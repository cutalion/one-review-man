"# frozen_string_literal: true"

require 'yaml'
require 'json'
require 'fileutils'
begin
  require 'openai'
rescue LoadError
  # defer error until real usage
end

module BookCore
  class LLMService
    class LLMError < StandardError; end
    class ConfigurationError < LLMError; end
    class APIError < LLMError; end

    DEFAULT_MODEL = 'gpt-4o-mini'
    O3_MODELS = %w[o3-mini o3].freeze

    def initialize(config_path, model_override = nil)
      @config_path = config_path
      @model_override = model_override
      @config = load_config(config_path)
      @client = setup_client
      @debug = ENV['DEBUG_AI'] == '1' || ENV['DEBUG_AI'] == 'true'
      @debug_dir = nil
    end

    # Simple text generation used by ChapterGenerator
    def generate_text(prompt:, context: {})
      # Deterministic mock mode for tests/validation
      if ENV['MOCK_AI'] == '1' || ENV['MOCK_AI'] == 'true'
        chapter_num = prompt.to_s.match(/chapter\s*(\d+)/i)&.captures&.first || context[:chapter_number] || '1'
        return "Mock chapter content for Chapter #{chapter_num}"
      end

      response = call_llm(prompt, get_task_options('generation', { temperature: 0.7 }), 'generation')
      raise APIError, 'Failed to generate content' unless response && response['content']
      response['content']
    end

    # Structured chapter translation (returns hash with title/summary/content)
    def translate_chapter_structured(title, summary, content, target_lang, glossary = nil)
      if ENV['MOCK_AI'] == '1' || ENV['MOCK_AI'] == 'true'
        return {
          'title' => "#{title} (#{target_lang})",
          'summary' => "#{summary} (#{target_lang})",
          'content' => content
        }
      end

      prompt = build_chapter_translation_prompt(title, summary, content, target_lang, glossary)
      options = get_task_options('translation', {
        temperature: 0.3,
        system_prompt: 'You are a professional translator specializing in programming humor and technical content. Translate accurately while preserving comedy and technical references. Respond with valid JSON only.',
        response_format: { type: 'json_object' }
      })
      response = call_llm_structured(prompt, options, 'translation')
      raise APIError, 'Failed to translate chapter' unless response && response['content']

      JSON.parse(response['content'])
    rescue JSON::ParserError => e
      raise APIError, "Invalid JSON from LLM: #{e.message}"
    end

    # Structured character translation (returns hash with translated fields)
    def translate_character_structured(name, description, personality_traits, programming_skills, catchphrase, backstory, quirks, target_lang)
      if ENV['MOCK_AI'] == '1' || ENV['MOCK_AI'] == 'true'
        return {
          'name' => "#{name} (#{target_lang})",
          'description' => description,
          'personality_traits' => personality_traits || [],
          'programming_skills' => programming_skills,
          'catchphrase' => catchphrase,
          'backstory' => backstory,
          'quirks' => quirks
        }
      end

      prompt = build_character_translation_prompt(name, description, personality_traits, programming_skills, catchphrase, backstory, quirks, target_lang)
      options = get_task_options('translation', {
        temperature: 0.3,
        system_prompt: 'You are a professional translator for character profiles in a programming parody universe. Respond with valid JSON only.',
        response_format: { type: 'json_object' }
      })
      response = call_llm_structured(prompt, options, 'translation')
      raise APIError, 'Failed to translate character' unless response && response['content']

      JSON.parse(response['content'])
    rescue JSON::ParserError => e
      raise APIError, "Invalid JSON from LLM (character translation): #{e.message}"
    end

    # Structured chapter generation (returns Hash with keys like title, summary, content, new_characters)
    def generate_chapter_structured(prompt, options = {})
      if ENV['MOCK_AI'] == '1' || ENV['MOCK_AI'] == 'true'
        chapter_num = prompt.to_s.match(/chapter\s*(\d+)/i)&.captures&.first || '1'
        return {
          'title' => "Chapter #{chapter_num}",
          'summary' => "Summary for chapter #{chapter_num}",
          'content' => "Mock chapter content for Chapter #{chapter_num}",
          'new_characters' => []
        }
      end

      enhanced_prompt = build_chapter_prompt_with_schema(prompt)
      options = get_task_options('generation', {
        temperature: 0.7,
        system_prompt: 'You are a creative writer specializing in programming humor and parody. Write engaging, funny content that captures the absurdist spirit of programming culture. Respond with valid JSON only.',
        response_format: { type: 'json_object' }
      }).merge(options)

      response = call_llm_structured(enhanced_prompt, options, 'generation')
      raise APIError, 'Failed to generate chapter' unless response && response['content']

      raw = response['content'].to_s
      debug_dump('chapter_generation_raw.json', raw)
      data = try_parse_json(raw)
      unless data
        # Retry once with stricter instruction
        strict_prompt = enhanced_prompt + "\n\nReturn ONLY a valid minified JSON object matching the schema above. Do not include any explanations or code fences."
        response2 = call_llm_structured(strict_prompt, options, 'generation')
        raw2 = response2['content'].to_s
        debug_dump('chapter_generation_raw_retry.json', raw2)
        data = try_parse_json(raw2)
      end
      raise APIError, 'Invalid JSON from LLM' unless data
      # Minimal validation
      raise APIError, 'Missing chapter content' if data['content'].to_s.strip.empty?
      data['title'] ||= 'Untitled Chapter'
      data['summary'] ||= ''
      data['new_characters'] ||= []
      data
    rescue JSON::ParserError => e
      raise APIError, "Invalid JSON from LLM: #{e.message}"
    end

    # Structured character generation used when a new character is introduced
    # Returns a Hash with keys: description, personality_traits (Array), programming_skills,
    # catchphrase, backstory, quirks
    def generate_character(character_prompt)
      if ENV['MOCK_AI'] == '1' || ENV['MOCK_AI'] == 'true'
        return {
          'description' => 'New character generated (mock) for testing.',
          'personality_traits' => ['mocked'],
          'programming_skills' => 'General programming',
          'catchphrase' => 'Mock phrase.',
          'backstory' => 'Born in the land of tests.',
          'quirks' => 'Always returns mocked values.'
        }
      end

      schema = <<~SCHEMA
        IMPORTANT: Respond with valid JSON that matches this exact schema:
        {
          "description": "Character description (string)",
          "personality_traits": ["trait (string)"] ,
          "programming_skills": "Programming skills (string)",
          "catchphrase": "Catchphrase (string)",
          "backstory": "Backstory (string)",
          "quirks": "Quirks (string)"
        }
      SCHEMA

      options = get_task_options('generation', {
        temperature: 0.7,
        system_prompt: 'You generate full, coherent character profiles for a programming parody universe. Respond with valid JSON only.',
        response_format: { type: 'json_object' }
      })

      response = call_llm_structured("#{character_prompt}\n\n#{schema}", options, 'generation')
      data = JSON.parse(response['content'])
      data
    rescue JSON::ParserError => e
      raise APIError, "Invalid JSON from LLM (character): #{e.message}"
    end

    private

    def load_config(config_file)
      File.exist?(config_file) ? (YAML.load_file(config_file) || {}) : {}
    end

    def setup_client
      return nil if ENV['MOCK_AI'] == '1' || ENV['MOCK_AI'] == 'true'

      api_key = ENV['OPENAI_API_KEY'] || @config['openai_api_key']
      organization = ENV['OPENAI_ORG_ID'] || @config['openai_org_id']
      base_url = ENV['OPENAI_BASE_URL'] || @config['openai_base_url']
      return nil unless defined?(OpenAI)
      unless api_key
        # No API key — caller can still run in mock mode
        return nil
      end

      client_options = {
        access_token: api_key,
        log_errors: true
      }
      client_options[:organization_id] = organization if organization
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
        messages: messages
      }
      # Only include temperature if model supports it
      parameters[:temperature] = (options[:temperature] || 0.7) if supports_temperature?(model)

      token_limit = get_safe_max_tokens(task_type, model)
      token_param = token_param_for_model(model)
      parameters[token_param] = token_limit

      debug_dump('request_parameters.json', JSON.pretty_generate(parameters))
      response = @client.chat(parameters: parameters)
      content = response.dig('choices', 0, 'message', 'content')
      debug_dump('response_raw.json', content)
      { 'content' => content }
    rescue Faraday::Error => e
      # Retry once swapping unsupported params
      if e.response && e.response[:body].to_s.include?("Unsupported value: 'temperature'")
        parameters.delete(:temperature)
        response = @client.chat(parameters: parameters)
        content = response.dig('choices', 0, 'message', 'content')
        return { 'content' => content }
      end
      # Retry once swapping token param if unsupported
      if e.response && e.response[:body].to_s.include?("Unsupported parameter: 'max_tokens'")
        parameters.delete(:max_tokens)
        parameters[:max_completion_tokens] = token_limit
        response = @client.chat(parameters: parameters)
        content = response.dig('choices', 0, 'message', 'content')
        return { 'content' => content }
      end
      raise APIError, "the server responded with status #{e.response[:status] if e.response}"
    rescue StandardError => e
      raise LLMError, e.message
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
        response_format: options[:response_format]
      }
      parameters[:temperature] = (options[:temperature] || 0.7) if supports_temperature?(model)

      token_limit = get_safe_max_tokens(task_type, model)
      token_param = token_param_for_model(model)
      parameters[token_param] = token_limit

      debug_dump('request_parameters.json', JSON.pretty_generate(parameters))
      response = @client.chat(parameters: parameters)
      content = response.dig('choices', 0, 'message', 'content')
      debug_dump('response_raw.json', content)
      { 'content' => content }
    rescue Faraday::Error => e
      if e.response && e.response[:body].to_s.include?("Unsupported value: 'temperature'")
        parameters.delete(:temperature)
        response = @client.chat(parameters: parameters)
        content = response.dig('choices', 0, 'message', 'content')
        return { 'content' => content }
      end
      if e.response && e.response[:body].to_s.include?("Unsupported parameter: 'max_tokens'")
        parameters.delete(:max_tokens)
        parameters[:max_completion_tokens] = token_limit
        response = @client.chat(parameters: parameters)
        content = response.dig('choices', 0, 'message', 'content')
        return { 'content' => content }
      end
      raise APIError, "the server responded with status #{e.response[:status] if e.response}"
    rescue StandardError => e
      raise LLMError, e.message
    end

    def get_task_options(task_type, base_options = {})
      merged = (@config['default_options'] || {}).dup
      if @config['task_options'] && @config['task_options'][task_type]
        merged.merge!(@config['task_options'][task_type])
      end
      merged['max_tokens'] ||= ({ 'generation' => 8000, 'translation' => 12000, 'chat' => 4000 }[task_type] || 6000)
      merged.merge(base_options).transform_keys(&:to_sym)
    end

    def get_model_for_task(task_type)
      return @model_override if @model_override
      if @config['models'] && @config['models'][task_type]
        @config['models'][task_type]
      else
        @config['model'] || DEFAULT_MODEL
      end
    end

    def get_safe_max_tokens(task_type, model)
      configured_limit = get_task_options(task_type)[:max_tokens]
      model_caps = {
        'gpt-4o' => 100_000,
        'gpt-4o-mini' => 100_000,
        'o3-mini' => 50_000,
        'o3' => 150_000,
        'gpt-5' => 150_000
      }
      model_cap = model_caps[model] || 50_000
      [configured_limit, model_cap - 5000].min
    end

    def token_param_for_model(model)
      return :max_completion_tokens if O3_MODELS.include?(model)
      return :max_completion_tokens if model.to_s.start_with?('gpt-5')
      :max_tokens
    end

    def supports_temperature?(model)
      # Newer models like gpt-5 may not accept custom temperature
      return false if model.to_s.start_with?('gpt-5')
      true
    end

    def build_chapter_translation_prompt(title, summary, content, target_lang, glossary)
      language_names = { 'ru' => 'Russian', 'es' => 'Spanish', 'fr' => 'French', 'de' => 'German', 'zh' => 'Chinese' }
      target_language_name = language_names[target_lang] || target_lang.upcase

      special_instructions = ''
      if target_lang == 'ru'
        special_instructions = <<~RUSSIAN

          RUSSIAN TRANSLITERATION RULES:
          - "One Review Man" → "Ванревьюмен"
          - "AI-Enhanced Disciple" → "ИИ-Усиленный Ученик"
          - Keep real names in Japanese style: "Satoru" → "Сатору", "Genki" → "Генки"
          - Use respectful address: "Сатору-сенсей" for "Satoru-sensei"
          - Programming terms: mix English and Russian naturally (e.g., "программист", "код", but "pull request", "git")
        RUSSIAN
      end

      glossary_block = if glossary && !glossary.to_s.empty?
        "GLOSSARY OF PROPER NAMES (use exact translations shown below):\n\n#{glossary}"
      else
        ''
      end

      <<~PROMPT
        Translate the following programming comedy chapter from English to #{target_language_name}.

        PRESERVE:
        - Programming humor and technical jokes
        - One-Punch Man parody references
        - Character personalities and catchphrases
        - Markdown formatting
        - Technical terms (translate context, keep some English technical terms where appropriate)
        - Naming conventions and character address patterns
        #{special_instructions}

        #{glossary_block}

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

        IMPORTANT: Respond with valid JSON that matches this exact schema:
        {
          "title": "Translated chapter title (string)",
          "summary": "Translated chapter summary (string)",
          "content": "Translated chapter content in markdown format (string)"
        }
      PROMPT
    end

    def build_character_translation_prompt(name, description, personality_traits, programming_skills, catchphrase, backstory, quirks, target_lang)
      language_names = { 'ru' => 'Russian', 'es' => 'Spanish', 'fr' => 'French', 'de' => 'German', 'zh' => 'Chinese' }
      target_language_name = language_names[target_lang] || target_lang.upcase

      <<~PROMPT
        Translate the following character profile into #{target_language_name} while preserving tone and style. Respond with valid JSON only.

        SOURCE CHARACTER:
        Name: #{name}
        Description: #{description}
        Personality Traits: #{Array(personality_traits).join(', ')}
        Programming Skills: #{programming_skills}
        Catchphrase: #{catchphrase}
        Backstory: #{backstory}
        Quirks: #{quirks}

        IMPORTANT: Respond with valid JSON that matches this exact schema:
        {
          "name": "Translated character name (string)",
          "description": "Translated character description (string)",
          "personality_traits": ["trait"],
          "programming_skills": "Translated programming skills (string)",
          "catchphrase": "Translated catchphrase (string)",
          "backstory": "Translated backstory (string)",
          "quirks": "Translated quirks (string)"
        }
      PROMPT
    end

    def build_chapter_prompt_with_schema(prompt)
      schema = <<~SCHEMA

        IMPORTANT: Respond with valid JSON that matches this exact schema:

        {
          "title": "Chapter title (string)",
          "summary": "Brief chapter summary (string)",
          "content": "Chapter content in markdown format (string)",
          "new_characters": [
            { "name": "Character name", "description": "Brief description", "personality_traits": ["trait"] }
          ]
        }

        Required fields: content
        Optional: title, summary, new_characters
      SCHEMA

      "#{prompt}\n\n#{schema}"
    end

    def try_parse_json(text)
      return nil if text.to_s.strip.empty?
      begin
        return JSON.parse(text)
      rescue JSON::ParserError
        # Try to extract JSON from code fences
        if (m = text.match(/```(?:json)?\s*(\{[\s\S]*\})\s*```/))
          begin
            return JSON.parse(m[1])
          rescue JSON::ParserError
            # fall through
          end
        end
        nil
      end
    end

    def ensure_debug_dir
      return unless @debug
      return @debug_dir if @debug_dir
      project_root = File.expand_path(File.join(File.dirname(@config_path), '..'))
      dir = File.join(project_root, 'tmp', 'ai_debug')
      FileUtils.mkdir_p(dir)
      @debug_dir = dir
    rescue StandardError
      @debug_dir = nil
    end

    def debug_dump(filename, content)
      return unless @debug
      ensure_debug_dir
      return unless @debug_dir
      File.write(File.join(@debug_dir, filename), content.to_s)
    rescue StandardError
      # best effort only
    end
  end
end

# Backward compatibility alias
::LLMService = BookCore::LLMService unless defined?(::LLMService)
