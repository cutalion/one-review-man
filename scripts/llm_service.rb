#!/usr/bin/env ruby
# frozen_string_literal: true

require 'openai'
require 'yaml'
require 'json'
require_relative 'prompt_utils'

# LLM Service for generating content via OpenAI API
# This service acts as an abstraction layer that could support multiple providers in the future
class LLMService
  class LLMError < StandardError; end
  class ConfigurationError < LLMError; end
  class APIError < LLMError; end

  DEFAULT_MODEL = 'gpt-4o-mini'

  # Models that use max_completion_tokens instead of max_tokens
  O3_MODELS = %w[o3-mini o3].freeze

  def initialize(config_file = 'scripts/llm_config.yml', model_override = nil)
    @config = load_config(config_file)
    @model_override = model_override
    @client = setup_client
  end

  def generate_chapter(prompt, options = {})
    puts '🤖 Generating chapter content...'

    options = get_task_options(
      'generation',
      {
        temperature: 0.7,
        system_prompt: 'You are a creative writer specializing in programming humor and parody. Write engaging, funny content that captures the absurdist spirit of programming culture.'
      }
    ).merge(options)

    response = call_llm(prompt, options, 'generation')

    raise APIError, 'Failed to generate chapter content' unless response && response['content']

    puts '✅ Chapter generated successfully!'
    response['content']
  end

  def generate_chapter_structured(prompt, options = {})
    puts '🤖 Generating structured chapter content...'

    # Add JSON schema to the prompt
    enhanced_prompt = build_chapter_prompt_with_schema(prompt)

    response = call_llm_structured(enhanced_prompt, get_task_options('generation', {
                                                                       temperature: 0.7,
                                                                       system_prompt: 'You are a creative writer specializing in programming humor and parody. Write engaging, funny content that captures the absurdist spirit of programming culture. Respond with valid JSON only.',
                                                                       response_format: { type: 'json_object' }
                                                                     }).merge(options), 'generation')

    raise APIError, 'Failed to generate chapter content' unless response && response['content']

    puts '✅ Structured chapter generated successfully!'

    # Parse JSON response
    begin
      chapter_data = JSON.parse(response['content'])
      validate_chapter_data(chapter_data)
      chapter_data
    rescue JSON::ParserError => e
      puts "❌ JSON parsing error: #{e.message}"
      puts "Raw response: #{response['content']}"
      # Fallback to old text-based chapter generation
      parse_chapter_content(response['content'])
    end
  end

  def generate_character(prompt, options = {})
    puts '🤖 Generating character...'

    # Add JSON schema to the prompt instead of using unsupported schema parameter
    enhanced_prompt = build_character_prompt_with_schema(prompt)

    # Use structured outputs for reliable character data
    response = call_llm_structured(enhanced_prompt, get_task_options('generation', {
                                                                       temperature: 0.8,
                                                                       system_prompt: 'You are a character designer for programming comedy stories. Create memorable, funny characters that fit the tech/programming world. Respond with valid JSON only.',
                                                                       response_format: { type: 'json_object' }
                                                                     }).merge(options), 'generation')

    raise APIError, 'Failed to generate character' unless response && response['content']

    puts '✅ Character generated successfully!'

    # Parse JSON response
    begin
      character_data = JSON.parse(response['content'])
      validate_character_data(character_data)
      character_data
    rescue JSON::ParserError => e
      puts "❌ JSON parsing error: #{e.message}"
      puts "Raw response: #{response['content']}"
      # Fallback to old parsing method
      parse_character_response(response['content'])
    end
  end

  def improve_content(content, improvement_type, options = {})
    puts "🤖 Improving content (#{improvement_type})..."

    system_prompts = {
      'humor' => 'You are an expert comedy writer. Make the content funnier while maintaining its core message.',
      'clarity' => 'You are an expert editor. Improve the clarity and flow of the content while maintaining its style.',
      'consistency' => 'You are an expert continuity editor. Ensure the content is consistent with established characters and world-building.'
    }

    prompt = build_improvement_prompt(content, improvement_type)

    response = call_llm(prompt, get_task_options('generation', {
                                                   temperature: 0.6,
                                                   system_prompt: system_prompts[improvement_type] || system_prompts['clarity']
                                                 }).merge(options), 'generation')

    raise APIError, 'Failed to improve content' unless response && response['content']

    puts '✅ Content improved successfully!'
    response['content']
  end

  def chat_with_llm(message, context = nil, options = {})
    puts '🤖 Processing request...'

    prompt = context ? "#{context}\n\nUser: #{message}" : message

    response = call_llm(prompt, get_task_options('chat', {
                                                   temperature: 0.7
                                                 }).merge(options), 'chat')

    raise APIError, 'Failed to get response from LLM' unless response && response['content']

    response['content']
  end

  def translate_chapter_structured(title, summary, content, target_lang)
    puts "🤖 Translating chapter to #{target_lang}..."

    # Build translation prompt with schema
    prompt = build_chapter_translation_prompt(title, summary, content, target_lang)

    options = get_task_options(
      'translation',
      {
        temperature: 0.3,
        system_prompt: 'You are a professional translator specializing in programming humor and technical content. Translate accurately while preserving the comedy and technical references. Respond with valid JSON only.',
        response_format: { type: 'json_object' }
      }
    )
    response = call_llm_structured(prompt, options, 'translation')

    raise APIError, 'Failed to translate chapter' unless response && response['content']

    puts '✅ Chapter translation completed!'

    # Parse JSON response
    begin
      translation_data = JSON.parse(response['content'])
      validate_chapter_translation_data(translation_data)
      translation_data
    rescue JSON::ParserError => e
      puts "❌ JSON parsing error: #{e.message}"
      puts "Raw response: #{response['content']}"
      # Fallback to simple translation
      fallback_chapter_translation(title, summary, content, target_lang)
    end
  end

  def translate_character_structured(name, description, personality_traits, programming_skills, catchphrase, backstory,
                                     quirks, target_lang)
    puts "🤖 Translating character to #{target_lang}..."

    # Build translation prompt with schema
    prompt = build_character_translation_prompt(name, description, personality_traits, programming_skills, catchphrase,
                                                backstory, quirks, target_lang)

    response = call_llm_structured(prompt, get_task_options('translation', {
                                                              temperature: 0.3, # Lower temperature for more consistent translation
                                                              system_prompt: 'You are a professional translator specializing in programming humor and character development. Translate character details accurately while preserving personality and humor. Respond with valid JSON only.',
                                                              response_format: { type: 'json_object' }
                                                            }), 'translation')

    raise APIError, 'Failed to translate character' unless response && response['content']

    puts '✅ Character translation completed!'

    # Parse JSON response
    begin
      translation_data = JSON.parse(response['content'])
      validate_character_translation_data(translation_data)
      translation_data
    rescue JSON::ParserError => e
      puts "❌ JSON parsing error: #{e.message}"
      puts "Raw response: #{response['content']}"
      # Fallback to simple translation
      fallback_character_translation(name, description, personality_traits, programming_skills, catchphrase, backstory,
                                     quirks, target_lang)
    end
  end

  private

  def load_config(config_file)
    if File.exist?(config_file)
      YAML.load_file(config_file) || {}
    else
      puts "⚠️  LLM config file not found at #{config_file}"
      puts 'Creating example config file...'
      create_example_config(config_file)
      {}
    end
  end

  def setup_client
    # Use environment variables first (recommended), then fall back to config
    api_key = ENV['OPENAI_API_KEY'] || @config['openai_api_key']
    organization = ENV['OPENAI_ORG_ID'] || @config['openai_org_id']
    ENV['OPENAI_PROJECT_ID'] || @config['openai_project_id']
    base_url = ENV['OPENAI_BASE_URL'] || @config['openai_base_url']

    unless api_key
      puts '⚠️  No OpenAI API key found in environment or config. Using mock responses...'
      puts "Set OPENAI_API_KEY environment variable or add 'openai_api_key' to config file"
      return nil
    end

    # Initialize client with correct parameters for ruby-openai gem
    client_options = {
      access_token: api_key, # ruby-openai uses access_token, not api_key
      log_errors: true # Helpful for development
    }

    # Add optional parameters if present - using ruby-openai parameter names
    client_options[:organization_id] = organization if organization
    # NOTE: ruby-openai gem doesn't support project parameter
    client_options[:uri_base] = base_url if base_url
    client_options[:request_timeout] = @config['timeout'] || 240

    OpenAI::Client.new(**client_options)
  end

  def call_llm(prompt, options = {}, task_type = 'generation')
    raise ConfigurationError, 'No OpenAI client configured' if @client.nil?

    model = get_model_for_task(task_type)
    messages = []
    messages << { role: 'system', content: options[:system_prompt] } if options[:system_prompt]
    messages << { role: 'user', content: prompt }

    parameters = {
      model: model,
      messages: messages,
      temperature: options[:temperature] || 0.7
    }

    # Use appropriate token limit parameter based on model with safety check
    token_limit = get_safe_max_tokens(task_type, model)
    if O3_MODELS.include?(model)
      parameters[:max_completion_tokens] = token_limit
    else
      parameters[:max_tokens] = token_limit
    end

    begin
      response = @client.chat(parameters: parameters)
      content = response.dig('choices', 0, 'message', 'content')
      { 'content' => content }
    rescue Faraday::Error => e
      puts "❌ API Error: #{e.message}"
      raise APIError, "the server responded with status #{e.response[:status] if e.response}"
    rescue StandardError => e
      puts "❌ Unexpected Error: #{e.message}"
      raise LLMError, e.message
    end
  end

  def call_llm_structured(prompt, options = {}, task_type = 'generation')
    raise ConfigurationError, 'No OpenAI client configured' if @client.nil?

    model = get_model_for_task(task_type)
    messages = []
    messages << { role: 'system', content: options[:system_prompt] } if options[:system_prompt]
    messages << { role: 'user', content: prompt }

    parameters = {
      model: model,
      messages: messages,
      temperature: options[:temperature] || 0.7,
      response_format: options[:response_format]
    }

    # Use appropriate token limit parameter based on model with safety check
    token_limit = get_safe_max_tokens(task_type, model)
    if O3_MODELS.include?(model)
      parameters[:max_completion_tokens] = token_limit
    else
      parameters[:max_tokens] = token_limit
    end

    begin
      response = @client.chat(parameters: parameters)
      content = response.dig('choices', 0, 'message', 'content')
      { 'content' => content }
    rescue Faraday::Error => e
      puts "❌ API Error: #{e.message}"
      raise APIError, "the server responded with status #{e.response[:status] if e.response}"
    rescue StandardError => e
      puts "❌ Unexpected Error: #{e.message}"
      raise LLMError, e.message
    end
  end

  def parse_character_response(response)
    # Handle mock responses (which are already hashes)
    return response if response.is_a?(Hash)

    # Try to extract structured character data from string response
    # This is a simple parser - could be enhanced based on actual LLM output format

    lines = response.split("\n").reject(&:empty?)
    character = {}

    current_section = nil
    content_buffer = []

    lines.each do |line|
      if line.match(/^(Name|Description|Personality|Traits|Catchphrase|Backstory|Quirks):/i)
        # Save previous section
        character[current_section] = content_buffer.join(' ').strip if current_section && content_buffer.any?

        # Start new section
        parts = line.split(':', 2)
        current_section = parts[0].downcase.gsub(/\s+/, '_')
        content_buffer = [parts[1].to_s.strip]
      elsif current_section
        content_buffer << line.strip
      end
    end

    # Save last section
    character[current_section] = content_buffer.join(' ').strip if current_section && content_buffer.any?

    # Convert traits to array if it's a string
    if character['personality_traits'].is_a?(String)
      character['personality_traits'] = character['personality_traits'].split(',').map(&:strip)
    end

    character
  end

  def build_improvement_prompt(content, improvement_type)
    template_files = {
      'humor' => 'scripts/prompts/humor_improvement_prompt.txt',
      'clarity' => 'scripts/prompts/clarity_improvement_prompt.txt',
      'consistency' => 'scripts/prompts/consistency_improvement_prompt.txt'
    }

    template_file = template_files[improvement_type] || 'scripts/prompts/general_improvement_prompt.txt'

    placeholders = {
      'CONTENT' => content
    }

    PromptUtils.build_prompt_from_file(template_file, placeholders)
  rescue PromptUtils::UnfilledPlaceholdersError => e
    puts "❌ Error: Improvement template has unfilled placeholders: #{e.unfilled_placeholders.join(', ')}"
    puts 'Please check the improvement prompt template and ensure all placeholders are handled.'
    # Fallback to simple prompt
    "Please improve the following content:\n\n#{content}"
  end

  def create_example_config(config_file)
    # Create clean config hash with task-specific models
    clean_config = {
      'model' => 'gpt-4o-mini',
      'models' => {
        'generation' => 'gpt-4o',
        'translation' => 'gpt-4o-mini',
        'chat' => 'gpt-4o-mini'
      },
      'timeout' => 240,
      'max_retries' => 2,
      'default_options' => {
        'temperature' => 0.7,
        'max_tokens' => 6000  # Generous default
      },
      'task_options' => {
        'generation' => {
          'temperature' => 0.8,
          'max_tokens' => 8000    # Large for chapters
        },
        'translation' => {
          'temperature' => 0.3,
          'max_tokens' => 12000   # Extra large for any language
        },
        'chat' => {
          'temperature' => 0.7,
          'max_tokens' => 4000    # Reasonable for chat
        }
      }
    }

    File.open(config_file, 'w') do |file|
      file.puts '# OpenAI Configuration for One Review Man'
      file.puts '# =========================================='
      file.puts '#'
      file.puts '# SECURITY BEST PRACTICE:'
      file.puts '# Set API keys via environment variables instead of this file:'
      file.puts '#'
      file.puts '#   export OPENAI_API_KEY="your-api-key-here"'
      file.puts '#   export OPENAI_ORG_ID="your-org-id"        # optional'
      file.puts '#   export OPENAI_PROJECT_ID="your-project"   # optional'
      file.puts '#   export OPENAI_BASE_URL="custom-url"       # optional'
      file.puts '#'
      file.puts '# This keeps secrets out of your repository!'
      file.puts ''
      file.puts '# Alternatively, you can set these in this file (less secure):'
      file.puts '# openai_api_key: your-api-key-here'
      file.puts '# openai_org_id: your-org-id'
      file.puts '# openai_project_id: your-project'
      file.puts '# openai_base_url: custom-url'
      file.puts ''
      file.puts '# Default model (used when no task-specific model is specified)'
      file.puts clean_config.to_yaml.lines[1..].join # Skip first "---" line
    end

    puts "📝 Created example config at #{config_file}"
    puts ''
    puts '🔒 SECURITY RECOMMENDATION:'
    puts 'Set your API key via environment variable instead of config file:'
    puts '  export OPENAI_API_KEY="your-api-key-here"'
    puts ''
    puts 'Get your API key from: https://platform.openai.com/api-keys'
    puts ''
    puts 'Available models:'
    puts '  - gpt-4o-mini (recommended, fast and cost-effective)'
    puts '  - gpt-4o (most capable)'
    puts '  - gpt-4-turbo (good balance)'
    puts '  - gpt-3.5-turbo (fastest, cheapest)'
    puts ''
    puts 'Task-specific models and limits configured:'
    puts '  - Generation (chapters/characters): gpt-4o with 8K tokens (higher quality)'
    puts '  - Translation: gpt-4o-mini with 12K tokens (generous for any language)'
    puts '  - Chat: gpt-4o-mini with 4K tokens (quick responses)'
    puts ''
    puts 'Environment variables supported:'
    puts '  - OPENAI_API_KEY (required)'
    puts '  - OPENAI_ORG_ID (optional)'
    puts '  - OPENAI_PROJECT_ID (optional)'
    puts '  - OPENAI_BASE_URL (optional)'
  end

  def character_schema
    {
      type: 'object',
      properties: {
        name: {
          type: 'string',
          description: 'Character name'
        },
        description: {
          type: 'string',
          description: 'Brief character description'
        },
        personality_traits: {
          type: 'array',
          items: { type: 'string' },
          description: 'List of personality traits'
        },
        programming_skills: {
          type: 'string',
          description: 'Programming abilities and technical skills'
        },
        catchphrase: {
          type: 'string',
          description: 'Character catchphrase or motto'
        },
        backstory: {
          type: 'string',
          description: 'Character background story'
        },
        quirks: {
          type: 'string',
          description: 'Notable quirks or unique characteristics'
        }
      },
      required: %w[name description personality_traits programming_skills],
      additionalProperties: false
    }
  end

  def validate_character_data(data)
    required_fields = %w[name description personality_traits programming_skills]

    missing_fields = required_fields.select { |field| data[field].nil? || data[field].to_s.strip.empty? }

    raise APIError, "Missing required character fields: #{missing_fields.join(', ')}" if missing_fields.any?

    # Ensure personality_traits is an array
    unless data['personality_traits'].is_a?(Array)
      raise APIError, "personality_traits must be an array, got: #{data['personality_traits'].class}"
    end

    # Ensure name is not empty
    raise APIError, 'Character name cannot be empty' if data['name'].to_s.strip.empty?

    puts '✅ Character data validation passed'
    true
  end

  def build_character_prompt_with_schema(prompt)
    schema_description = <<~SCHEMA

      IMPORTANT: Respond with valid JSON that matches this exact schema:

      {
        "name": "Professional/workplace name (string)",
        "real_name": "Actual given name (string, optional - include if different from professional name)",
        "description": "Brief character description (string)",
        "personality_traits": ["trait1", "trait2", "trait3"],
        "programming_skills": "Programming abilities and technical skills (string)",
        "catchphrase": "Character catchphrase or motto (string, optional)",
        "backstory": "Character background story (string, optional)",
        "quirks": "Notable quirks or unique characteristics (string, optional)"
      }

      Required fields: name, description, personality_traits, programming_skills
      Optional fields: real_name, catchphrase, backstory, quirks

      NAMING CONVENTIONS:
      - For One Review Man: name="One Review Man", real_name="Satoru"
      - For AI-Enhanced Disciple: name="AI-Enhanced Disciple", real_name="Genki"#{'  '}
      - For other characters: include real_name only if they have both professional and personal names

      Make sure personality_traits is always an array of strings.
    SCHEMA

    "#{prompt}#{schema_description}"
  end

  def build_chapter_prompt_with_schema(prompt)
    schema_description = <<~SCHEMA

      IMPORTANT: Respond with valid JSON that matches this exact schema:

      {
        "title": "Chapter title (string)",
        "content": "Chapter content in markdown format (string)",
        "summary": "Brief chapter summary (string)",
        "new_characters": [
          {
            "name": "Character name",
            "description": "Brief character description"
          }
        ],
        "programming_themes": ["code_review", "debugging", "deployment", "meetings"],
        "comedy_elements": ["absurd_situation", "tech_parody", "workplace_humor"],
        "word_count": 1500,
        "difficulty_level": "beginner",
        "one_punch_man_references": ["reference1", "reference2"]
      }

      Required fields: title, content, summary
      Optional but recommended: new_characters, programming_themes, comedy_elements, word_count, difficulty_level, one_punch_man_references

      Programming themes can include: code_review, debugging, deployment, git_conflicts, meetings, technical_debt, framework_wars, stack_overflow, pair_programming, devops
      Comedy elements can include: absurd_situation, tech_parody, workplace_humor, overpowered_protagonist, bureaucracy_satire
      Difficulty levels: beginner, intermediate, advanced

      Make sure content is engaging programming comedy that parodies One-Punch Man tropes.
    SCHEMA

    "#{prompt}#{schema_description}"
  end

  def validate_chapter_data(data)
    required_fields = %w[title content summary]

    missing_fields = required_fields.select { |field| data[field].nil? || data[field].to_s.strip.empty? }

    raise APIError, "Missing required chapter fields: #{missing_fields.join(', ')}" if missing_fields.any?

    # Ensure title is not empty
    raise APIError, 'Chapter title cannot be empty' if data['title'].to_s.strip.empty?

    # Validate optional arrays
    %w[new_characters programming_themes comedy_elements one_punch_man_references].each do |field|
      if data[field] && !data[field].is_a?(Array)
        puts "⚠️  Warning: #{field} should be an array, got #{data[field].class}"
      end
    end

    # Validate word count if present
    puts '⚠️  Warning: word_count should be an integer' if data['word_count'] && !data['word_count'].is_a?(Integer)

    puts '✅ Chapter data validation passed'
    true
  end

  def parse_chapter_content(content)
    # Handle mock responses (which are already hashes)
    return content if content.is_a?(Hash)

    # Try to extract structured chapter data from string response
    # This is a simple parser - could be enhanced based on actual LLM output format

    lines = content.split("\n").reject(&:empty?)
    chapter = {}

    current_section = nil
    content_buffer = []

    lines.each do |line|
      if line.match(/^(Title|Content|Summary|Metadata):/i)
        # Save previous section
        chapter[current_section] = content_buffer.join(' ').strip if current_section && content_buffer.any?

        # Start new section
        parts = line.split(':', 2)
        current_section = parts[0].downcase.gsub(/\s+/, '_')
        content_buffer = [parts[1].to_s.strip]
      elsif current_section
        content_buffer << line.strip
      end
    end

    # Save last section
    chapter[current_section] = content_buffer.join(' ').strip if current_section && content_buffer.any?

    # Convert metadata to hash if it's a string
    chapter['metadata'] = JSON.parse(chapter['metadata']) if chapter['metadata'].is_a?(String)

    chapter
  end

  def build_chapter_translation_prompt(title, summary, content, target_lang)
    language_names = {
      'ru' => 'Russian',
      'es' => 'Spanish',
      'fr' => 'French',
      'de' => 'German',
      'zh' => 'Chinese'
    }

    target_language_name = language_names[target_lang] || target_lang.upcase

    # Special handling for Russian transliterations
    special_instructions = ''
    if target_lang == 'ru'
      special_instructions = <<~RUSSIAN_INSTRUCTIONS

        RUSSIAN TRANSLITERATION RULES:
        - "One Review Man" → "Ванревьюмен" (follows the same pattern as "One Punch Man" → "Ванпанчмен")
        - "AI-Enhanced Disciple" → "ИИ-Усиленный Ученик"
        - Keep real names in Japanese style: "Satoru" → "Сатору", "Genki" → "Генки"
        - Use respectful address: "Сатору-сенсей" for "Satoru-sensei"
        - Programming terms: mix English and Russian naturally (e.g., "программист", "код", but "pull request", "git")
      RUSSIAN_INSTRUCTIONS
    end

    prompt = <<~PROMPT
      Translate the following programming comedy chapter from English to #{target_language_name}.

      PRESERVE:
      - Programming humor and technical jokes
      - One-Punch Man parody references#{'  '}
      - Character personalities and catchphrases
      - Markdown formatting
      - Technical terms (translate context, keep some English technical terms where appropriate)
      - Naming conventions and character address patterns
      #{special_instructions}

      SOURCE CHAPTER:
      Title: #{title}
      Summary: #{summary}

      Content:
      #{content}

      TRANSLATION INSTRUCTIONS:
      - Translate all narrative text to #{target_language_name}
      - Keep programming terms in English where commonly used (e.g., "pull request", "merge", "deployment")
      - Adapt jokes to work in #{target_language_name} while keeping the programming humor
      - Maintain the One-Punch Man parody style
      - Follow character naming and address conventions for #{target_language_name}
    PROMPT

    schema_description = <<~SCHEMA

      IMPORTANT: Respond with valid JSON that matches this exact schema:

      {
        "title": "Translated chapter title (string)",
        "summary": "Translated chapter summary (string)",
        "content": "Translated chapter content in markdown format (string)"
      }

      Required fields: title, summary, content
      All fields should contain the translated text in #{target_language_name}.
    SCHEMA

    "#{prompt}#{schema_description}"
  end

  def validate_chapter_translation_data(data)
    required_fields = %w[title summary content]

    missing_fields = required_fields.select { |field| data[field].nil? || data[field].to_s.strip.empty? }

    raise APIError, "Missing required chapter translation fields: #{missing_fields.join(', ')}" if missing_fields.any?

    # Ensure title is not empty
    raise APIError, 'Chapter title cannot be empty' if data['title'].to_s.strip.empty?

    puts '✅ Chapter translation data validation passed'
    true
  end

  def fallback_chapter_translation(_title, _summary, _content, _target_lang)
    # Implement fallback translation logic here
    # This is a placeholder and should be replaced with actual implementation
    puts '❌ Fallback translation not implemented'
    {}
  end

  def build_character_translation_prompt(name, description, personality_traits, programming_skills, catchphrase,
                                         backstory, quirks, target_lang)
    language_names = {
      'ru' => 'Russian',
      'es' => 'Spanish',
      'fr' => 'French',
      'de' => 'German',
      'zh' => 'Chinese'
    }

    target_language_name = language_names[target_lang] || target_lang.upcase

    # Special handling for Russian transliterations
    special_instructions = ''
    if target_lang == 'ru'
      special_instructions = <<~RUSSIAN_INSTRUCTIONS

        RUSSIAN TRANSLITERATION RULES:
        - "One Review Man" → "Ванревьюмен" (follows the same pattern as "One Punch Man" → "Ванпанчмен")
        - "AI-Enhanced Disciple" → "ИИ-Усиленный Ученик"
        - Keep real names in Japanese style: "Satoru" → "Сатору", "Genki" → "Генки"
        - Use respectful address: "Сатору-сенсей" for "Satoru-sensei"
        - For other characters: translate descriptive titles, transliterate personal names
        - Programming terms: mix English and Russian naturally (e.g., "программист", "код", but "pull request", "git")
      RUSSIAN_INSTRUCTIONS
    end

    prompt = <<~PROMPT
      Translate the following programming comedy character from English to #{target_language_name}.

      PRESERVE:
      - Programming humor and personality
      - Technical skills and abilities
      - Character quirks and comedy elements
      - Programming-related catchphrases
      - Character naming conventions and address patterns
      #{special_instructions}

      SOURCE CHARACTER:
      Name: #{name}
      Description: #{description}
      Personality Traits: #{personality_traits.join(', ')}
      Programming Skills: #{programming_skills}
      Catchphrase: #{catchphrase}
      Backstory: #{backstory}
      Quirks: #{quirks}

      TRANSLATION INSTRUCTIONS:
      - Translate all descriptive text to #{target_language_name}
      - Keep programming terms in English where commonly used
      - Adapt humor to work in #{target_language_name} while keeping the programming context
      - Maintain character personality and comedy style
      - Follow character naming conventions for #{target_language_name}
      - Preserve the relationship dynamic with other characters (especially One Review Man/Ванревьюмен)
    PROMPT

    schema_description = <<~SCHEMA

      IMPORTANT: Respond with valid JSON that matches this exact schema:

      {
        "name": "Translated character name (string)",
        "description": "Translated character description (string)",
        "personality_traits": ["translated_trait1", "translated_trait2", "translated_trait3"],
        "programming_skills": "Translated programming abilities and technical skills (string)",
        "catchphrase": "Translated character catchphrase or motto (string, optional)",
        "backstory": "Translated character background story (string, optional)",
        "quirks": "Translated notable quirks or unique characteristics (string, optional)"
      }

      Required fields: name, description, personality_traits, programming_skills
      Optional fields: catchphrase, backstory, quirks
      All fields should contain translated text in #{target_language_name}.
      Make sure personality_traits is always an array of strings.
    SCHEMA

    "#{prompt}#{schema_description}"
  end

  def validate_character_translation_data(data)
    required_fields = %w[name description personality_traits programming_skills]

    missing_fields = required_fields.select { |field| data[field].nil? || data[field].to_s.strip.empty? }

    raise APIError, "Missing required character translation fields: #{missing_fields.join(', ')}" if missing_fields.any?

    # Ensure personality_traits is an array
    unless data['personality_traits'].is_a?(Array)
      raise APIError, "personality_traits must be an array, got: #{data['personality_traits'].class}"
    end

    # Ensure name is not empty
    raise APIError, 'Character name cannot be empty' if data['name'].to_s.strip.empty?

    puts '✅ Character translation data validation passed'
    true
  end

  def fallback_character_translation(_name, _description, _personality_traits, _programming_skills, _catchphrase, _backstory,
                                     _quirks, _target_lang)
    # Implement fallback translation logic here
    # This is a placeholder and should be replaced with actual implementation
    puts '❌ Fallback translation not implemented'
    {}
  end

  # Get task-specific configuration options
  def get_task_options(task_type, base_options = {})
    # Start with default options
    merged_options = (@config['default_options'] || {}).dup

    # Override with task-specific options if they exist
    if @config['task_options'] && @config['task_options'][task_type]
      merged_options.merge!(@config['task_options'][task_type])
    end

    # Apply generous defaults if max_tokens not specified
    unless merged_options['max_tokens'] || base_options[:max_tokens]
      default_limits = {
        'generation' => 8000,    # Generous for chapter content
        'translation' => 12000,  # Extra generous for translations
        'chat' => 4000          # Reasonable for conversations
      }
      
      merged_options['max_tokens'] = default_limits[task_type] || 6000
    end

    # Finally merge with any provided base options (method-level defaults)
    merged_options.merge!(base_options)

    # Convert string keys to symbol keys for consistency
    merged_options.transform_keys(&:to_sym)
  end

  # Get model for specific task type
  def get_model_for_task(task_type)
    # Override takes precedence over everything
    return @model_override if @model_override

    # Try task-specific model first
    if @config['models'] && @config['models'][task_type]
      @config['models'][task_type]
    else
      # Fall back to default model
      @config['model'] || DEFAULT_MODEL
    end
  end

  # Get safe max_tokens that doesn't exceed model capacity
  def get_safe_max_tokens(task_type, model)
    configured_limit = get_task_options(task_type)[:max_tokens]
    
    # Model capacity limits (conservative estimates)
    model_caps = {
      'gpt-4o' => 100_000,
      'gpt-4o-mini' => 100_000,
      'o3-mini' => 50_000,
      'o3' => 150_000
    }
    
    model_cap = model_caps[model] || 50_000
    
    # Use configured limit, but cap at model capacity minus prompt overhead
    [configured_limit, model_cap - 5000].min
  end
end


