# frozen_string_literal: true

module BookCore
  # Utility methods for consistent environment variable handling
  module EnvUtils
    # Check if AI mocking is enabled
    # @return [Boolean] true if MOCK_AI environment variable is set to '1' or 'true'
    def self.mock_ai_enabled?
      %w[1 true].include?(ENV.fetch('MOCK_AI', nil))
    end

    # Check if debug mode is enabled for AI operations
    # @return [Boolean] true if DEBUG_AI environment variable is set to '1' or 'true'
    def self.debug_ai_enabled?
      %w[1 true].include?(ENV.fetch('DEBUG_AI', nil))
    end

    # Get OpenAI API key from environment or config
    # @param config [Hash] Configuration hash that may contain openai_api_key
    # @return [String, nil] API key if found
    def self.openai_api_key(config = {})
      ENV['OPENAI_API_KEY'] || config['openai_api_key']
    end

    # Get OpenAI organization ID from environment or config
    # @param config [Hash] Configuration hash that may contain openai_org_id
    # @return [String, nil] Organization ID if found
    def self.openai_org_id(config = {})
      ENV['OPENAI_ORG_ID'] || config['openai_org_id']
    end

    # Get OpenAI base URL from environment or config
    # @param config [Hash] Configuration hash that may contain openai_base_url
    # @return [String, nil] Base URL if found
    def self.openai_base_url(config = {})
      ENV['OPENAI_BASE_URL'] || config['openai_base_url']
    end

    # Get OpenRouter API key from environment or config
    # @param config [Hash] Configuration hash that may contain openrouter_api_key
    # @return [String, nil] API key if found
    def self.openrouter_api_key(config = {})
      ENV['OPENROUTER_API_KEY'] || config['openrouter_api_key']
    end

    # Get Jekyll template path from environment or default
    # @param default_path [String] Default template path to use if not set
    # @return [String] Template path
    def self.jekyll_template_path(default_path)
      ENV['JEKYLL_TEMPLATE_PATH'] || default_path
    end
  end
end
