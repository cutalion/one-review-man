# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module BookCore
  # Handles loading and merging of configuration from defaults, project settings, and CLI options.
  class Configuration
    DEFAULTS_PATH = File.expand_path('defaults/settings.yml', __dir__)

    def self.load(project_root, cli_options = {})
      new(project_root, cli_options).resolve
    end

    def initialize(project_root, cli_options)
      @project_root = project_root
      @cli_options = cli_options
    end

    def resolve
      defaults = load_defaults
      project_settings = load_project_settings
      
      # Merge order: defaults -> project settings -> cli options
      config = deep_merge(defaults, project_settings)
      apply_cli_overrides(config, @cli_options)
    end

    private

    def load_defaults
      YAML.load_file(DEFAULTS_PATH) || {}
    rescue StandardError => e
      warn "⚠️  Failed to load default settings: #{e.message}"
      {}
    end

    def load_project_settings
      return {} unless @project_root

      settings_path = File.join(@project_root, 'data', 'settings.yml')
      return {} unless File.exist?(settings_path)

      YAML.load_file(settings_path) || {}
    rescue StandardError => e
      warn "⚠️  Failed to load project settings: #{e.message}"
      {}
    end

    def deep_merge(target, source)
      target.merge(source) do |key, oldval, newval|
        if oldval.is_a?(Hash) && newval.is_a?(Hash)
          deep_merge(oldval, newval)
        else
          newval
        end
      end
    end

    def apply_cli_overrides(config, options)
      options.each do |key, value|
        next if value.nil?

        # Support dot notation for nested keys (e.g. "llm.model")
        keys = key.to_s.split('.')
        last_key = keys.pop
        
        current = config
        keys.each do |k|
          current[k] ||= {}
          current = current[k]
          # If we hit a non-hash while traversing, we can't merge into it, so we stop or overwrite
          # For simplicity, we assume the structure matches if it exists
          break unless current.is_a?(Hash)
        end

        if current.is_a?(Hash)
          current[last_key] = value
        end
      end
      config
    end
  end
end
