# frozen_string_literal: true

require 'yaml'

module BookCore
  class Config
    # Load YAML file and return a Hash; return empty Hash when file is missing
    # or when the file parses to nil.
    def self.load_yaml(file_path)
      return {} unless File.exist?(file_path)

      parsed = YAML.safe_load(File.read(file_path))
      parsed.is_a?(Hash) ? parsed : {}
    rescue Psych::SyntaxError
      {}
    end
  end
end 
