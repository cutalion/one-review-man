#!/usr/bin/env ruby
# frozen_string_literal: true

require 'set'

module PromptUtils
  class UnfilledPlaceholdersError < StandardError
    attr_reader :unfilled_placeholders

    def initialize(unfilled_placeholders)
      @unfilled_placeholders = unfilled_placeholders
      super("Unfilled placeholders found: #{unfilled_placeholders.join(', ')}")
    end
  end

  # Build a prompt from a template string and a hash of placeholders
  # @param template [String] The template string with placeholders like {PLACEHOLDER_NAME}
  # @param placeholders [Hash] Hash with placeholder names as keys and replacement values as values
  # @param warn_unused [Boolean] Whether to warn about unused placeholders (default: true)
  # @return [String] The processed prompt with placeholders replaced
  # @raise [UnfilledPlaceholdersError] If any placeholders remain unfilled
  def self.build_prompt(template, placeholders, warn_unused: true)
    raise ArgumentError, 'Template cannot be nil' if template.nil?
    raise ArgumentError, 'Placeholders must be a Hash' unless placeholders.is_a?(Hash)

    # Convert all placeholder keys to strings for consistency
    normalized_placeholders = {}
    placeholders.each do |key, value|
      normalized_placeholders[key.to_s] = value
    end

    # Find all placeholders in the template
    template_placeholders = extract_placeholders(template)
    
    # Track which placeholders were used
    used_placeholders = Set.new
    
    # Replace placeholders
    result = template.dup
    template_placeholders.each do |placeholder|
      if normalized_placeholders.key?(placeholder)
        value = normalized_placeholders[placeholder]
        # Convert nil values to empty string to avoid leaving placeholder
        replacement_value = value.nil? ? '' : value.to_s
        result.gsub!("{#{placeholder}}", replacement_value)
        used_placeholders.add(placeholder)
      end
    end

    # Check for unfilled placeholders
    remaining_placeholders = extract_placeholders(result)
    if remaining_placeholders.any?
      raise UnfilledPlaceholdersError, remaining_placeholders
    end

    # Warn about unused placeholders
    if warn_unused
      unused_placeholders = normalized_placeholders.keys - used_placeholders.to_a
      if unused_placeholders.any?
        puts "⚠️  Warning: Unused placeholders provided: #{unused_placeholders.join(', ')}"
      end
    end

    result
  end

  # Extract all placeholder names from a template string
  # @param template [String] The template string
  # @return [Array<String>] Array of placeholder names (without the braces)
  def self.extract_placeholders(template)
    template.scan(/\{([^}]+)\}/).flatten.uniq
  end

  # Validate that all required placeholders are provided
  # @param template [String] The template string
  # @param placeholders [Hash] Hash with placeholder names as keys
  # @return [Array<String>] Array of missing placeholder names
  def self.validate_placeholders(template, placeholders)
    template_placeholders = extract_placeholders(template)
    provided_placeholders = placeholders.keys.map(&:to_s)
    
    template_placeholders - provided_placeholders
  end

  # Load a template from a file and build prompt
  # @param template_file [String] Path to the template file
  # @param placeholders [Hash] Hash with placeholder names as keys and replacement values as values
  # @param warn_unused [Boolean] Whether to warn about unused placeholders (default: true)
  # @return [String] The processed prompt
  # @raise [UnfilledPlaceholdersError] If any placeholders remain unfilled
  # @raise [StandardError] If template file doesn't exist
  def self.build_prompt_from_file(template_file, placeholders, warn_unused: true)
    raise "Template file not found: #{template_file}" unless File.exist?(template_file)
    
    template = File.read(template_file)
    build_prompt(template, placeholders, warn_unused: warn_unused)
  end
end 
