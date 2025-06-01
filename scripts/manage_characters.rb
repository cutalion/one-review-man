#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'date'
require_relative 'book_utils'
require_relative 'llm_service'

class CharacterManager
  include BookUtils

  def initialize
    # Always work with English
    @characters = load_characters
    @book_data = load_book_data
    @llm_service = LLMService.new
  end

  def generate_character(character_type = 'side')
    # Handle special character types
    case character_type.downcase
    when 'protagonist'
      return generate_one_review_man
    when 'disciple'
      return generate_ai_disciple
    end

    puts "🤖 Generating new #{character_type} character with AI..."

    prompt = build_character_generation_prompt(character_type)

    begin
      character_data = @llm_service.generate_character(prompt)

      if character_data && character_data['name']
        # Clean up and validate character data
        processed_character = process_generated_character(character_data)

        success = add_character(processed_character)

        if success
          puts "✅ Character '#{processed_character['name']}' generated and created successfully!"
          return processed_character
        end
      else
        puts '❌ Failed to generate valid character data'
        puts('Character data: ', character_data.inspect)
      end
    rescue LLMService::LLMError => e
      puts "❌ Character generation failed: #{e.message}"
      puts "Consider creating a character manually with 'ruby manage_characters.rb add'"
    end

    nil
  end

  def generate_one_review_man
    puts '🤖 Generating One Review Man - the ultimate programmer...'

    # Check if One Review Man already exists
    if character_exists?('one_review_man')
      puts "One Review Man already exists! Use 'list' to see existing characters."
      return nil
    end

    # Build specific prompt for One Review Man
    prompt = build_one_review_man_prompt

    begin
      character_data = @llm_service.generate_character(prompt)

      if character_data && character_data['name']
        # Clean up and validate character data
        processed_character = process_generated_character(character_data)

        # Ensure canonical name and first appearance
        processed_character['name'] = 'One Review Man'
        processed_character['first_appearance'] = 'Chapter 1'

        success = add_character(processed_character)

        if success
          puts '✅ One Review Man has been created! The ultimate programmer has joined the story.'
          return processed_character
        end
      else
        puts '❌ Failed to generate valid character data for One Review Man'
        puts('Character data: ', character_data.inspect)
      end
    rescue LLMService::LLMError => e
      puts "❌ One Review Man generation failed: #{e.message}"
      puts 'Consider creating the character manually'
    end

    nil
  end

  def generate_ai_disciple
    puts "🤖 Generating AI-Enhanced Disciple - One Review Man's devoted student..."

    # Check if the disciple already exists
    if character_exists?('ai_enhanced_disciple')
      puts "AI-Enhanced Disciple already exists! Use 'list' to see existing characters."
      return nil
    end

    # Build specific prompt for AI-Enhanced Disciple
    prompt = build_ai_disciple_prompt

    begin
      character_data = @llm_service.generate_character(prompt)

      if character_data && character_data['name']
        # Clean up and validate character data
        processed_character = process_generated_character(character_data)

        # Ensure canonical name and first appearance
        processed_character['name'] = 'AI-Enhanced Disciple'
        processed_character['first_appearance'] = 'Chapter 1'
        processed_character['relationships'] = ['One Review Man (master/mentor)']

        success = add_character(processed_character)

        if success
          puts '✅ AI-Enhanced Disciple has been created! One Review Man now has a devoted student.'
          return processed_character
        end
      else
        puts '❌ Failed to generate valid character data for AI-Enhanced Disciple'
        puts('Character data: ', character_data.inspect)
      end
    rescue LLMService::LLMError => e
      puts "❌ AI-Enhanced Disciple generation failed: #{e.message}"
      puts 'Consider creating the character manually'
    end

    nil
  end

  def list_characters
    puts "\n=== Characters ==="
    @characters['characters'].each do |slug, char|
      puts "#{char['name']} (#{slug})"
      puts "  Description: #{char['description']}"
      puts "  First appearance: #{char['first_appearance'] || 'Not yet appeared'}"
      puts "  Traits: #{char['personality_traits']&.join(', ') || 'None listed'}"
      puts "  Skills: #{char['programming_skills'] || 'General programming'}"
      puts ''
    end
  end

  private

  def add_character(character_data)
    slug = slugify(character_data['name'])

    if character_exists?(slug)
      puts "Character '#{character_data['name']}' already exists!"
      return false
    end

    # Add to characters data
    @characters['characters'][slug] = character_data.merge({
                                                             'slug' => slug,
                                                             'created_date' => Date.today.to_s
                                                           })

    # Create character page
    create_character_page(slug, character_data)

    # Update metadata
    @book_data['status']['characters_created'] += 1

    # Save changes
    save_characters(@characters)
    save_book_data(@book_data)

    puts "Character '#{character_data['name']}' created successfully!"
    true
  end

  def character_exists?(slug)
    @characters['characters'].key?(slug)
  end

  def build_character_generation_prompt(character_type)
    template_file = 'scripts/prompts/character_prompts.txt'
    raise "Prompt template not found at #{template_file}" unless File.exist?(template_file)

    template = File.read(template_file)

    # Safely handle characters data
    characters_hash = @characters['characters'] || {}
    existing_chars_context = characters_hash.map do |_slug, char|
      "#{char['name']}: #{char['description']}"
    end.join("\n")

    character_type_mapping = {
      'main' => 'MAIN CHARACTERS (Protagonists)',
      'hero' => 'HERO CHARACTERS (Fellow Programmers)',
      'villain' => 'VILLAIN CHARACTERS (Bad Coders/Practices)',
      'side' => 'SIDE CHARACTERS (Workplace NPCs)',
      'mentor' => 'MENTOR CHARACTERS (Senior Figures)'
    }

    mapped_type = character_type_mapping[character_type.downcase]
    raise "Character type not found in mapping: #{character_type_mapping}" unless mapped_type

    template
      .gsub('{CHARACTER_TYPE}', mapped_type)
      .gsub('{EXISTING_CHARACTERS_CONTEXT}', existing_chars_context.empty? ? 'No existing characters yet.' : "Existing characters:\n#{existing_chars_context}")
      .gsub('{SPECIAL_REQUIREMENTS}', "Create a #{character_type} character that fits the One Review Man universe.")
  end

  def build_one_review_man_prompt
    existing_chars_context = get_existing_characters_context

    <<~PROMPT
      Create the main protagonist character "One Review Man" for a programming parody of One-Punch Man.

      CONTEXT:
      This is a humorous parody where One Review Man is like Saitama - overpowered but bored. He's a programmer who writes perfect code that passes every code review on the first try.

      NAMING CONVENTIONS:
      - Professional Name: "One Review Man" (like "One-Punch Man" is Saitama's hero name)
      - Real Name: "Satoru" (parody of Saitama's real name)
      - Most people call him "One Review Man" or respectful variations
      - Only his disciple (AI-Enhanced Disciple) calls him "Satoru" or "Satoru-sensei"
      - He calls his disciple "Genki" when they talk privately

      EXISTING CHARACTERS:
      #{existing_chars_context.empty? ? 'No existing characters yet.' : existing_chars_context}

      CHARACTER REQUIREMENTS:
      - Name: "One Review Man" (professional title/hero name)
      - Real Name: "Satoru" (his actual given name)
      - Must be the ultimate programmer (like Saitama is the ultimate hero)
      - Writes flawless code that never needs revisions
      - All pull requests are instantly approved and merged
      - Has become bored with his overwhelming programming abilities
      - Parodies Saitama's personality: calm, humble, unimpressed by challenges
      - Should have a simple catchphrase (like Saitama's "OK")
      - Training backstory should parody Saitama's training regimen
      - Maintains simple appearance despite incredible abilities
      - Shows casual, mentor-like relationship with his disciple

      PROGRAMMING COMEDY ELEMENTS:
      - Code review scenarios
      - Debugging mastery
      - Framework/language mastery
      - Production deployment confidence
      - Mentoring other developers
      - Nonchalant attitude toward "impossible" programming challenges

      Please generate this character with typical fields: name, real_name, description, personality_traits, programming_skills, catchphrase, backstory, quirks.
      Remember: Most colleagues call him "One Review Man", only his disciple uses "Satoru".
    PROMPT
  end

  def build_ai_disciple_prompt
    existing_chars_context = get_existing_characters_context

    <<~PROMPT
      Create the "AI-Enhanced Disciple" character for a programming parody of One-Punch Man.

      CONTEXT:
      This character is the Genos equivalent - a cyborg-like programmer with AI enhancements who desperately wants to learn from One Review Man.

      NAMING CONVENTIONS:
      - Professional Name: "AI-Enhanced Disciple" (like "Demon Cyborg" is Genos's hero classification)
      - Real Name: "Genki" (parody of Genos's real name)
      - Most people call him "AI-Enhanced Disciple" or "Disciple-kun"
      - One Review Man (Satoru) calls him "Genki" in private conversations
      - He calls One Review Man "Satoru-sensei" or "Master" (the only one who uses his real name)

      EXISTING CHARACTERS:
      #{existing_chars_context.empty? ? 'No existing characters yet.' : existing_chars_context}

      CHARACTER REQUIREMENTS:
      - Name: "AI-Enhanced Disciple" (professional title/hero designation)
      - Real Name: "Genki" (his actual given name)
      - Must be like Genos - dedicated student/disciple
      - Has cybernetic/AI enhancements for programming
      - Uses advanced technology but still can't match One Review Man's natural perfection
      - Extremely dedicated and analytical
      - Takes detailed notes and documentation
      - Speaks formally and respectfully, especially to "Satoru-sensei"
      - Technology-obsessed personality
      - Parodies Genos's relationship with Saitama
      - Shows deep respect and admiration for his master

      PROGRAMMING/AI ELEMENTS:
      - Neurointerface technology
      - AI-assisted programming
      - Machine learning integration
      - Advanced debugging tools
      - Still makes mistakes despite technology
      - Overcomplicates simple solutions
      - Constantly seeks to understand Satoru's "simple" methods

      DIALOGUE CHARACTERISTICS:
      - Formal, technical speech patterns
      - Addresses One Review Man as "Satoru-sensei" or "Master"
      - Uses programming jargon extensively
      - Shows reverence and dedication in speech

      Please generate this character with typical fields: name, real_name, description, personality_traits, programming_skills, catchphrase, backstory, quirks.
      The character should have a respectful catchphrase directed at One Review Man using "Satoru-sensei" (like "Sensei, please teach me your techniques!").
    PROMPT
  end

  def get_existing_characters_context
    characters_hash = @characters['characters'] || {}
    characters_hash.map do |_slug, char|
      "#{char['name']}: #{char['description']}"
    end.join("\n")
  end

  def process_generated_character(character_data)
    # Ensure required fields and clean up data
    processed = {
      'name' => character_data['name']&.strip,
      'description' => character_data['description']&.strip,
      'personality_traits' => extract_traits(character_data),
      'programming_skills' => character_data['programming_skills']&.strip || 'General programming',
      'catchphrase' => character_data['catchphrase']&.strip,
      'backstory' => character_data['backstory']&.strip,
      'quirks' => character_data['quirks']&.strip
    }.compact # Remove nil/empty values

    # Ensure name exists
    processed['name'] = 'Generated Character' unless processed['name'] && !processed['name'].empty?

    # Ensure description exists
    unless processed['description'] && !processed['description'].empty?
      processed['description'] = 'A programmer with unique abilities'
    end

    processed
  end

  def extract_traits(character_data)
    traits = character_data['personality_traits'] || character_data['traits']

    case traits
    when Array
      traits.map(&:strip).reject(&:empty?)
    when String
      traits.split(',').map(&:strip).reject(&:empty?)
    else
      []
    end
  end

  def create_character_page(slug, character_data)
    filename = "_characters/#{slug}.md"

    front_matter = {
      'layout' => 'character',
      'name' => character_data['name'],
      'slug' => slug,
      'description' => character_data['description'],
      'personality_traits' => character_data['personality_traits'] || [],
      'programming_skills' => character_data['programming_skills'],
      'first_appearance' => character_data['first_appearance'],
      'relationships' => character_data['relationships'] || [],
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

      if character_data['programming_skills']
        file.puts '## Programming Skills'
        file.puts ''
        file.puts character_data['programming_skills']
        file.puts ''
      end

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
end

# Command line interface
if __FILE__ == $PROGRAM_NAME
  manager = CharacterManager.new

  case ARGV[0]
  when 'generate'
    character_type = ARGV[1] || 'side'
    manager.generate_character(character_type)

  when 'protagonist'
    manager.generate_one_review_man

  when 'disciple'
    manager.generate_ai_disciple

  when 'list'
    manager.list_characters

  else
    puts 'One Review Man - Character Manager'
    puts ''
    puts 'Usage:'
    puts '  ruby manage_characters.rb generate [type]  # Generate character with AI'
    puts '  ruby manage_characters.rb protagonist      # Generate One Review Man himself'
    puts '  ruby manage_characters.rb disciple        # Generate AI-Enhanced Disciple'
    puts '  ruby manage_characters.rb list             # List all characters'
    puts ''
    puts 'Character types: main, hero, villain, side, mentor'
    puts ''
    puts 'Examples:'
    puts '  ruby manage_characters.rb protagonist      # Generate One Review Man (main protagonist)'
    puts '  ruby manage_characters.rb disciple        # Generate AI-Enhanced Disciple (Genos equivalent)'
    puts '  ruby manage_characters.rb generate main    # Generate a main character/protagonist'
    puts '  ruby manage_characters.rb generate hero    # Generate a hero character'
    puts '  ruby manage_characters.rb list             # Show all characters'
  end
end
