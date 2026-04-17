# frozen_string_literal: true

require 'json'
require 'yaml'
require 'eidos/probe'

module Eidos
  module CLI
    # Runner behind `eidos probe MODEL`. Not a Thor class — the Thor command
    # lives directly on CLI::Main, and delegates here.
    #
    # Credential precedence (highest wins):
    #   1. --api-key flag
    #   2. -w WORLD_DIR --> data/settings.yml providers[<p>].api_key_env --> ENV
    #   3. Conventional ENV fallback (OPENAI_API_KEY / OPENROUTER_API_KEY)
    class ProbeCli
      DEFAULT_ENV_KEYS = {
        'openai'     => 'OPENAI_API_KEY',
        'openrouter' => 'OPENROUTER_API_KEY'
      }.freeze

      def self.run(model, options = {})
        new(options).run(model)
      end

      def initialize(options = {})
        @options = options
      end

      def run(model)
        if %w[--help -h help].include?(model)
          print_help
          exit 0
        end

        if model.start_with?('-')
          warn "MODEL looks like a flag ('#{model}'). Did you mean `eidos help probe`?"
          exit 2
        end

        provider = (@options['provider'] || 'openai').to_s.downcase

        unless Eidos::Probe::SUPPORTED_PROVIDERS.include?(provider)
          warn "Unsupported provider '#{provider}'. Supported: #{Eidos::Probe::SUPPORTED_PROVIDERS.join(', ')}"
          exit 2
        end

        world_dir = @options['world-dir']
        world_settings = load_world_settings(world_dir)
        api_key  = resolve_api_key(provider, @options['api-key'], world_settings)
        base_url = resolve_base_url(provider, @options['base-url'], world_settings)

        unless api_key
          warn credential_error_message(provider, world_dir)
          exit 2
        end

        result = Eidos::Probe.new(
          provider: provider,
          model: model,
          api_key: api_key,
          base_url: base_url,
          timeout: (@options['timeout'] || 60).to_i
        ).run

        if @options['json']
          puts JSON.generate(result.to_h.transform_keys(&:to_s))
        else
          puts format_human(result, metrics: !!@options['metrics'])
        end

        exit(result.ok? ? 0 : 1)
      end

      private

      def print_help
        require 'eidos/cli/main'
        Eidos::CLI::Main.new.help('probe')
      end

      def load_world_settings(world_dir)
        return nil unless world_dir

        path = File.join(File.expand_path(world_dir), 'data', 'settings.yml')
        return nil unless File.exist?(path)

        YAML.safe_load_file(path, permitted_classes: [Symbol]) || {}
      rescue StandardError
        nil
      end

      def resolve_api_key(provider, flag_value, world_settings)
        return flag_value if flag_value && !flag_value.empty?

        if world_settings
          env_key = world_settings.dig('providers', provider, 'api_key_env')
          val = env_key && ENV[env_key]
          return val if val && !val.empty?
        end

        env_key = DEFAULT_ENV_KEYS[provider]
        val = env_key && ENV[env_key]
        return val if val && !val.empty?

        nil
      end

      def resolve_base_url(provider, flag_value, world_settings)
        return flag_value if flag_value && !flag_value.empty?

        if world_settings
          provider_cfg = world_settings.dig('providers', provider) || {}
          return provider_cfg['base_url'] if provider_cfg['base_url'] && !provider_cfg['base_url'].to_s.empty?

          env_key = provider_cfg['base_url_env']
          val = env_key && ENV[env_key]
          return val if val && !val.empty?
        end

        nil
      end

      def credential_error_message(provider, world_dir)
        checked = []
        checked << "world settings (#{world_dir}/data/settings.yml)" if world_dir
        checked << "ENV[#{DEFAULT_ENV_KEYS[provider]}]" if DEFAULT_ENV_KEYS[provider]
        "No API key for provider '#{provider}'. Checked: #{checked.join(', ')}. " \
          "Pass --api-key=..., or set the appropriate environment variable."
      end

      def format_human(result, metrics:)
        if result.ok?
          head = "OK #{result.provider} #{result.model} (#{result.latency_ms}ms"
          if metrics && result.input_tokens && result.output_tokens
            head += ", #{result.input_tokens} in / #{result.output_tokens} out tokens"
          end
          head += '): '
          "#{head}#{result.response_excerpt.inspect}"
        else
          "FAIL #{result.provider} #{result.model} [#{result.failure_category}]: #{result.error_message}"
        end
      end
    end
  end
end
