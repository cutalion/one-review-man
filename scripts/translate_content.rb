#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'date'
require 'slop'
require_relative 'book_utils'
require_relative 'llm_service'

class ContentTranslator
  include BookUtils

  def initialize(model_override = nil)
    @source_lang = 'en' # Always translate FROM English
    @llm_service = LLMService.new('scripts/llm_config.yml', model_override)
  end

  def translate_chapter(chapter_number, target_lang)
    # Find the English chapter
    chapters = get_all_chapters('en')
    source_chapter = chapters.find { |c| c['chapter_number'] == chapter_number }

    unless source_chapter
      puts "Chapter #{chapter_number} not found in English!"
      return false
    end

    puts "Translating Chapter #{chapter_number} to #{target_lang.upcase}..."
    puts "Source: #{source_chapter['title']}"
    puts ''
    puts 'Please provide translations for:'
    puts ''

    # Get translation inputs
    print 'Chapter title: '
    translated_title = gets.chomp

    print 'Chapter summary: '
    translated_summary = gets.chomp

    puts ''
    puts 'Now translate the chapter content:'
    puts "Original content length: #{source_chapter['content']&.length || 0} characters"
    puts 'Please paste the translated content (press Ctrl+D when done):'

    translated_content = $stdin.read

    # Create the translated chapter file
    create_translated_chapter(source_chapter, target_lang, {
                                'title' => translated_title,
                                'summary' => translated_summary,
                                'content' => translated_content
                              })

    # Update metadata for target language
    update_translation_metadata(target_lang, 'chapter', source_chapter['chapter_number'])

    puts "Chapter #{chapter_number} translated to #{target_lang} successfully!"
    true
  end

  def translate_character(character_slug, target_lang)
    # Load English character data
    source_characters = load_characters('en')
    source_character = source_characters.dig('characters', character_slug)

    unless source_character
      puts "Character '#{character_slug}' not found in English!"
      return false
    end

    puts "Translating character '#{source_character['name']}' to #{target_lang.upcase}..."
    puts ''

    # Get translation inputs
    print 'Character name: '
    translated_name = gets.chomp

    print 'Character description: '
    translated_description = gets.chomp

    print 'Personality traits (comma-separated): '
    traits_input = gets.chomp
    translated_traits = traits_input.split(',').map(&:strip).reject(&:empty?)

    print 'Catchphrase (if any): '
    translated_catchphrase = gets.chomp
    translated_catchphrase = nil if translated_catchphrase.empty?

    print 'Backstory: '
    translated_backstory = gets.chomp
    translated_backstory = nil if translated_backstory.empty?

    print 'Quirks: '
    translated_quirks = gets.chomp
    translated_quirks = nil if translated_quirks.empty?

    # Create translated character data (preserve structure and relationships)
    translated_character = source_character.dup
    translated_character.update({
                                  'name' => translated_name,
                                  'description' => translated_description,
                                  'personality_traits' => translated_traits,
                                  'catchphrase' => translated_catchphrase,
                                  'backstory' => translated_backstory,
                                  'quirks' => translated_quirks,
                                  'translated_from' => 'en',
                                  'translated_date' => Date.today.to_s,
                                  'language' => target_lang
                                })

    # Save to target language character data
    target_characters = load_characters(target_lang)
    target_characters['characters'][character_slug] = translated_character
    save_characters(target_characters, target_lang)

    # Create character page
    create_translated_character_page(character_slug, translated_character, target_lang)

    # Update metadata
    update_translation_metadata(target_lang, 'character', character_slug)

    puts "Character '#{translated_name}' (#{character_slug}) translated to #{target_lang} successfully!"
    true
  end

  def translate_all_characters(target_lang)
    source_characters = load_characters('en')

    if source_characters['characters'].empty?
      puts 'No characters found in English to translate!'
      return false
    end

    puts "Translating all characters to #{target_lang.upcase}..."

    success_count = 0
    total_count = 0
    skipped_count = 0

    source_characters['characters'].each do |slug, character|
      # Check if translation already exists
      target_file = "_characters/#{slug}.#{target_lang}.md"

      if File.exist?(target_file)
        puts "⏭️  Skipping #{character['name']} (#{slug}) - already translated"
        skipped_count += 1
        next
      end

      puts "\n=== Translating #{character['name']} ==="
      total_count += 1
      success_count += 1 if translate_character(slug, target_lang)
    end

    puts "\n📊 Character Translation Summary:"
    puts "✅ Successfully translated: #{success_count}/#{total_count}"
    puts "❌ Failed: #{total_count - success_count}/#{total_count}"
    puts "⏭️  Skipped (already exists): #{skipped_count}"

    success_count == total_count
  end

  def sync_chapter_metadata(chapter_number, target_lang)
    # Sync non-text metadata (character appearances, relationships, etc.)
    source_chapters = get_all_chapters('en')
    source_chapter = source_chapters.find { |c| c['chapter_number'] == chapter_number }

    return false unless source_chapter

    target_chapters = get_all_chapters(target_lang)
    target_chapter = target_chapters.find { |c| c['chapter_number'] == chapter_number }

    return false unless target_chapter

    # Update the target chapter file with synced metadata
    sync_metadata = {
      'characters' => source_chapter['characters'],
      'new_characters' => source_chapter['new_characters'],
      'chapter_number' => source_chapter['chapter_number']
    }

    update_chapter_front_matter(target_chapter['file_path'], sync_metadata)
    puts "Synced metadata for Chapter #{chapter_number} in #{target_lang}"
    true
  end

  def list_translation_status(target_lang)
    puts "\n=== Translation Status for #{target_lang.upcase} ==="

    # Check chapters
    source_chapters = get_all_chapters

    puts "\nChapters:"
    source_chapters.each do |chapter|
      chapter_num = chapter['chapter_number']
      source_basename = File.basename(chapter['file_path'], '.md')
      target_file = "_chapters/#{source_basename}.#{target_lang}.md"
      translated = File.exist?(target_file)
      status = translated ? '✅ Translated' : '❌ Missing'
      puts "  Chapter #{chapter_num}: #{chapter['title']} - #{status}"
    end

    # Check characters
    puts "\nCharacters:"
    Dir.glob('_characters/*.md').reject { |f| f.include?('.ru.') || f.include?('.en.') }.each do |source_file|
      character_slug = File.basename(source_file, '.md')
      character_data = parse_character_file(source_file)
      character_name = character_data['name'] || character_slug.gsub('_', ' ').split.map(&:capitalize).join(' ')

      target_file = "_characters/#{character_slug}.#{target_lang}.md"
      translated = File.exist?(target_file)
      status = translated ? '✅ Translated' : '❌ Missing'
      puts "  #{character_name} (#{character_slug}) - #{status}"
    end
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

  def create_translated_chapter(source_chapter, target_lang, translations)
    # Create filename with language suffix
    base_name = File.basename(source_chapter['file_path'], '.md')
    target_filename = "_chapters/#{base_name}.#{target_lang}.md"

    # Preserve all metadata from source, update with translations
    front_matter = source_chapter.dup
    front_matter.delete('content')
    front_matter.delete('file_path')
    front_matter.update({
                          'title' => translations['title'],
                          'summary' => translations['summary'],
                          'lang' => target_lang,
                          'translated_from' => 'en',
                          'translated_date' => Date.today.to_s
                        })

    File.open(target_filename, 'w') do |file|
      file.puts '---'
      file.puts front_matter.to_yaml.lines[1..]
      file.puts '---'
      file.puts ''
      file.puts translations['content']
    end
  end

  def create_translated_character_page(slug, character_data, target_lang)
    filename = "_characters/#{slug}.#{target_lang}.md"

    front_matter = {
      'layout' => 'character',
      'name' => character_data['name'],
      'slug' => slug,
      'description' => character_data['description'],
      'personality_traits' => character_data['personality_traits'] || [],
      'first_appearance' => character_data['first_appearance'],
      'relationships' => character_data['relationships'] || [],
      'lang' => target_lang,
      'translated_from' => 'en',
      'translated_date' => Date.today.to_s
    }

    File.open(filename, 'w') do |file|
      file.puts '---'
      file.puts front_matter.to_yaml.lines[1..]
      file.puts '---'
      file.puts ''

      # Get localized strings
      strings = load_strings(target_lang)

      file.puts "## #{strings.dig('character', 'about') || 'About'} #{character_data['name']}"
      file.puts ''
      file.puts character_data['description']
      file.puts ''

      if character_data['backstory']
        file.puts "## #{strings.dig('character', 'backstory') || 'Backstory'}"
        file.puts ''
        file.puts character_data['backstory']
        file.puts ''
      end

      if character_data['quirks']
        file.puts "## #{strings.dig('character', 'quirks') || 'Notable Quirks'}"
        file.puts ''
        file.puts character_data['quirks']
        file.puts ''
      end

      if character_data['catchphrase']
        file.puts "## #{strings.dig('character', 'catchphrase') || 'Catchphrase'}"
        file.puts ''
        file.puts "> \"#{character_data['catchphrase']}\""
        file.puts ''
      end

      file.puts "## #{strings.dig('character', 'appearances') || 'Appearances'}"
      file.puts ''
      file.puts "#{strings.dig('character', 'first_appeared') || 'First appeared in'}: #{character_data['first_appearance'] || strings.dig('character', 'to_be_determined') || 'To be determined'}"
      file.puts ''
      file.puts '<!-- Chapter appearances will be tracked automatically -->'
    end
  end

  def update_translation_metadata(target_lang, content_type, _content_id)
    book_data = load_book_data(target_lang)
    book_data['status'] ||= {}
    book_data['status']['last_translated'] = Date.today.to_s
    book_data['status']['translation_count'] = (book_data['status']['translation_count'] || 0) + 1

    if content_type == 'character'
      book_data['status']['characters_created'] = (book_data['status']['characters_created'] || 0) + 1
    end

    save_book_data(book_data, target_lang)
  end

  def update_chapter_front_matter(file_path, updates)
    front_matter, content_body = parse_front_matter_file(file_path)
    return unless front_matter && content_body

    front_matter.update(updates)
    write_front_matter_file(file_path, front_matter, content_body)
  end

  def parse_front_matter_file(file_path)
    content = File.read(file_path)
    match = content.match(/^---\s*\n(.*?)\n---\s*\n(.*)/m)
    return [nil, nil] unless match

    [YAML.load(match[1]), match[2]]
  end

  def write_front_matter_file(file_path, front_matter, content_body)
    File.open(file_path, 'w') do |file|
      file.puts '---'
      file.puts front_matter.to_yaml.lines[1..]
      file.puts '---'
      file.puts content_body
    end
  end

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
        file.puts "> \"#{translation_data['catchphrase']}\""
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

