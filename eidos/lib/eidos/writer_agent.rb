# frozen_string_literal: true

require 'json'
require 'yaml'
require 'eidos/story_bible'
require 'eidos/agent_tools/story_bible_tools'
require 'eidos/env_utils'

module Eidos
  # Agent-based chapter writer that uses tools to query the Story Bible.
  # The agent runs in a loop, making tool calls until it submits a chapter.
  class WriterAgent
    MAX_ITERATIONS = 20
    DEFAULT_MODEL = 'google/gemini-3-flash-preview'

    attr_reader :chapter_result

    def initialize(llm_service:, story_bible:, project_root: Dir.pwd, debug: false)
      @llm_service = llm_service
      @story_bible = story_bible
      @project_root = project_root
      @debug = debug || EnvUtils.debug_ai_enabled?
      @chapter_result = nil
      @tool_calls_log = []
    end

    # Generate a chapter using the agent loop
    # @param chapter_number [Integer] The chapter number to generate
    # @param requirements [String] Optional additional requirements for the chapter
    # @return [Hash] The generated chapter data
    def generate_chapter(chapter_number, requirements: nil)
      @chapter_result = nil
      @tool_calls_log = []

      # Handle mock mode
      if EnvUtils.mock_ai_enabled?
        return mock_chapter(chapter_number)
      end

      messages = build_initial_messages(chapter_number, requirements)
      tools = AgentTools::StoryBibleTools.for_api

      iteration = 0
      while iteration < MAX_ITERATIONS
        iteration += 1
        debug_log("=== Iteration #{iteration} ===")

        response = call_llm_with_tools(messages, tools)
        
        # Check if the response contains tool calls
        tool_calls = response.dig('choices', 0, 'message', 'tool_calls')
        
        if tool_calls && !tool_calls.empty?
          # Add assistant message with tool calls
          assistant_message = response.dig('choices', 0, 'message')
          messages << assistant_message

          # Execute tools and add results
          tool_calls.each do |tool_call|
            result = execute_tool(tool_call)
            messages << {
              'role' => 'tool',
              'tool_call_id' => tool_call['id'],
              'content' => result.to_json
            }

            # Check if this was a submit_chapter call
            if tool_call.dig('function', 'name') == 'submit_chapter' && @chapter_result
              debug_log("Chapter submitted successfully!")
              return @chapter_result
            end
          end
        else
          # No tool calls - agent is done but didn't submit
          content = response.dig('choices', 0, 'message', 'content')
          debug_log("Agent finished without submitting. Response: #{content&.slice(0, 200)}...")
          
          # Try to parse as JSON in case the model returned the chapter directly
          if content
            begin
              parsed = JSON.parse(content)
              if parsed['content'] || parsed['title']
                @chapter_result = normalize_chapter_result(parsed)
                return @chapter_result
              end
            rescue JSON::ParserError
              # Not JSON, continue
            end
          end
          
          # Ask the agent to submit
          messages << {
            'role' => 'user',
            'content' => 'Please submit your chapter using the submit_chapter tool.'
          }
        end
      end

      raise LLMService::APIError, "Agent exceeded maximum iterations (#{MAX_ITERATIONS}) without submitting a chapter"
    end

    # Get the log of tool calls made during generation
    def tool_calls_log
      @tool_calls_log.dup
    end

    private

    def build_initial_messages(chapter_number, requirements)
      system_prompt = build_system_prompt(chapter_number)
      user_prompt = build_user_prompt(chapter_number, requirements)

      [
        { 'role' => 'system', 'content' => system_prompt },
        { 'role' => 'user', 'content' => user_prompt }
      ]
    end

    def build_system_prompt(chapter_number)
      config = world_config_object

      <<~PROMPT
        You are a creative writer for "#{config.story_title}", a #{config.story_genre.to_s.downcase} story.

        STORY CONCEPT:
        #{config.story_description}

        STYLE:
        - #{config.story_style} narrative voice
        - Tone and humor consistent with the established genre
        - Engaging narrative with character development
        
        YOUR TASK:
        Write Chapter #{chapter_number}. Use the provided tools to:
        1. First, check recent chapter summaries for context
        2. Look up characters you want to feature
        3. Check active plot threads
        4. Review world rules for consistency
        5. Write the chapter
        6. Submit using the submit_chapter tool
        
        IMPORTANT:
        - Always query the story bible for character details before writing about them
        - Maintain consistency with established facts and relationships
        - The chapter should be substantial (at least 1000 words)
        - Include dialogue and character interactions
        - When done, use the submit_chapter tool with all required fields
      PROMPT
    end

    def build_user_prompt(chapter_number, requirements)
      prompt = "Write Chapter #{chapter_number}."
      
      if requirements
        prompt += "\n\nAdditional requirements:\n#{requirements}"
      end
      
      prompt += "\n\nStart by using tools to gather context about the story so far."
      prompt
    end

    def call_llm_with_tools(messages, tools)
      model = resolve_model
      provider = resolve_provider
      client = @llm_service.get_client(provider)
      
      raise LLMService::ConfigurationError, "No client configured for provider '#{provider}'" unless client

      max_tokens = agent_config['max_completion_tokens'] || 8000

      parameters = {
        model: model,
        messages: messages,
        tools: tools,
        max_completion_tokens: max_tokens
      }

      debug_log("Calling LLM with #{messages.length} messages, model: #{model}, provider: #{provider}")
      debug_dump('agent_request.json', JSON.pretty_generate(parameters))

      response = client.chat(parameters: parameters)
      
      debug_dump('agent_response.json', JSON.pretty_generate(response))
      response
    end

    def resolve_model
      agent_config['model'] || DEFAULT_MODEL
    end

    def resolve_provider
      provider = agent_config['provider']
      return provider if provider

      # Fallback: use OpenRouter for google/ models, otherwise use generation provider
      model = resolve_model
      model.start_with?('google/') ? 'openrouter' : @llm_service.get_provider_for_task('generation')
    end

    def agent_config
      @agent_config ||= begin
        settings = @llm_service.instance_variable_get(:@settings) || {}
        settings['agent'] || {}
      end
    end

    def execute_tool(tool_call)
      function_name = tool_call.dig('function', 'name')
      arguments_json = tool_call.dig('function', 'arguments') || '{}'
      
      begin
        arguments = JSON.parse(arguments_json)
      rescue JSON::ParserError
        arguments = {}
      end

      debug_log("Tool call: #{function_name}(#{arguments.inspect})")
      @tool_calls_log << { name: function_name, arguments: arguments, timestamp: Time.now }

      result = case function_name
               when 'get_character'
                 @story_bible.get_character(arguments['id'])
               when 'list_characters'
                 @story_bible.list_characters(appeared_in: arguments['appeared_in'])
               when 'get_location'
                 @story_bible.get_location(arguments['id'])
               when 'list_locations'
                 @story_bible.locations.map { |id, data| { 'id' => id, 'name' => data['name'] } }
               when 'get_chapter_summaries'
                 get_chapter_summaries(arguments['count'] || 3)
               when 'get_plot_threads'
                 @story_bible.active_plot_threads
               when 'get_world_rules'
                 @story_bible.world_rules.values.map { |r| r['rule'] || r['description'] }
               when 'search_facts'
                 @story_bible.search_facts(arguments['query'])
               when 'get_relationships'
                 @story_bible.get_relationships_for(arguments['character_id'])
               when 'submit_chapter'
                 handle_submit_chapter(arguments)
               else
                 { error: "Unknown tool: #{function_name}" }
               end

      result || { error: "No result from #{function_name}" }
    end

    def handle_submit_chapter(arguments)
      @chapter_result = normalize_chapter_result(arguments)
      
      { 
        success: true, 
        message: "Chapter '#{@chapter_result['title']}' submitted successfully.",
        word_count: @chapter_result['content'].to_s.split.length
      }
    end

    def normalize_chapter_result(data)
      {
        'title' => data['title'] || 'Untitled Chapter',
        'content' => data['content'] || '',
        'summary' => data['summary'] || '',
        'characters_featured' => data['characters_featured'] || [],
        'new_characters' => data['new_characters'] || [],
        'new_facts' => data['new_facts'] || []
      }
    end

    def get_chapter_summaries(count)
      summaries = []
      chapters_dir = File.join(@project_root, 'content', 'chapters')
      
      return summaries unless Dir.exist?(chapters_dir)

      chapter_files = Dir.glob(File.join(chapters_dir, '*.md')).sort.last(count)
      
      chapter_files.each do |file|
        content = File.read(file)
        # Parse front matter
        if content =~ /\A---\s*\n(.*?)\n---\s*\n/m
          front_matter = YAML.safe_load(Regexp.last_match(1)) rescue {}
          summaries << {
            'chapter' => front_matter['chapter_number'] || File.basename(file).match(/(\d+)/)[1].to_i,
            'title' => front_matter['title'],
            'summary' => front_matter['summary']
          }
        end
      end

      summaries
    end

    def load_world_config
      config_path = File.join(@project_root, 'data', 'world_config.yml')
      return {} unless File.exist?(config_path)

      YAML.safe_load_file(config_path) || {}
    rescue StandardError
      {}
    end

    def world_config_object
      @world_config_object ||= WorldConfig.load_from_project(@project_root)
    end

    def mock_chapter(chapter_number)
      {
        'title' => "Mock Chapter #{chapter_number}",
        'content' => "This is mock content for Chapter #{chapter_number}.\n\nGenerated in MOCK_AI mode for testing.",
        'summary' => "Mock summary for Chapter #{chapter_number}",
        'characters_featured' => ['kenji_yamamoto'],
        'new_characters' => [],
        'new_facts' => []
      }
    end

    def debug_log(message)
      return unless @debug

      puts "[WriterAgent] #{message}"
    end

    def debug_dump(filename, content)
      return unless @debug

      dir = File.join(@project_root, 'tmp', 'agent_debug')
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, filename), content)
    rescue StandardError
      # Best effort
    end
  end
end
