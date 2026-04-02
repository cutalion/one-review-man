# frozen_string_literal: true

module Eidos
  # Utilities for consistent nil/empty value handling and validation
  module ValidationUtils
    # Check if a value is present (not nil and not empty)
    # @param value [Object] Value to check
    # @return [Boolean] true if value is present
    def self.present?(value)
      return false if value.nil?
      return !value.empty? if value.respond_to?(:empty?)

      true
    end

    # Check if a value is blank (nil, empty, or only whitespace)
    # @param value [Object] Value to check
    # @return [Boolean] true if value is blank
    def self.blank?(value)
      return true if value.nil?
      return true if value.respond_to?(:empty?) && value.empty?
      return true if value.is_a?(String) && value.strip.empty?

      false
    end

    # Get a default value if the original is blank
    # @param value [Object] Original value
    # @param default [Object] Default value to use if original is blank
    # @return [Object] Original value or default
    def self.presence_or(value, default)
      present?(value) ? value : default
    end

    # Validate that required fields are present in a hash
    # @param data [Hash] Data to validate
    # @param required_fields [Array<String>] Field names that must be present
    # @return [Array<String>] List of missing fields
    def self.missing_required_fields(data, required_fields)
      return required_fields if data.nil?

      required_fields.select { |field| blank?(data[field]) }
    end

    # Safe string conversion that handles nil values
    # @param value [Object] Value to convert
    # @param default [String] Default string if value is nil
    # @return [String] String representation
    def self.safe_string(value, default = '')
      return default if value.nil?

      value.to_s
    end

    # Safe array access that returns empty array for nil
    # @param value [Object] Value that might be an array
    # @return [Array] Array or empty array
    def self.safe_array(value)
      return [] if value.nil?
      return value if value.is_a?(Array)

      [value]
    end

    # Safe hash access that returns empty hash for nil
    # @param value [Object] Value that might be a hash
    # @return [Hash] Hash or empty hash
    def self.safe_hash(value)
      return {} if value.nil?
      return value if value.is_a?(Hash)

      {}
    end

    # Validate character slug format
    # @param slug [String] Slug to validate
    # @return [Boolean] true if slug is valid
    def self.valid_slug?(slug)
      return false if blank?(slug)
      return false unless slug.is_a?(String)

      # Slug should contain only lowercase letters, numbers, and hyphens
      # Should not start or end with hyphen
      slug.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
    end

    # Generate a safe slug from a name
    # @param name [String] Name to convert to slug
    # @return [String] Safe slug
    def self.slugify(name)
      return '' if blank?(name)

      name.to_s
          .downcase
          .strip
          .gsub(/[^a-z0-9\s-]/, '') # Remove non-alphanumeric except spaces and hyphens
          .gsub(/\s+/, '-')         # Convert spaces to hyphens
          .gsub(/-+/, '-')          # Collapse multiple hyphens
          .gsub(/^-|-$/, '')        # Remove leading/trailing hyphens
    end
  end
end
