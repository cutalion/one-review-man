# frozen_string_literal: true

require 'yaml'
require 'json'
require 'fileutils'
require 'book_core/env_utils'
begin
  require 'openai'
rescue LoadError
  # defer error until real usage
end

module BookCore
  # Service class for interacting with Large Language Model APIs
  class LLMService
    class LLMError < StandardError; end
    class ConfigurationError < LLMError; end
    class APIError < LLMError; end

    class LLMError < StandardError; end
    class ConfigurationError < LLMError; end
    class APIError < LLMError; end

    def initialize(config)
      @config = config['llm'] || {}
      @settings = config # Keep full config for other sections like illustration
      @clients = {} # Cache for lazy-initialized clients per provider
      @debug = EnvUtils.debug_ai_enabled?
      @debug_dir = nil
    end

    # Simple text generation used by ChapterGenerator
    def generate_text(prompt:, context: {})
      # Deterministic mock mode for tests/validation
      if EnvUtils.mock_ai_enabled?
        chapter_num = prompt.to_s.match(/chapter\s*(\d+)/i)&.captures&.first || context[:chapter_number] || '1'
        return "Mock chapter content for Chapter #{chapter_num}"
      end

      response = call_llm(prompt, get_task_options('generation', { temperature: 0.7 }), 'generation')
      raise APIError, 'Failed to generate content' unless response && response['content']

      response['content']
    end

    # Summarize text using a lightweight model
    def summarize_text(text)
      if EnvUtils.mock_ai_enabled?
        return "Mock summary of: #{text[0..20]}..."
      end

      prompt = "Summarize the following text into a short description suitable for an image alt text (max 20 words):\n\n#{text}"
      
      # Use gpt-5-nano by default for summarization if not overridden
      # Model is now resolved from config via get_model_for_task('summarization')
      options = get_task_options('summarization', { 
        system_prompt: 'You are a helpful assistant that summarizes text for image descriptions.' 
      })

      response = call_llm(prompt, options, 'summarization')
      raise APIError, 'Failed to summarize text' unless response && response['content']

      response['content'].strip
    end

    # Structured chapter translation (returns hash with title/summary/content)
    def translate_chapter_structured(title, summary, content, target_lang, glossary = nil, book_metadata = nil)
      if EnvUtils.mock_ai_enabled?
        return {
          'title' => "#{title} (#{target_lang})",
          'summary' => "#{summary} (#{target_lang})",
          'content' => content
        }
      end

      prompt = build_chapter_translation_prompt(title, summary, content, target_lang, glossary, book_metadata)
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
      if EnvUtils.mock_ai_enabled?
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
      if EnvUtils.mock_ai_enabled?
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
        strict_prompt = "#{enhanced_prompt}\n\nReturn ONLY a valid minified JSON object matching the schema above. Do not include any explanations or code fences."
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
      if EnvUtils.mock_ai_enabled?
        return {
          'description' => 'New character generated (mock) for testing.',
          'personality_traits' => ['mocked'],
          'programming_skills' => 'General programming',
          'catchphrase' => 'Mock phrase.',
          'backstory' => 'Born in the land of tests.',
          'quirks' => 'Always returns mocked values.',
          'physical_appearance' => {
            'age' => '25',
            'skin_tone' => 'Pixelated',
            'hair' => 'Blue',
            'eyes' => 'Green',
            'outfit' => 'Hoodie',
            'distinguishing_features' => 'None'
          }
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
          "quirks": "Quirks (string)",
          "physical_appearance": {
            "age": "Age (string or number)",
            "skin_tone": "Skin tone (string)",
            "hair": "Hair color/style (string)",
            "eyes": "Eye color/shape (string)",
            "outfit": "Clothing style (string)",
            "distinguishing_features": "Notable features (string)"
          }
        }
      SCHEMA

      options = get_task_options('generation', {
                                   temperature: 0.7,
                                   system_prompt: 'You generate full, coherent character profiles for a programming parody universe. Respond with valid JSON only.',
                                   response_format: { type: 'json_object' }
                                 })

      response = call_llm_structured("#{character_prompt}\n\n#{schema}", options, 'generation')
      JSON.parse(response['content'])
    rescue JSON::ParserError => e
      raise APIError, "Invalid JSON from LLM (character): #{e.message}"
    end

    # Generate an image using DALL-E or OpenRouter
    # Returns base64 encoded image data
    # @param prompt [String] Image generation prompt
    # @param size [String] Image size (e.g., '1024x1024', '16:9')
    # @param quality [String] Image quality for DALL-E
    # @param style [String] Image style for DALL-E
    # @param model [String] Model name (e.g., 'dall-e-3', 'google/gemini-3-pro-image-preview')
    # @param provider [String] Provider name ('openai' or 'openrouter')
    def generate_image(prompt, size: nil, quality: 'standard', style: nil, model: nil, provider: nil)
      if EnvUtils.mock_ai_enabled?
        return 'https://placehold.co/1024x1024/png?text=Mock+Image'
      end

      opts = resolve_image_options(provider: provider, model: model, style: style, size: size)
      provider = opts[:provider]
      model = opts[:model]
      style = opts[:style]
      size = opts[:size]

      case provider.to_s.downcase
      when 'openrouter'
        generate_image_with_openrouter(prompt, model: model, size: size)
      when 'openai'
        generate_image_with_openai(prompt, size: size, quality: quality, style: style, model: model)
      else
        raise ConfigurationError, "Unknown image provider: #{provider}. Supported: openai, openrouter"
      end
    end

    # Get the provider for a specific task type
    # @param task_type [String] Task type ('generation', 'translation', 'summarization')
    # @return [String] Provider name
    def get_provider_for_task(task_type)
      case task_type
      when 'summarization'
        @settings.dig('summarization', 'provider') || @config['provider'] || 'openai'
      when 'translation'
        @settings.dig('translation', 'provider') || @settings.dig('content', 'provider') || @config['provider'] || 'openai'
      when 'generation'
        @settings.dig('content', 'provider') || @config['provider'] || 'openai'
      else
        @config['provider'] || 'openai'
      end
    end

    # Validate that a provider is supported
    # @param provider_name [String] Provider to validate
    # @raise [ConfigurationError] if provider is not supported
    def validate_provider!(provider_name)
      providers_config = @settings['providers'] || {}
      return if providers_config.key?(provider_name)

      supported = providers_config.keys.join(', ')
      raise ConfigurationError, "Unsupported provider '#{provider_name}'. Supported providers: #{supported}"
    end

    # Get or create a client for the specified provider
    # @param provider_name [String] Provider name ('openai' or 'openrouter')
    # @return [OpenAI::Client, nil] Client instance
    def get_client(provider_name)
      return nil if EnvUtils.mock_ai_enabled?
      
      validate_provider!(provider_name)
      
      @clients[provider_name] ||= setup_client_for_provider(provider_name)
    end

    def resolve_image_options(provider: nil, model: nil, style: nil, size: nil, orientation: nil)
      illustration_config = @settings['illustration'] || {}
      
      # Use explicit args, then illustration config, then hardcoded fallbacks
      provider ||= illustration_config['provider'] || 'openai'
      model ||= illustration_config['model'] || 'dall-e-3'
      style ||= illustration_config['style'] || 'vivid'
      
      # Resolve size from orientation if size is not explicit
      unless size
        orientation ||= illustration_config['orientation']
        size = resolve_default_size(orientation) || '1024x1024'
      end

      {
        provider: provider,
        model: model,
        style: style,
        size: size,
        orientation: orientation
      }
    end

    private

    # Generate image using OpenAI DALL-E
    def generate_image_with_openai(prompt, size:, quality:, style:, model:)
      client = get_client('openai')
      raise ConfigurationError, 'No OpenAI client configured' if client.nil?

      parameters = {
        model: model,
        prompt: prompt,
        size: size,
        quality: quality,
        style: style,
        response_format: 'b64_json' # We want the data, not a temporary URL
      }

      debug_dump('image_generation_params.json', JSON.pretty_generate(parameters))

      response = with_retries do
        client.images.generate(parameters: parameters)
      end

      debug_dump('image_generation_response.json', response.to_s)

      # Extract base64 data
      b64_data = response.dig('data', 0, 'b64_json')
      raise APIError, 'Failed to generate image: No data returned' unless b64_data

      b64_data
    rescue Faraday::Error => e
      raise APIError, "Image generation failed: #{e.response[:status] if e.response} - #{e.response[:body] if e.response}"
    rescue StandardError => e
      raise LLMError, "Image generation error: #{e.message}"
    end

    # Generate image using OpenRouter (chat completions with modalities)
    def generate_image_with_openrouter(prompt, model:, size:)
      client = get_client('openrouter')
      raise ConfigurationError, 'No OpenRouter client configured' unless client

      messages = [{ role: 'user', content: prompt }]
      
      parameters = {
        model: model,
        messages: messages,
        modalities: ['image', 'text']
      }

      # Add aspect ratio configuration if a ratio is provided (e.g., '16:9')
      if size.include?(':')
        parameters[:image_config] = { aspect_ratio: size }
      end

      debug_dump('openrouter_image_params.json', JSON.pretty_generate(parameters))

      response = with_retries do
        client.chat(parameters: parameters)
      end

      debug_dump('openrouter_image_response.json', response.to_s)

      # OpenRouter returns images in message.images array, not content
      # Format: { choices: [{ message: { images: [{ image_url: { url: "data:image/..." } }] } }] }
      message = response.dig('choices', 0, 'message')
      
      # Debug: log what we got
      puts "DEBUG: Response structure:" if @debug
      puts "  choices present: #{response['choices']&.any?}" if @debug
      puts "  message keys: #{message&.keys&.inspect}" if @debug
      puts "  images present: #{message&.dig('images')&.any?}" if @debug
      
      # Check for images in the correct location
      images = message&.dig('images')
      if images&.any?
        # Get the first image's data URL
        image_url = images.first&.dig('image_url', 'url')
        if image_url&.start_with?('data:image')
          # Extract base64 part from "data:image/png;base64,..."
          b64_data = image_url.split(',', 2)[1]
          return b64_data if b64_data
        end
      end

      # Fallback: check content for backwards compatibility
      content_parts = message&.dig('content')
      if content_parts.is_a?(Array)
        image_part = content_parts.find { |part| part['type'] == 'image_url' }
        if image_part && image_part['image_url']
          data_url = image_part['image_url']['url']
          if data_url&.start_with?('data:image')
            b64_data = data_url.split(',', 2)[1]
            return b64_data if b64_data
          end
        end
      end

      # Better error message showing what we got
      error_details = {
        'response_keys' => response.keys,
        'message_keys' => message&.keys,
        'images_count' => images&.length,
        'content_type' => content_parts.class.name,
        'full_message' => message&.inspect[0..500]
      }
      
      debug_dump('openrouter_parse_error.json', JSON.pretty_generate(error_details))
      
      raise APIError, "Failed to extract image from OpenRouter response. Message keys: #{message&.keys&.inspect}"
    rescue Faraday::Error => e
      raise APIError, "OpenRouter image generation failed: #{e.response[:status] if e.response} - #{e.response[:body] if e.response}"
    rescue StandardError => e
      raise LLMError, "OpenRouter image generation error: #{e.message}"
    end

    public

    def get_model_for_task(task_type)
      # Check for specific model override for this task type in the config
      # The config logic should have already merged CLI overrides into this structure
      if task_type == 'summarization' && @settings['summarization'] && @settings['summarization']['model']
        return @settings['summarization']['model']
      end

      if task_type == 'translation' && @settings['translation'] && @settings['translation']['model']
        return @settings['translation']['model']
      end

      if @config['models'] && @config['models'][task_type]
        @config['models'][task_type]
      elsif @settings['content'] && @settings['content']['model']
        @settings['content']['model']
      else
        @config['model']
      end
    end

    def with_retries
      retries = 0
      max_retries = @config.dig('retry', 'max_attempts') || 3
      backoff = @config.dig('retry', 'backoff_multiplier') || 2

      begin
        yield
      rescue Faraday::Error
        if retries < max_retries
          sleep_time = backoff**retries
          # Log retry (puts for now, could be logger)
          puts "⚠️  LLM Request failed. Retrying in #{sleep_time}s... (Attempt #{retries + 1}/#{max_retries})" if @debug
          sleep(sleep_time)
          retries += 1
          retry
        end
        raise
      end
    end

    def resolve_default_size(orientation)
      case orientation.to_s.downcase
      when 'portrait'
        '1024x1792'
      when 'landscape'
        '1792x1024'
      else
        '1024x1024' # square
      end
    end

    private

    # Setup a client for a specific provider
    # @param provider_name [String] Provider name
    # @return [OpenAI::Client, nil]
    def setup_client_for_provider(provider_name)
      return nil unless defined?(OpenAI)
      
      providers_config = @settings['providers'] || {}
      provider_config = providers_config[provider_name]
      raise ConfigurationError, "Provider configuration not found for '#{provider_name}'" unless provider_config

      case provider_name
      when 'openai'
        setup_openai_client(provider_config)
      when 'openrouter'
        setup_openrouter_client(provider_config)
      else
        raise ConfigurationError, "Unknown provider: #{provider_name}"
      end
    end

    # Setup OpenAI client
    def setup_openai_client(provider_config)
      api_key = ENV[provider_config['api_key_env']] || @config['openai_api_key']
      unless api_key
        # No API key — caller can still run in mock mode
        return nil
      end

      client_options = {
        access_token: api_key,
        log_errors: true,
        request_timeout: @config['timeout'] || 240
      }
      
      if provider_config['org_id_env']
        org_id = ENV[provider_config['org_id_env']] || @config['openai_org_id']
        client_options[:organization_id] = org_id if org_id
      end
      
      if provider_config['base_url_env']
        base_url = ENV[provider_config['base_url_env']] || @config['openai_base_url']
        client_options[:uri_base] = base_url if base_url
      end

      OpenAI::Client.new(**client_options)
    end

    # Setup OpenRouter client (uses OpenAI client with different base URL)
    def setup_openrouter_client(provider_config)
      api_key = ENV[provider_config['api_key_env']] || @config['openrouter_api_key']
      unless api_key
        return nil
      end

      client_options = {
        access_token: api_key,
        uri_base: provider_config['base_url'] || 'https://openrouter.ai/api/v1',
        log_errors: true,
        request_timeout: @config['timeout'] || 240
      }

      OpenAI::Client.new(**client_options)
    end

    def call_llm(prompt, options = {}, task_type = 'generation')
      provider = get_provider_for_task(task_type)
      client = get_client(provider)
      raise ConfigurationError, "No client configured for provider '#{provider}'" if client.nil?

      model = get_model_for_task(task_type)
      messages = []
      messages << { role: 'system', content: options[:system_prompt] } if options[:system_prompt]
      messages << { role: 'user', content: prompt }

      parameters = build_api_parameters(model, messages, options, task_type)

      debug_dump('request_parameters.json', JSON.pretty_generate(parameters))
      
      response = with_retries do
        client.chat(parameters: parameters)
      end
      
      content = response.dig('choices', 0, 'message', 'content')
      debug_dump('response_raw.json', content)
      { 'content' => content }
    rescue Faraday::Error => e
      raise APIError, "the server responded with status #{e.response[:status] if e.response}"
    rescue StandardError => e
      raise LLMError, e.message
    end

    def call_llm_structured(prompt, options = {}, task_type = 'generation')
      provider = get_provider_for_task(task_type)
      client = get_client(provider)
      raise ConfigurationError, "No client configured for provider '#{provider}'" if client.nil?

      model = get_model_for_task(task_type)
      messages = []
      messages << { role: 'system', content: options[:system_prompt] } if options[:system_prompt]
      messages << { role: 'user', content: prompt }

      parameters = build_api_parameters(model, messages, options, task_type)
      parameters[:response_format] = options[:response_format] if options[:response_format]

      debug_dump('request_parameters.json', JSON.pretty_generate(parameters))
      
      response = with_retries do
        client.chat(parameters: parameters)
      end
      
      content = response.dig('choices', 0, 'message', 'content')
      debug_dump('response_raw.json', content)
      { 'content' => content }
    rescue Faraday::Error => e
      raise APIError, "the server responded with status #{e.response[:status] if e.response}"
    rescue StandardError => e
      raise LLMError, e.message
    end

    def build_api_parameters(model, messages, options = {}, task_type = 'generation')
      parameters = {
        model: model,
        messages: messages
      }

      # Get model-specific settings and add them to parameters
      model_settings = get_model_settings(model)

      # Handle token limits with fallback to task options
      task_token_limit = get_task_options(task_type)[:max_tokens]

      # Add each configured parameter, with options override
      model_settings.each do |param, value|
        param_key = param.to_sym

        # Special handling for token parameters - use task limit if smaller
        if param.include?('tokens')
          final_value = [options[param_key] || value, task_token_limit].min
          parameters[param_key] = final_value
        else
          # For other parameters, use options override or model default
          parameters[param_key] = options[param_key] || value
        end
      end

      parameters
    end

    def get_task_options(task_type, base_options = {})
      merged = (@config['default_options'] || {}).dup
      merged.merge!(@config['task_options'][task_type]) if @config['task_options'] && @config['task_options'][task_type]
      
      if task_type == 'summarization' && @settings['summarization']
        # Merge root-level summarization options (excluding model)
        sum_opts = @settings['summarization'].reject { |k, _| k == 'model' }
        merged.merge!(sum_opts)
      end

      merged['max_tokens'] ||= { 'generation' => 8000, 'translation' => 12_000, 'chat' => 4000 }[task_type] || 6000
      merged.merge(base_options).transform_keys(&:to_sym)
    end

    def get_model_settings(model)
      @config.dig('model_settings', model) || {}
    end

    def build_chapter_translation_prompt(title, summary, content, target_lang, glossary, book_metadata = nil)
      language_names = { 'ru' => 'Russian', 'es' => 'Spanish', 'fr' => 'French', 'de' => 'German', 'zh' => 'Chinese' }
      target_language_name = language_names[target_lang] || target_lang.upcase

      special_instructions = build_translation_rules(target_lang, book_metadata)

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
          ],
          "story_facts": {
            "locations": [
              { "name": "Location name", "description": "What makes this location significant", "type": "office|cafe|room|building|other" }
            ],
            "events": [
              { "name": "Event name", "description": "What happened and why it's important", "impact": "minor|major" }
            ],
            "world_rules": [
              { "rule": "How something works in this world", "category": "technology|culture|physics|other" }
            ],
            "relationships": [
              { "character1": "Name", "character2": "Name", "relationship": "colleague|mentor|rival|friend|other", "status": "established|changed" }
            ]
          }
        }

        Required fields: content
        Optional: title, summary, new_characters, story_facts
      SCHEMA

      "#{prompt}\n\n#{schema}"
    end

    def try_parse_json(text)
      return nil if text.to_s.strip.empty?

      begin
        JSON.parse(text)
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

      # Best effort to find project root since we don't have config_path anymore
      # We assume the caller (CLI) sets up the environment or we use PWD
      project_root = Dir.pwd
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

    def build_translation_rules(target_lang, book_metadata = nil)
      return '' unless book_metadata

      # Load translation rules from book configuration
      translation_rules = book_metadata.dig('generation', 'translation_rules', target_lang)
      return build_generic_translation_rules(target_lang) unless translation_rules

      rules_text = []
      language_names = { 'ru' => 'RUSSIAN', 'es' => 'SPANISH', 'fr' => 'FRENCH', 'de' => 'GERMAN', 'zh' => 'CHINESE' }
      lang_name = language_names[target_lang] || target_lang.upcase

      rules_text << "#{lang_name} TRANSLATION RULES:"

      # Character name mappings
      translation_rules['character_mappings']&.each do |original, translated|
        rules_text << "- \"#{original}\" → \"#{translated}\""
      end

      # Name style rules
      if translation_rules['name_style']
        case translation_rules['name_style']
        when 'japanese_transliteration'
          rules_text << '- Keep real names in Japanese style: "Satoru" → "Сатору", "Genki" → "Генки"'
        when 'preserve_original'
          rules_text << '- Preserve original character names without translation'
        end
      end

      # Address form rules
      translation_rules['address_forms']&.each do |original, translated|
        rules_text << "- Use respectful address: \"#{translated}\" for \"#{original}\""
      end

      # Technical term rules
      if translation_rules['technical_terms']
        case translation_rules['technical_terms']
        when 'mixed_en_ru'
          rules_text << '- Programming terms: mix English and Russian naturally (e.g., "программист", "код", but "pull request", "git")'
        when 'prefer_native'
          rules_text << '- Use native language equivalents for technical terms when available'
        when 'preserve_english'
          rules_text << '- Keep English technical terms in their original form'
        end
      end

      # Custom rules
      if translation_rules['custom_rules'].is_a?(Array)
        translation_rules['custom_rules'].each do |rule|
          rules_text << "- #{rule}"
        end
      end

      rules_text.empty? ? build_generic_translation_rules(target_lang) : "\n#{rules_text.join("\n")}"
    end

    def build_generic_translation_rules(target_lang)
      language_names = { 'ru' => 'RUSSIAN', 'es' => 'SPANISH', 'fr' => 'FRENCH', 'de' => 'GERMAN', 'zh' => 'CHINESE' }
      lang_name = language_names[target_lang] || target_lang.upcase

      <<~GENERIC

        #{lang_name} TRANSLATION GUIDELINES:
        - Preserve proper names and character names as appropriate for the story
        - Use natural #{target_lang} equivalents for common terms
        - Keep technical terms in their commonly used form
        - Maintain respectful address forms when present in original
      GENERIC
    end
  end
end

# Backward compatibility alias
LLMService = BookCore::LLMService unless defined?(LLMService)
