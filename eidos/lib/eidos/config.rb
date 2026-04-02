# frozen_string_literal: true

require 'yaml'

module Eidos
  # Configuration utilities for loading and parsing book settings
  class Config
    # Load YAML file and return a Hash; return empty Hash when file is missing
    # or when the file parses to nil.
    def self.load_yaml(file_path)
      return {} unless File.exist?(file_path)

      parsed = YAML.safe_load_file(file_path)
      parsed.is_a?(Hash) ? parsed : {}
    rescue Psych::SyntaxError
      {}
    end
  end
end
