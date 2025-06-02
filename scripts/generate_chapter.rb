#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'date'
require 'fileutils'
require_relative 'book_utils'
require_relative 'llm_service'

class ChapterGenerator
  include BookUtils

  def initialize
    # Always generate in English
    @book_data = load_book_data
    @characters = load_characters
    @generation_log = load_generation_log
    @llm_service = LLMService.new
  end

  def generate_next_chapter(auto_generate: false)
    current_chapter = @book_data['book']['current_chapter'] + 1

    puts "Generating Chapter #{current_chapter}..."

    # Determine characters for this chapter
    characters = select_characters_for_chapter(current_chapter)

    # Build prompt
    prompt = build_chapter_prompt(current_chapter, characters)

    unless auto_generate
      puts 'Prompt built. Ready for AI generation.'
      puts 'Would you like to see the prompt? (y/n)'

      response = gets.chomp.downcase
      if %w[y yes].include?(response)
        puts "\n#{'=' * 50}"
        puts prompt
        puts "#{'=' * 50}\n"
      end

      puts 'Proceed with AI generation? (y/n)'
      proceed = gets.chomp.downcase
      return unless %w[y yes].include?(proceed)
    end

    begin
      # Use structured chapter generation for better reliability
      chapter_data = @llm_service.generate_chapter_structured(prompt)

      if chapter_data && chapter_data['content'] && !chapter_data['content'].strip.empty?
        create_chapter_file_structured(current_chapter, chapter_data, characters)
        update_book_progress(current_chapter)

        puts "✅ Chapter #{current_chapter} generated successfully!"

        # Display generation summary
        display_chapter_summary(chapter_data)
      else
        puts '❌ No content generated. Please try again.'
      end
    rescue LLMService::LLMError => e
      puts "❌ Chapter generation failed: #{e.message}"
      puts 'Please create the chapter file manually and paste AI-generated content.'
      create_empty_chapter_structure(current_chapter, characters)
    end
  end

  def improve_chapter(chapter_number, improvement_type = 'humor')
    puts "Improving Chapter #{chapter_number} (#{improvement_type})..."

    # Find existing chapter
    chapters = get_all_chapters
    existing_chapter = chapters.find { |c| c['chapter_number'] == chapter_number }

    unless existing_chapter
      puts "Chapter #{chapter_number} not found!"
      return false
    end

    # Get current content
    chapter_file = "_chapters/#{format_chapter_filename(chapter_number)}"
    current_content = extract_chapter_content(chapter_file)

    if current_content.empty?
      puts 'No content found in chapter file to improve!'
      return false
    end

    begin
      # Improve content using LLM
      improved_content = @llm_service.improve_content(current_content, improvement_type)

      # Update the chapter file
      update_chapter_content(chapter_file, improved_content)

      puts "✅ Chapter #{chapter_number} improved successfully!"
    rescue LLMService::LLMError => e
      puts "❌ Improvement failed: #{e.message}"
      false
    end
  end

  def regenerate_prompt(chapter_number)
    puts "Regenerating prompt for Chapter #{chapter_number}..."

    # Find existing chapter
    chapters = get_all_chapters
    existing_chapter = chapters.find { |c| c['chapter_number'] == chapter_number }

    unless existing_chapter
      puts "Chapter #{chapter_number} not found!"
      return false
    end

    # Get characters from existing chapter
    characters = existing_chapter['characters'] || []
    character_objects = get_characters_by_slugs(characters)

    # Build and display prompt
    prompt = build_chapter_prompt(chapter_number, character_objects)

    puts "\n#{'=' * 50}"
    puts "PROMPT FOR CHAPTER #{chapter_number}"
    puts '=' * 50
    puts prompt
    puts "#{'=' * 50}\n"

    true
  end

  def regenerate_chapter(chapter_number)
    puts "Regenerating Chapter #{chapter_number} with AI..."

    # Find existing chapter
    chapters = get_all_chapters
    existing_chapter = chapters.find { |c| c['chapter_number'] == chapter_number }

    unless existing_chapter
      puts "Chapter #{chapter_number} not found!"
      return false
    end

    # Get characters from existing chapter
    characters = existing_chapter['characters'] || []
    character_objects = get_characters_by_slugs(characters)

    # Build prompt
    prompt = build_chapter_prompt(chapter_number, character_objects)

    puts 'Proceeding with regeneration...'

    begin
      # Generate new content using structured method
      chapter_data = @llm_service.generate_chapter_structured(prompt)

      # Update chapter file with structured data
      chapter_file = "_chapters/#{format_chapter_filename(chapter_number)}"
      update_chapter_with_structured_content(chapter_file, chapter_data)

      puts "✅ Chapter #{chapter_number} regenerated successfully!"

      # Display generation summary
      display_chapter_summary(chapter_data)
    rescue LLMService::LLMError => e
      puts "❌ Regeneration failed: #{e.message}"
      false
    end
  end

  private

  def select_characters_for_chapter(chapter_num)
    # Logic to determine which characters appear in this chapter
    all_characters = @characters['characters'].values

    if chapter_num == 1
      # First chapter - introduce 1-2 main characters
      all_characters.take(2)
    elsif chapter_num <= 3
      # Early chapters - gradually introduce characters
      all_characters.take([chapter_num + 1, all_characters.size].min)
    else
      # Later chapters - mix of existing characters
      all_characters.sample([3, all_characters.size].min)
    end
  end

  def build_chapter_prompt(chapter_num, characters)
    prompt_template = load_prompt_template
    book_metadata = @book_data

    # Get previous chapters summary
    previous_chapters = get_all_chapters
                        .select { |c| c['chapter_number'] && c['chapter_number'] < chapter_num }
                        .sort_by { |c| c['chapter_number'] }

    previous_summary = if previous_chapters.any?
                         previous_chapters.map { |c| "Chapter #{c['chapter_number']}: #{c['title']} - #{c['summary'] || 'Summary not available'}" }.join("\n")
                       else
                         'This is the first chapter.'
                       end

    # Build character context
    character_context = characters.map do |char|
      traits = char['personality_traits']&.join(', ') || 'None specified'
      skills = char['programming_skills'] || 'General programming'
      "#{char['name']}: #{char['description']} (Traits: #{traits}, Skills: #{skills})"
    end.join("\n")

    # Get used plot devices
    used_devices = get_used_plot_devices

    # Get character real names for template replacement
    one_review_man = @characters['characters'].values.find { |c| c['name'] == 'One Review Man' }
    ai_disciple = @characters['characters'].values.find { |c| c['name'] == 'AI-Enhanced Disciple' }

    one_review_man_real_name = one_review_man&.dig('real_name') || '[to be generated]'
    ai_disciple_real_name = ai_disciple&.dig('real_name') || '[to be generated]'

    # Replace template variables
    prompt_template
      .gsub('{CHAPTER_NUMBER}', chapter_num.to_s)
      .gsub('{TARGET_LENGTH}', book_metadata.dig('generation', 'chapter_length_target') || '1500-3000 words')
      .gsub('{PREVIOUS_CHAPTERS_SUMMARY}', previous_summary)
      .gsub('{CHARACTER_CONTEXT}', character_context.empty? ? 'No existing characters.' : "Existing characters:\n#{character_context}")
      .gsub('{USED_PLOT_DEVICES}', used_devices.join(', '))
      .gsub('{SPECIAL_INSTRUCTIONS}', get_special_instructions(chapter_num))
      .gsub('{ONE_REVIEW_MAN_REAL_NAME}', one_review_man_real_name)
      .gsub('{AI_ENHANCED_DISCIPLE_REAL_NAME}', ai_disciple_real_name)
  end

  def load_prompt_template
    template_file = 'scripts/prompts/chapter_prompts.txt'
    raise "Prompt template not found at #{template_file}" unless File.exist?(template_file)

    File.read(template_file)
  end

  def parse_generated_chapter(content)
    # Extract title and content from generated text
    lines = content.split("\n")

    title = nil
    content_lines = []
    summary = nil
    new_characters = []

    current_section = :content

    lines.each do |line|
      stripped_line = line.strip

      # Look for title (first # heading)
      if stripped_line.match(/^#\s+(.+)$/) && title.nil?
        title = ::Regexp.last_match(1).strip
        content_lines << line
      # Look for character notes section
      elsif stripped_line.match(/^##?\s*(Character Notes|New Characters)/i)
        current_section = :characters
      # Look for summary section
      elsif stripped_line.match(/^##?\s*Summary/i)
        current_section = :summary
      else
        case current_section
        when :content
          content_lines << line
        when :characters
          # Parse character mentions
          if stripped_line.match(/^-?\s*(.+):\s*(.+)$/)
            char_name = ::Regexp.last_match(1).strip
            char_desc = ::Regexp.last_match(2).strip
            new_characters << { 'name' => char_name, 'description' => char_desc }
          end
        when :summary
          summary = "#{summary || ''}#{stripped_line} "
        end
      end
    end

    {
      title: title || "Chapter #{@book_data['book']['current_chapter'] + 1}",
      content: content_lines.join("\n").strip,
      summary: summary&.strip,
      new_characters: new_characters
    }
  end

  def create_chapter_file_structured(chapter_num, chapter_data, characters)
    filename = "_chapters/#{format_chapter_filename(chapter_num)}"

    # Extract new characters if present
    new_characters = chapter_data['new_characters'] || []
    character_slugs = new_characters.map { |char| slugify(char['name']) }

    # Generate proper permalink for Jekyll Polyglot (use dashes, not underscores)
    chapter_slug = format_chapter_filename(chapter_num).gsub('.md', '').gsub('_', '-')
    permalink = "/chapters/#{chapter_slug}/"

    front_matter = {
      'layout' => 'chapter',
      'title' => chapter_data['title'],
      'chapter_number' => chapter_num,
      'characters' => characters.map { |c| c['slug'] },
      'new_characters' => character_slugs,
      'summary' => chapter_data['summary'],
      'programming_themes' => chapter_data['programming_themes'] || [],
      'comedy_elements' => chapter_data['comedy_elements'] || [],
      'word_count' => chapter_data['word_count'],
      'difficulty_level' => chapter_data['difficulty_level'],
      'one_punch_man_references' => chapter_data['one_punch_man_references'] || [],
      'permalink' => permalink,
      'generated_date' => Date.today.to_s,
      'status' => 'generated',
      'lang' => 'en'
    }

    File.open(filename, 'w') do |file|
      file.puts '---'
      file.puts front_matter.to_yaml.lines[1..] # Skip first "---" line
      file.puts '---'
      file.puts ''
      file.puts chapter_data['content']
      file.puts ''
    end

    # Auto-create any new characters mentioned
    create_new_characters_structured(new_characters, chapter_num) if new_characters.any?
  end

  def create_new_characters_structured(new_characters, chapter_num)
    puts "\n🎭 Creating new characters mentioned in the chapter..."

    new_characters.each do |char_data|
      next if char_data['name'].nil? || char_data['name'].empty?

      slug = slugify(char_data['name'])

      # Skip if character already exists
      if @characters['characters'].key?(slug)
        puts "Character '#{char_data['name']}' already exists, skipping..."
        next
      end

      character_prompt = build_character_creation_prompt(char_data, chapter_num)

      begin
        full_character = @llm_service.generate_character(character_prompt)

        # Merge LLM generated data with basic info
        character_data = {
          'name' => char_data['name'],
          'description' => full_character['description'] || char_data['description'],
          'personality_traits' => full_character['personality_traits'] || [],
          'programming_skills' => full_character['programming_skills'] || 'General programming',
          'catchphrase' => full_character['catchphrase'],
          'backstory' => full_character['backstory'],
          'quirks' => full_character['quirks'],
          'first_appearance' => "Chapter #{chapter_num}",
          'slug' => slug,
          'created_date' => Date.today.to_s,
          'language' => 'en'
        }.compact

        # Add to characters data
        @characters['characters'][slug] = character_data
        save_characters(@characters)

        # Create character page
        create_character_page(slug, character_data)

        puts "✅ Created character: #{char_data['name']}"
      rescue LLMService::LLMError => e
        puts "⚠️  Failed to fully generate character '#{char_data['name']}': #{e.message}"
        # Create basic character entry
        basic_character = {
          'name' => char_data['name'],
          'description' => char_data['description'] || 'New character',
          'first_appearance' => "Chapter #{chapter_num}",
          'slug' => slug,
          'created_date' => Date.today.to_s,
          'language' => 'en'
        }

        @characters['characters'][slug] = basic_character
        save_characters(@characters)
        puts 'Created basic character entry for manual completion'
      end
    end
  end

  def build_character_creation_prompt(char_data, chapter_num)
    <<~PROMPT
      Create a full character profile for a new character introduced in Chapter #{chapter_num} of "One Review Man".

      CHARACTER INFO FROM CHAPTER:
      Name: #{char_data['name']}
      Description: #{char_data['description'] || 'Brief mention only'}

      CONTEXT:
      This character was introduced in Chapter #{chapter_num} and should fit into the One Review Man universe - a programming parody of One-Punch Man.

      REQUIREMENTS:
      - Expand on the basic description to create a full character
      - Make them fit the programming/tech comedy theme
      - Give them distinctive personality traits
      - Add programming skills appropriate to their role
      - Include a memorable catchphrase if appropriate
      - Add backstory that explains their place in the programming world

      Please create a complete character profile with typical fields: name, description, personality_traits, programming_skills, catchphrase, backstory, quirks.
    PROMPT
  end

  def get_special_instructions(chapter_num)
    if chapter_num == 1
      'This is the first chapter - introduce the main character and establish the workplace setting.'
    elsif chapter_num <= 3
      'This is an early chapter - continue building the world and introducing characters.'
    else
      'Build on established relationships and escalate the comedy.'
    end
  end

  def prepare_chapter_file(chapter_num, characters)
    filename = "_chapters/#{format_chapter_filename(chapter_num)}"

    front_matter = {
      'layout' => 'chapter',
      'title' => "Chapter #{chapter_num}: [Title to be generated]",
      'chapter_number' => chapter_num,
      'characters' => characters.map { |c| c['slug'] },
      'new_characters' => [], # To be filled during generation
      'summary' => '[Summary to be generated]',
      'generated_date' => Date.today.to_s,
      'status' => 'pending',
      'lang' => 'en'
    }

    File.open(filename, 'w') do |file|
      file.puts '---'
      file.puts front_matter.to_yaml.lines[1..] # Skip first "---" line
      file.puts '---'
      file.puts ''
      file.puts '<!-- Chapter content will be generated here -->'
      file.puts ''
      file.puts '<!-- After generating content, update the front matter with: -->'
      file.puts '<!--   - Actual chapter title -->'
      file.puts '<!--   - Chapter summary -->'
      file.puts '<!--   - Any new characters introduced -->'
      file.puts "<!--   - Change status from 'pending' to 'completed' -->"
      file.puts ''
    end
  end

  def extract_chapter_content(file_path)
    content = File.read(file_path)
    parts = content.split(/^---\s*$/, 3)

    if parts.length >= 3
      parts[2].strip
    else
      ''
    end
  end

  def update_chapter_content(file_path, new_content)
    current_content = File.read(file_path)
    parts = current_content.split(/^---\s*$/, 3)

    if parts.length >= 3
      # Keep front matter, replace content
      File.write(file_path, "---\n#{parts[1]}---\n\n#{new_content}")
    else
      puts 'Warning: Could not parse chapter file structure'
    end
  end

  def update_chapter_with_structured_content(file_path, chapter_data)
    current_content = File.read(file_path)
    parts = current_content.split(/^---\s*$/, 3)

    if parts.length >= 3
      # Update front matter
      front_matter = YAML.load(parts[1]) || {}
      front_matter['title'] = chapter_data['title']
      front_matter['summary'] = chapter_data['summary'] if chapter_data['summary']
      front_matter['status'] = 'regenerated'
      front_matter['regenerated_date'] = Date.today.to_s

      # Write updated file
      File.open(file_path, 'w') do |file|
        file.puts '---'
        file.puts front_matter.to_yaml.lines[1..]
        file.puts '---'
        file.puts ''
        file.puts chapter_data['content']
        file.puts ''
      end
    else
      puts 'Warning: Could not parse chapter file structure'
    end
  end

  def create_character_page(slug, character_data)
    filename = "_characters/#{slug}.md"

    # Generate proper permalink for Jekyll Polyglot (use dashes, not underscores)
    permalink_slug = slug.gsub('_', '-')
    permalink = "/characters/#{permalink_slug}/"

    front_matter = {
      'layout' => 'character',
      'name' => character_data['name'],
      'slug' => slug,
      'description' => character_data['description'],
      'personality_traits' => character_data['personality_traits'] || [],
      'programming_skills' => character_data['programming_skills'],
      'first_appearance' => character_data['first_appearance'],
      'permalink' => permalink,
      'created_date' => Date.today.to_s,
      'lang' => 'en'
    }

    File.open(filename, 'w') do |file|
      file.puts '---'
      file.puts front_matter.to_yaml.lines[1..]
      file.puts '---'
      file.puts ''

      file.puts "## About #{character_data['name']}"
      file.puts ''
      file.puts character_data['description']
      file.puts ''

      if character_data['backstory']
        file.puts '## Backstory'
        file.puts ''
        file.puts character_data['backstory']
        file.puts ''
      end

      if character_data['quirks']
        file.puts '## Notable Quirks'
        file.puts ''
        file.puts character_data['quirks']
        file.puts ''
      end

      if character_data['catchphrase']
        file.puts '## Catchphrase'
        file.puts ''
        file.puts "> \"#{character_data['catchphrase']}\""
        file.puts ''
      end

      file.puts '## Appearances'
      file.puts ''
      file.puts "First appeared in: #{character_data['first_appearance'] || 'To be determined'}"
      file.puts ''
      file.puts '<!-- Chapter appearances will be tracked automatically -->'
    end
  end

  def slugify(name)
    name.downcase.gsub(/[^a-z0-9\u0430-\u044f]+/, '_').gsub(/^_+|_+$/, '')
  end

  def format_chapter_filename(chapter_num)
    "#{chapter_num.to_s.rjust(3, '0')}-chapter.md"
  end

  def update_metadata(chapter_num)
    @book_data['book']['current_chapter'] = chapter_num
    @book_data['status']['last_generated'] = Date.today.to_s
    @book_data['status']['generation_count'] += 1

    save_book_data(@book_data)

    # Log generation
    log_generation('chapter', "chapter-#{format('%03d', chapter_num)}", {
                     'language' => 'en',
                     'characters_involved' => [],
                     'new_characters' => [],
                     'chapter_number' => chapter_num
                   })
  end

  def display_chapter_summary(chapter_data)
    puts "\n📊 Chapter Generation Summary"
    puts '=' * 40
    puts "Title: #{chapter_data['title']}"
    puts "Word Count: #{chapter_data['word_count'] || 'Not specified'}"
    puts "Difficulty: #{chapter_data['difficulty_level'] || 'Not specified'}"

    if chapter_data['programming_themes']&.any?
      puts "Programming Themes: #{chapter_data['programming_themes'].join(', ')}"
    end

    puts "Comedy Elements: #{chapter_data['comedy_elements'].join(', ')}" if chapter_data['comedy_elements']&.any?

    if chapter_data['one_punch_man_references']&.any?
      puts "One-Punch Man References: #{chapter_data['one_punch_man_references'].join(', ')}"
    end

    if chapter_data['new_characters']&.any?
      puts "New Characters: #{chapter_data['new_characters'].map { |c| c['name'] }.join(', ')}"
    end

    puts '=' * 40
  end

  def get_characters_by_slugs(character_slugs)
    character_slugs.map do |slug|
      @characters['characters'][slug]
    end.compact
  end

  def update_book_progress(current_chapter)
    @book_data['book']['current_chapter'] = current_chapter

    # Initialize chapters_written if it doesn't exist
    @book_data['status']['chapters_written'] ||= 0
    @book_data['status']['chapters_written'] += 1

    @book_data['status']['last_generated'] = Date.today.to_s
    @book_data['status']['generation_count'] ||= 0
    @book_data['status']['generation_count'] += 1

    save_book_data(@book_data)
    puts "📈 Updated book progress: Chapter #{current_chapter} completed"
  end
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  generator = ChapterGenerator.new

  case ARGV[0]
  when 'next', 'generate', nil
    auto_generate = ARGV.include?('--auto')
    generator.generate_next_chapter(auto_generate: auto_generate)

  when 'improve'
    chapter_num = ARGV[1]&.to_i
    improvement_type = ARGV[2] || 'humor'

    if chapter_num&.positive?
      generator.improve_chapter(chapter_num, improvement_type)
    else
      puts 'Usage: ruby generate_chapter.rb improve <chapter_number> [humor|clarity|consistency]'
    end

  when 'regenerate'
    chapter_num = ARGV[1]&.to_i

    if chapter_num&.positive?
      generator.regenerate_chapter(chapter_num)
    else
      puts 'Usage: ruby generate_chapter.rb regenerate <chapter_number>'
    end

  when 'prompt'
    chapter_num = ARGV[1]&.to_i

    if chapter_num&.positive?
      generator.regenerate_prompt(chapter_num)
    else
      puts 'Usage: ruby generate_chapter.rb prompt <chapter_number>'
    end

  else
    puts 'One Review Man - Chapter Generator'
    puts ''
    puts 'Usage:'
    puts '  ruby generate_chapter.rb [next|generate]     # Generate next chapter'
    puts '  ruby generate_chapter.rb next --auto         # Generate without prompts'
    puts '  ruby generate_chapter.rb improve <num> [type] # Improve existing chapter'
    puts '  ruby generate_chapter.rb regenerate <num>    # Regenerate chapter with AI'
    puts '  ruby generate_chapter.rb prompt <num>        # Show prompt for chapter'
    puts ''
    puts 'Improvement types: humor, clarity, consistency'
  end
end
