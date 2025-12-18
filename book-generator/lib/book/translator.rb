# frozen_string_literal: true

# This file provides a require path compatibility shim under the package so
# `require 'book/translator'` resolves without relying on the repo root.

core_lib = File.expand_path('../..', __dir__)
$LOAD_PATH.unshift(core_lib) unless $LOAD_PATH.include?(core_lib)

require 'yaml'
require 'book_core/llm_service'
require 'book_core/book_utils'

module Book
  # Service class for translating book content to different languages
  class Translator
    include BookUtils

    def initialize(model_override = nil, llm_service: nil, project_root: Dir.pwd, config: nil)
      @source_lang = 'en' # Always translate FROM English
      @project_root = File.expand_path(project_root)
      
      if config
        @llm_service = llm_service || BookCore::LLMService.new(config)
      else
        # Fallback for legacy calls
        config = BookCore::Configuration.load(@project_root, { 'llm.model' => model_override })
        @llm_service = llm_service || BookCore::LLMService.new(config)
      end
    end

    # Translate a single chapter using the LLM service with glossary support
    def translate_chapter_with_ai(chapter_number, target_lang)
      source_file = File.join(@project_root, preferred_chapters_dir_name, format_chapter_filename(chapter_number))
      unless File.exist?(source_file)
        puts "❌ Chapter #{chapter_number} not found at #{source_file}"
        return false
      end

      provider = @llm_service.get_provider_for_task('translation')
      model = @llm_service.get_model_for_task('translation')
      puts "🤖 Translating Chapter #{chapter_number} to #{target_lang.upcase} using #{provider}/#{model}..."

      chapter_data = parse_chapter_file(source_file)
      source_basename = File.basename(source_file, '.md')
      target_file = File.join(@project_root, preferred_chapters_dir_name, "#{source_basename}.#{target_lang}.md")

      begin
        glossary = build_name_glossary(target_lang)
        book_metadata = load_book_metadata_abs
        translation_data = @llm_service.translate_chapter_structured(
          chapter_data['title'],
          chapter_data['summary'] || 'No summary available',
          chapter_data['content'],
          target_lang,
          glossary,
          book_metadata
        )

        create_translated_chapter_file(target_file, chapter_data, translation_data, target_lang)

        puts "✅ Chapter #{chapter_number} translated successfully!"
        puts "📄 Created: #{target_file}"
        true
      rescue BookCore::LLMService::LLMError => e
        puts "❌ Translation failed: #{e.message}"
        false
      end
    end

    def translate_character_with_ai(character_slug, target_lang)
      source_file = File.join(@project_root, preferred_characters_dir_name, "#{character_slug}.md")
      unless File.exist?(source_file)
        puts "❌ Character '#{character_slug}' not found in _characters/"
        return false
      end

      provider = @llm_service.get_provider_for_task('translation')
      model = @llm_service.get_model_for_task('translation')
      puts "🤖 Translating character '#{character_slug}' to #{target_lang.upcase} using #{provider}/#{model}..."

      character_data = parse_character_file(source_file)
      target_file = File.join(@project_root, preferred_characters_dir_name, "#{character_slug}.#{target_lang}.md")

      begin
        translation_data = @llm_service.translate_character_structured(
          character_data['name'],
          character_data['description'],
          character_data['personality_traits'] || [],
          character_data['programming_skills'] || '',
          character_data['catchphrase'] || '',
          character_data['backstory'] || '',
          character_data['quirks'] || '',
          target_lang
        )

        create_translated_character_file(target_file, character_data, translation_data, target_lang)
        puts "✅ Character '#{character_slug}' translated successfully!"
        puts "📄 Created: #{target_file}"
        true
      rescue BookCore::LLMService::LLMError => e
        puts "❌ Translation failed: #{e.message}"
        false
      end
    end

    def translate_all_content?(target_lang)
      puts "🌍 Translating all ready content to #{target_lang.upcase}..."

      success_count = 0
      total_count = 0
      skipped_count = 0

      puts "\n👥 Translating characters..."
      Dir.glob(File.join(@project_root, preferred_characters_dir_name, '*.md')).reject { |f| f.include?('.ru.') || f.include?('.en.') }.each do |character_file|
        character_slug = File.basename(character_file, '.md')
        target_file = File.join(@project_root, preferred_characters_dir_name, "#{character_slug}.#{target_lang}.md")
        if File.exist?(target_file)
          puts "⏭️  Skipping character #{character_slug} - already translated"
          skipped_count += 1
          next
        end
        total_count += 1
        success_count += 1 if translate_character_with_ai(character_slug, target_lang)
      end

      puts "\n📚 Translating chapters..."
      Dir.glob(File.join(@project_root, preferred_chapters_dir_name, '*.md')).reject { |f| f.include?('.ru.') || f.include?('.en.') }.each do |chapter_file|
        chapter_data = parse_chapter_file(chapter_file)
        chapter_num = chapter_data['chapter_number']
        next unless chapter_num

        source_basename = File.basename(chapter_file, '.md')
        target_file = File.join(@project_root, preferred_chapters_dir_name, "#{source_basename}.#{target_lang}.md")
        if File.exist?(target_file)
          puts "⏭️  Skipping Chapter #{chapter_num} - already translated"
          skipped_count += 1
          next
        end
        total_count += 1
        success_count += 1 if translate_chapter_with_ai(chapter_num, target_lang)
      end

      puts "\n📊 Translation Summary:"
      puts "✅ Successfully translated: #{success_count}/#{total_count}"
      puts "❌ Failed: #{total_count - success_count}/#{total_count}"
      puts "⏭️  Skipped (already exists): #{skipped_count}"

      success_count == total_count
    end

    private

    include BookUtils

    def build_name_glossary(target_lang)
      glossary_lines = []
      Dir.glob(File.join(@project_root, preferred_characters_dir_name, '*.md')).each do |english_file|
        next if english_file.include?(".#{target_lang}.") || english_file.include?('.en.')

        slug = File.basename(english_file, '.md')
        translated_file = File.join(@project_root, preferred_characters_dir_name, "#{slug}.#{target_lang}.md")
        next unless File.exist?(translated_file)

        english_name = extract_name_from_character_file(english_file)
        translated_name = extract_name_from_character_file(translated_file)
        next unless english_name && translated_name

        glossary_lines << "#{english_name} -> #{translated_name}"
        en_parts = english_name.split
        tr_parts = translated_name.split
        en_parts.zip(tr_parts).each { |en_part, tr_part| glossary_lines << "#{en_part} -> #{tr_part}" } if en_parts.size == tr_parts.size && en_parts.size > 1
      end
      glossary_lines.uniq.sort.join("\n")
    end

    def preferred_chapters_dir_name
      content_dir = File.join(@project_root, 'content', 'chapters')
      Dir.exist?(content_dir) ? File.join('content', 'chapters') : '_chapters'
    end

    def preferred_characters_dir_name
      content_dir = File.join(@project_root, 'content', 'characters')
      Dir.exist?(content_dir) ? File.join('content', 'characters') : '_characters'
    end

    def extract_name_from_character_file(file_path)
      content = File.read(file_path)
      match = content.match(/\A---\s*\n(.*?)\n---/m)
      return nil unless match

      front_matter = YAML.safe_load(match[1]) || {}
      front_matter['name']
    rescue StandardError => e
      puts "⚠️  Warning: Failed to extract name from character file '#{file_path}': #{e.message}"
      nil
    end

    def create_translated_chapter_file(target_file, source_data, translation_data, target_lang)
      source_basename = File.basename(target_file, ".#{target_lang}.md").gsub('_', '-')
      permalink = "/chapters/#{source_basename}/"

      front_matter = source_data.dup
      front_matter.delete('content')
      front_matter.delete('file_path')
      front_matter.update({
                            'title' => translation_data['title'],
                            'summary' => translation_data['summary'],
                            'permalink' => permalink,
                            'lang' => target_lang,
                            'translated_from' => 'en',
                            'translated_date' => Date.today.to_s
                          })

      File.open(target_file, 'w') do |file|
        file.puts '---'
        file.puts front_matter.to_yaml.lines[1..]
        file.puts '---'
        file.puts ''
        file.puts translation_data['content']
      end
    end

    def create_translated_character_file(target_file, source_data, translation_data, target_lang)
      character_slug = source_data['slug']
      permalink_slug = character_slug.gsub('_', '-')
      permalink = "/characters/#{permalink_slug}/"

      front_matter = {
        'layout' => 'character',
        'name' => translation_data['name'],
        'slug' => source_data['slug'],
        'description' => translation_data['description'],
        'personality_traits' => translation_data['personality_traits'] || [],
        'programming_skills' => translation_data['programming_skills'],
        'catchphrase' => translation_data['catchphrase'],
        'backstory' => translation_data['backstory'],
        'quirks' => translation_data['quirks'],
        'first_appearance' => source_data['first_appearance'],
        'relationships' => source_data['relationships'] || [],
        'permalink' => permalink,
        'lang' => target_lang,
        'translated_from' => 'en',
        'translated_date' => Date.today.to_s
      }.compact

      File.open(target_file, 'w') do |file|
        file.puts '---'
        file.puts front_matter.to_yaml.lines[1..]
        file.puts '---'
        file.puts ''

        file.puts(target_lang == 'ru' ? "## О персонаже #{translation_data['name']}" : "## About #{translation_data['name']}")
        file.puts ''
        file.puts translation_data['description']
        file.puts ''

        if translation_data['backstory'] && !translation_data['backstory'].empty?
          file.puts(target_lang == 'ru' ? '## Предыстория' : '## Backstory')
          file.puts ''
          file.puts translation_data['backstory']
          file.puts ''
        end

        if translation_data['quirks'] && !translation_data['quirks'].empty?
          file.puts(target_lang == 'ru' ? '## Особенности' : '## Notable Quirks')
          file.puts ''
          file.puts translation_data['quirks']
          file.puts ''
        end

        if translation_data['catchphrase'] && !translation_data['catchphrase'].empty?
          file.puts(target_lang == 'ru' ? '## Крылатая фраза' : '## Catchphrase')
          file.puts ''
          file.puts "> \"#{translation_data['catchphrase']}\""
          file.puts ''
        end

        file.puts(target_lang == 'ru' ? '## Появления' : '## Appearances')
        file.puts ''
        first_appearance_text = target_lang == 'ru' ? 'Впервые появился в' : 'First appeared in'
        file.puts "#{first_appearance_text}: #{source_data['first_appearance'] || (target_lang == 'ru' ? 'Ещё не определено' : 'To be determined')}"
        file.puts ''
        file.puts '<!-- Chapter appearances will be tracked automatically -->'
      end
    end

    def load_book_metadata_abs
      path = File.join(@project_root, 'data', 'book_metadata.yml')
      File.exist?(path) ? (YAML.safe_load_file(path) || {}) : {}
    end
  end
end