# Command line interface
if __FILE__ == $PROGRAM_NAME
  # Parse options
  begin
    result = Slop.parse(ARGV) do |o|
      o.banner = "AI-Powered Translation Tool for One Review Man\n\nUsage: #{File.basename($0)} [command] [arguments] [options]"
      o.separator ''
      o.separator 'Commands:'
      o.separator '  chapter NUM LANG      Translate specific chapter with AI'
      o.separator '  character SLUG LANG   Translate specific character with AI'
      o.separator '  all-characters LANG   Translate all characters with AI'
      o.separator '  all-content LANG      Translate all content with AI'
      o.separator '  sync NUM LANG         Sync chapter metadata'
      o.separator '  status LANG           Show translation status'
      o.separator ''
      o.separator 'Options:'

      o.string '-m', '--model', 'Override model (gpt-4o, o3, gpt-4o-mini)', default: nil
      o.bool '-h', '--help', 'Show this help' do
        puts o
        exit
      end

      o.separator ''
      o.separator 'Examples:'
      o.separator "  #{File.basename($0)} chapter 1 ru -m gpt-4o"
      o.separator "  #{File.basename($0)} character one_review_man ru"
      o.separator "  #{File.basename($0)} all-characters ru --model o3"
      o.separator "  #{File.basename($0)} all-content ru"
      o.separator "  #{File.basename($0)} status ru"
      o.separator ''
      o.separator 'Supported languages: ru (Russian), es (Spanish), fr (French), de (German)'
    end

    opts = result
    remaining_args = result.args
  rescue Slop::Error => e
    puts "❌ Error: #{e.message}"
    puts "Try: #{File.basename($0)} --help"
    exit 1
  end

  # Show help if no command provided
  if remaining_args.empty?
    puts opts
    exit 0
  end

  # Show model override feedback
  puts "🔧 Using model override: #{opts[:model]}" if opts[:model]

  # Get command and arguments
  command = remaining_args.shift

  # Initialize translator
  translator = ContentTranslator.new(opts[:model])

  # Execute command
  case command
  when 'chapter'
    chapter_num = remaining_args.shift&.to_i
    target_lang = remaining_args.shift

    if chapter_num&.positive? && target_lang
      translator.translate_chapter_with_ai(chapter_num, target_lang)
    else
      puts '❌ Error: Chapter number and target language required'
      puts "Usage: #{File.basename($0)} chapter <chapter_number> <target_language>"
      puts "Example: #{File.basename($0)} chapter 1 ru"
      exit 1
    end

  when 'character'
    character_slug = remaining_args.shift
    target_lang = remaining_args.shift

    if character_slug && target_lang
      translator.translate_character_with_ai(character_slug, target_lang)
    else
      puts '❌ Error: Character slug and target language required'
      puts "Usage: #{File.basename($0)} character <character_slug> <target_language>"
      puts "Example: #{File.basename($0)} character one_review_man ru"
      exit 1
    end

  when 'all-characters'
    target_lang = remaining_args.shift

    if target_lang
      # Translate all characters with AI (only English originals, not already translated files)
      puts "🌍 Translating all characters to #{target_lang.upcase} with AI..."
      success_count = 0
      total_count = 0
      skipped_count = 0

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
        success_count += 1 if translator.translate_character_with_ai(character_slug, target_lang)
      end

      puts "\n📊 Character Translation Summary:"
      puts "✅ Successfully translated: #{success_count}/#{total_count}"
      puts "❌ Failed: #{total_count - success_count}/#{total_count}"
      puts "⏭️  Skipped (already exists): #{skipped_count}"
    else
      puts '❌ Error: Target language required'
      puts "Usage: #{File.basename($0)} all-characters <target_language>"
      puts "Example: #{File.basename($0)} all-characters ru"
      exit 1
    end

  when 'all-content'
    target_lang = remaining_args.shift

    if target_lang
      translator.translate_all_content(target_lang)
    else
      puts '❌ Error: Target language required'
      puts "Usage: #{File.basename($0)} all-content <target_language>"
      puts "Example: #{File.basename($0)} all-content ru"
      exit 1
    end

  when 'sync'
    chapter_num = remaining_args.shift&.to_i
    target_lang = remaining_args.shift

    if chapter_num&.positive? && target_lang
      translator.sync_chapter_metadata(chapter_num, target_lang)
    else
      puts '❌ Error: Chapter number and target language required'
      puts "Usage: #{File.basename($0)} sync <chapter_number> <target_language>"
      puts "Example: #{File.basename($0)} sync 1 ru"
      exit 1
    end

  when 'status'
    target_lang = remaining_args.shift

    if target_lang
      translator.list_translation_status(target_lang)
    else
      puts '❌ Error: Target language required'
      puts "Usage: #{File.basename($0)} status <target_language>"
      puts "Example: #{File.basename($0)} status ru"
      exit 1
    end

  else
    puts "❌ Error: Unknown command '#{command}'"
    puts "Try: #{File.basename($0)} --help"
    exit 1
  end
end
