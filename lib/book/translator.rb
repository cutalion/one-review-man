#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'date'
require_relative 'utils/book_utils'
require_relative 'utils/llm_service'

module Book
  class Translator
    include BookUtils

    def initialize(model_override = nil)
      @source_lang = 'en' # Always translate FROM English
      @llm_service = LLMService.new('scripts/llm_config.yml', model_override)
    end

    def translate_chapter_with_ai(chapter_number, target_lang)
      # Find the English chapter file using the standard naming convention
      source_file = "_chapters/#{format_chapter_filename(chapter_number)}"

      unless File.exist?(source_file)
        puts "❌ Chapter #{chapter_number} not found at #{source_file}"
        return false
      end

      puts "🤖 Translating Chapter #{chapter_number} to #{target_lang.upcase} with AI..."

      # Parse the source chapter
      chapter_data = parse_chapter_file(source_file)

      # Generate target filename using suffix approach (consistent with project pattern)
      source_basename = File.basename(source_file, '.md')
      target_file = "_chapters/#{source_basename}.#{target_lang}.md"

      begin
        # Use LLM to translate with structured output
        translation_data = @llm_service.translate_chapter_structured(
          chapter_data['title'],
          chapter_data['summary'] || 'No summary available',
          chapter_data['content'],
          target_lang
        )

        # Create translated chapter file
        create_translated_chapter_file(target_file, chapter_data, translation_data, target_lang)

        puts "✅ Chapter #{chapter_number} translated successfully!"
        puts "📄 Created: #{target_file}"

        true
      rescue LLMService::LLMError => e
        puts "❌ Translation failed: #{e.message}"
        false
      end
    end

    def translate_character_with_ai(character_slug, target_lang)
      # Find the English character file
      source_file = "_characters/#{character_slug}.md"

      unless File.exist?(source_file)
        puts "❌ Character '#{character_slug}' not found in _characters/"
        return false
      end

      puts "🤖 Translating character '#{character_slug}' to #{target_lang.upcase} with AI..."

      # Parse the source character
      character_data = parse_character_file(source_file)

      # Generate target filename using suffix approach (consistent with project pattern)
      target_file = "_characters/#{character_slug}.#{target_lang}.md"

      begin
        # Use LLM to translate with structured output
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

        # Create translated character file
        create_translated_character_file(target_file, character_data, translation_data, target_lang)

        puts "✅ Character '#{character_slug}' translated successfully!"
        puts "📄 Created: #{target_file}"

        true
      rescue LLMService::LLMError => e
        puts "❌ Translation failed: #{e.message}"
        false
      end
    end

    def translate_all_content(target_lang)
      puts "🌍 Translating all ready content to #{target_lang.upcase}..."

      success_count = 0
      total_count = 0
      skipped_count = 0

      # Translate all chapters (only English originals, not already translated files)
      puts "\n📚 Translating chapters..."
      Dir.glob('_chapters/*.md').reject { |f| f.include?('.ru.') || f.include?('.en.') }.each do |chapter_file|
        chapter_data = parse_chapter_file(chapter_file)
        chapter_num = chapter_data['chapter_number']

        next unless chapter_num

        # Check if translation already exists
        source_basename = File.basename(chapter_file, '.md')
        target_file = "_chapters/#{source_basename}.#{target_lang}.md"

        if File.exist?(target_file)
          puts "⏭️  Skipping Chapter #{chapter_num} - already translated"
          skipped_count += 1
          next
        end

        total_count += 1
        success_count += 1 if translate_chapter_with_ai(chapter_num, target_lang)
      end

      # Translate all characters (only English originals, not already translated files)
      puts "\n👥 Translating characters..."
      Dir.glob('_characters/*.md').reject { |f| f.include?('.ru.') || f.include?('.en.') }.each do |character_file|
        character_slug = File.basename(character_file, '.md')

        # Check if translation already exists
        target_file = "_characters/#{character_slug}.#{target_lang}.md"

        if File.exist?(target_file)
          puts "⏭️  Skipping character #{character_slug} - already translated"
          skipped_count += 1
          next
        end

        total_count += 1
        success_count += 1 if translate_character_with_ai(character_slug, target_lang)
      end

      puts "\n📊 Translation Summary:"
      puts "✅ Successfully translated: #{success_count}/#{total_count}"
      puts "❌ Failed: #{total_count - success_count}/#{total_count}"
      puts "⏭️  Skipped (already exists): #{skipped_count}"

      success_count == total_count
    end

    private

    def create_translated_chapter_file(target_file, source_data, translation_data, target_lang)
      # Generate proper permalink for Jekyll Polyglot (same as English, Polyglot will handle /ru/ prefix)
      source_basename = File.basename(target_file, ".#{target_lang}.md").gsub('_', '-')
      permalink = "/chapters/#{source_basename}/"

      # Preserve all metadata from source, update with translations
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
      # Generate proper permalink for Jekyll Polyglot (same as English, Polyglot will handle /ru/ prefix)
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

        file.puts "## О персонаже #{translation_data['name']}" if target_lang == 'ru'
        file.puts "## About #{translation_data['name']}" if target_lang != 'ru'
        file.puts ''
        file.puts translation_data['description']
        file.puts ''

        if translation_data['backstory'] && !translation_data['backstory'].empty?
          file.puts target_lang == 'ru' ? '## Предыстория' : '## Backstory'
          file.puts ''
          file.puts translation_data['backstory']
          file.puts ''
        end

        if translation_data['quirks'] && !translation_data['quirks'].empty?
          file.puts target_lang == 'ru' ? '## Особенности' : '## Notable Quirks'
          file.puts ''
          file.puts translation_data['quirks']
          file.puts ''
        end

        if translation_data['catchphrase'] && !translation_data['catchphrase'].empty?
          file.puts target_lang == 'ru' ? '## Крылатая фраза' : '## Catchphrase'
          file.puts ''
          file.puts "> \"#{translation_data['catchphrase']}\"
"
          file.puts ''
        end

        file.puts target_lang == 'ru' ? '## Появления' : '## Appearances'
        file.puts ''
        first_appearance_text = target_lang == 'ru' ? 'Впервые появился в' : 'First appeared in'
        file.puts "#{first_appearance_text}: #{source_data['first_appearance'] || (target_lang == 'ru' ? 'Ещё не определено' : 'To be determined')}"
        file.puts ''
        file.puts '<!-- Chapter appearances will be tracked automatically -->'
      end
    end

    def parse_character_file(file_path)
      content = File.read(file_path)
      match = content.match(/\A---\s*\n(.*?)\n---\s*\n(.*)/m)

      if match
        front_matter = YAML.safe_load(match[1]) || {}
        content_text = match[2]

        front_matter.merge({
                             'content' => content_text,
                             'file_path' => file_path
                           })
      else
        {
          'name' => File.basename(file_path, '.md').gsub('_', ' ').split.map(&:capitalize).join(' '),
          'content' => content,
          'file_path' => file_path
        }
      end
    rescue StandardError => e
      puts "Error parsing #{file_path}: #{e.message}"
      { 'file_path' => file_path, 'name' => File.basename(file_path, '.md') }
    end

    def format_chapter_filename(chapter_number)
      "#{chapter_number.to_s.rjust(3, '0')}-chapter.md"
    end
  end
end