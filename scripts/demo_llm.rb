#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'book_utils'
require_relative 'llm_service'
require_relative 'generate_chapter'
require_relative 'manage_characters'

# Demonstration script for LLM-powered content generation
class LLMDemo
  include BookUtils

  def initialize
    @llm_service = LLMService.new
    @chapter_generator = ChapterGenerator.new
    @character_manager = CharacterManager.new
  end

  def run_demo
    puts '🎭 One Review Man - LLM Generation Demo'
    puts '=' * 50
    puts ''

    puts 'This demo will show you how to:'
    puts '1. Generate characters with AI'
    puts '2. Generate chapters with AI'
    puts '3. Improve existing content'
    puts '4. Interactive Chat with LLM'
    puts '5. Show Configuration Help'
    puts ''

    puts '⚠️  Note: If no LLM is configured, mock responses will be used'
    puts ''

    loop do
      show_menu
      choice = gets.chomp.downcase

      case choice
      when '1'
        demo_character_generation
      when '2'
        demo_chapter_generation
      when '3'
        demo_content_improvement
      when '4'
        demo_interactive_chat
      when '5'
        show_configuration_help
      when 'q', 'quit', 'exit'
        puts '👋 Thanks for trying the LLM demo!'
        break
      else
        puts 'Invalid choice. Please try again.'
      end

      puts "\nPress Enter to continue..."
      gets
    end
  end

  private

  def show_menu
    puts "\n🤖 LLM Demo Menu"
    puts '-' * 30
    puts '1. Generate Character with AI'
    puts '2. Generate Chapter with AI'
    puts '3. Improve Existing Content'
    puts '4. Interactive Chat with LLM'
    puts '5. Show Configuration Help'
    puts 'Q. Quit'
    puts ''
    print 'Choose an option: '
  end

  def demo_character_generation
    puts "\n🎭 Character Generation Demo"
    puts '-' * 40

    puts 'Available character types:'
    puts '- hero: Fellow programmers with impressive skills'
    puts '- villain: Bad coders representing poor practices'
    puts '- side: Workplace NPCs for comic relief'
    puts '- mentor: Senior figures with wisdom'
    puts ''
    puts '💡 NAMING CONVENTIONS:'
    puts '- Characters have professional names (workplace titles) and may have real names'
    puts '- One Review Man (real name: Satoru) - only his disciple uses his real name'
    puts '- AI-Enhanced Disciple (real name: Genki) - Satoru calls him by his real name'
    puts '- Other characters may have both professional and personal names'
    puts ''

    print "Enter character type (or press Enter for 'side'): "
    char_type = gets.chomp
    char_type = 'side' if char_type.empty?

    puts "\n🤖 Generating #{char_type} character..."

    begin
      character = @character_manager.generate_character(char_type)

      if character
        puts "\n✅ Character Generated Successfully!"
        puts "Name: #{character['name']}"
        puts "Real Name: #{character['real_name']}" if character['real_name'] && character['real_name'] != character['name']
        puts "Description: #{character['description']}"
        puts "Skills: #{character['programming_skills']}"
        puts "Traits: #{character['personality_traits']&.join(', ')}"
        puts "Catchphrase: #{character['catchphrase']}" if character['catchphrase']
        puts ''
        puts "Character saved to _characters/#{character['name'].downcase.gsub(/[^a-z0-9]/, '_')}.md"
      else
        puts '❌ Character generation failed'
      end
    rescue StandardError => e
      puts "❌ Error: #{e.message}"
    end
  end

  def demo_chapter_generation
    puts "\n📖 Chapter Generation Demo"
    puts '-' * 40

    book_data = load_book_data('en')
    current_chapter = book_data.dig('book', 'current_chapter') || 0
    next_chapter = current_chapter + 1

    puts "Next chapter to generate: Chapter #{next_chapter}"
    puts ''

    print 'Generate chapter automatically? (y/n): '
    auto = gets.chomp.downcase

    if %w[y yes].include?(auto)
      puts "\n🤖 Generating Chapter #{next_chapter}..."

      begin
        @chapter_generator.generate_next_chapter(auto_generate: true)
        puts "\n✅ Chapter generation completed!"
        puts 'Check _chapters/ directory for the new chapter file'
      rescue StandardError => e
        puts "❌ Error: #{e.message}"
      end
    else
      puts 'Use: ruby scripts/generate_chapter.rb next'
      puts 'This will prompt you through the generation process'
    end
  end

  def demo_content_improvement
    puts "\n✨ Content Improvement Demo"
    puts '-' * 40

    puts 'Improvement types:'
    puts '- humor: Make content funnier'
    puts '- clarity: Improve readability and flow'
    puts '- consistency: Ensure consistency with established world'
    puts ''

    # Show available content to improve
    characters = load_characters('en')
    chapters = get_all_chapters('en')

    if characters['characters'].any?
      puts 'Available characters to improve:'
      characters['characters'].each do |slug, char|
        puts "  - #{slug} (#{char['name']})"
      end
      puts ''
    end

    if chapters.any?
      puts 'Available chapters to improve:'
      chapters.each do |chapter|
        puts "  - Chapter #{chapter['chapter_number']}: #{chapter['title']}"
      end
      puts ''
    end

    print 'Improve character or chapter? (character/chapter): '
    content_type = gets.chomp.downcase

    case content_type
    when 'character'
      if characters['characters'].any?
        print 'Enter character slug: '
        slug = gets.chomp

        print 'Improvement type (humor/clarity/consistency): '
        improvement = gets.chomp
        improvement = 'humor' if improvement.empty?

        puts "\n🤖 Improving character..."
        @character_manager.improve_character(slug, improvement)
      else
        puts 'No characters available to improve'
      end

    when 'chapter'
      if chapters.any?
        print 'Enter chapter number: '
        chapter_num = gets.chomp.to_i

        print 'Improvement type (humor/clarity/consistency): '
        improvement = gets.chomp
        improvement = 'humor' if improvement.empty?

        puts "\n🤖 Improving chapter..."
        @chapter_generator.improve_chapter(chapter_num, improvement)
      else
        puts 'No chapters available to improve'
      end
    else
      puts 'Invalid content type'
    end
  end

  def demo_interactive_chat
    puts "\n💬 Interactive Chat Demo"
    puts '-' * 40
    puts 'Chat with the LLM about One Review Man content'
    puts "Type 'quit' to return to main menu"
    puts ''

    context = "You are discussing 'One Review Man', a programming comedy parody of One-Punch Man. The story follows a super-programmer who writes perfect code and gets all pull requests approved on first review. IMPORTANT NAMING: The protagonist's real name is Satoru (like Saitama), but most people call him 'One Review Man'. His disciple's real name is Genki (like Genos), professional title 'AI-Enhanced Disciple'. Only Genki calls him 'Satoru-sensei', everyone else uses 'One Review Man'. When Satoru and Genki speak privately, they use real names. RUSSIAN TRANSLATION: 'One Review Man' becomes 'Ванревьюмен' (like 'One Punch Man' → 'Ванпанчмен'), real names become 'Сатору' and 'Генки'."

    loop do
      print 'You: '
      message = gets.chomp

      break if %w[quit exit back].include?(message.downcase)

      if message.strip.empty?
        puts 'Please enter a message'
        next
      end

      puts "\n🤖 LLM: "
      begin
        response = @llm_service.chat_with_llm(message, context)
        puts response
      rescue StandardError => e
        puts "❌ Error: #{e.message}"
      end
      puts ''
    end
  end

  def show_configuration_help
    puts "\n⚙️  LLM Configuration Help"
    puts '-' * 40

    # Check environment variables first
    env_api_key = ENV.fetch('OPENAI_API_KEY', nil)
    env_org = ENV.fetch('OPENAI_ORG_ID', nil)
    env_project = ENV.fetch('OPENAI_PROJECT_ID', nil)
    env_base_url = ENV.fetch('OPENAI_BASE_URL', nil)

    config_file = 'scripts/llm_config.yml'
    config = {}

    if File.exist?(config_file)
      puts "✅ Configuration file found at: #{config_file}"
      config = begin
        YAML.load_file(config_file)
      rescue StandardError
        {}
      end
    else
      puts "❌ No configuration file found at: #{config_file}"
    end

    # Check API key configuration
    if env_api_key
      puts '✅ OpenAI API key found in environment variable'
    elsif config['openai_api_key'] && !config['openai_api_key'].to_s.empty?
      puts '⚠️  OpenAI API key found in config file (consider using environment variable)'
    else
      puts '❌ No OpenAI API key found'
      puts '   Set OPENAI_API_KEY environment variable or add to config file'
    end

    # Show current settings
    puts ''
    puts 'Current settings:'
    puts "  Default Model: #{config['model'] || 'gpt-4o-mini (default)'}"

    # Show task-specific models if configured
    if config['models']
      puts '  Task-specific models:'
      config['models'].each do |task, model|
        puts "    #{task.capitalize}: #{model}"
      end
    end

    puts "  Timeout: #{config['timeout'] || 240} seconds"
    puts "  Max retries: #{config['max_retries'] || 2}"

    puts "  Organization: #{env_org || config['openai_org_id']}" if env_org || config['openai_org_id']

    puts "  Project: #{env_project || config['openai_project_id']}" if env_project || config['openai_project_id']

    puts "  Base URL: #{env_base_url || config['openai_base_url']}" if env_base_url || config['openai_base_url']

    puts ''
    puts '🔒 RECOMMENDED SETUP:'
    puts 'Set environment variables (keeps secrets out of git):'
    puts '  export OPENAI_API_KEY="your-api-key-here"'
    puts '  export OPENAI_ORG_ID="your-org-id"        # optional'
    puts '  export OPENAI_PROJECT_ID="your-project"   # optional'
    puts ''
    puts 'Get your API key from: https://platform.openai.com/api-keys'
    puts ''
    puts 'Available models:'
    puts '  • gpt-4o-mini (recommended, fast and cost-effective)'
    puts '  • gpt-4o (most capable, higher cost)'
    puts '  • gpt-4-turbo (good balance of speed and capability)'
    puts '  • gpt-3.5-turbo (fastest and cheapest)'
    puts ''
    puts '🎯 TASK-SPECIFIC MODELS:'
    puts 'You can now configure different models for different tasks:'
    puts '  • Generation (chapters/characters): Use gpt-4o for higher quality content'
    puts '  • Translation: Use gpt-4o-mini for fast, cost-effective translation'
    puts '  • Chat: Use gpt-4o-mini for quick interactive responses'
    puts ''
    puts 'Edit scripts/llm_config.yml to customize task-specific models and options.'
    puts ''
    puts 'Without API key, the system will use mock responses for development.'
  end
end

# Command line execution
if __FILE__ == $PROGRAM_NAME
  if ARGV[0] == 'setup'
    puts '🔧 Setting up LLM configuration...'

    # Try to create config by running LLM service once
    begin
      LLMService.new
      puts '✅ Example configuration created at scripts/llm_config.yml'
      puts 'Please edit this file with your API keys and preferences'
    rescue StandardError => e
      puts "❌ Setup failed: #{e.message}"
    end
  else
    demo = LLMDemo.new
    demo.run_demo
  end
end
