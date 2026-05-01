#!/usr/bin/env ruby
# frozen_string_literal: true

# Utilities for processing prompt templates and placeholder replacement
module Eidos
module PromptUtils
  # Error raised when prompt template contains unfilled placeholders
  class UnfilledPlaceholdersError < StandardError
    attr_reader :unfilled_placeholders

    def initialize(unfilled_placeholders)
      @unfilled_placeholders = unfilled_placeholders
      super("Unfilled placeholders found: #{unfilled_placeholders.join(', ')}")
    end
  end

  # Placeholder names that are only meaningful inside {{#CHARACTER_SECTION}} blocks;
  # suppress unused-placeholder warnings for them when the section is empty/elided.
  CHARACTER_SECTION_KEYS = %w[CHARACTER_NAME CHARACTER_DESCRIPTION].freeze

  # Build a prompt from a template string and a hash of placeholders
  # @param template [String] The template string with placeholders like {{PLACEHOLDER_NAME}}
  # @param placeholders [Hash] Hash with placeholder names as keys and replacement values as values
  # @param warn_unused [Boolean] Whether to warn about unused placeholders (default: true)
  # @param context [String] Context description for warning messages (default: nil)
  # @param characters [Array, nil] Character entries that drive {{#CHARACTER_SECTION}}...
  #   {{/CHARACTER_SECTION}} block rendering. When nil the template is left as-is;
  #   when [] the block is stripped entirely; when populated the section is kept.
  # @return [String] The processed prompt with placeholders replaced
  # @raise [UnfilledPlaceholdersError] If any placeholders remain unfilled
  def self.build_prompt(template, placeholders, warn_unused: true, context: nil, characters: nil)
    raise ArgumentError, 'Template cannot be nil' if template.nil?
    raise ArgumentError, 'Placeholders must be a Hash' unless placeholders.is_a?(Hash)

    # Convert all placeholder keys to strings for consistency
    normalized_placeholders = {}
    placeholders.each do |key, value|
      normalized_placeholders[key.to_s] = value
    end

    working_template = apply_character_section(template, characters)

    # Find all placeholders in the (post-section-handling) template
    template_placeholders = extract_placeholders(working_template)

    # Track which placeholders were used
    used_placeholders = Set.new

    # Replace placeholders
    result = working_template.dup
    template_placeholders.each do |placeholder|
      next unless normalized_placeholders.key?(placeholder)

      value = normalized_placeholders[placeholder]
      # Convert nil values to empty string to avoid leaving placeholder
      replacement_value = value.nil? ? '' : value.to_s
      result.gsub!("{{#{placeholder}}}", replacement_value)
      used_placeholders.add(placeholder)
    end

    # Check for unfilled placeholders
    remaining_placeholders = extract_placeholders(result)
    raise UnfilledPlaceholdersError, remaining_placeholders if remaining_placeholders.any?

    # Warn about unused placeholders. CHARACTER_NAME / CHARACTER_DESCRIPTION are
    # advisory keys that callers may pre-populate even when the surrounding
    # {{#CHARACTER_SECTION}}...{{/CHARACTER_SECTION}} block is absent or elided,
    # so never include them in the warning noise.
    if warn_unused
      unused_placeholders = normalized_placeholders.keys - used_placeholders.to_a
      unused_placeholders -= CHARACTER_SECTION_KEYS
      if unused_placeholders.any?
        warning_msg = "⚠️  Warning: Unused placeholders provided: #{unused_placeholders.join(', ')}"
        warning_msg += " (in #{context})" if context
        warn warning_msg
      end
    end

    result
  end

  # Handle {{#CHARACTER_SECTION}}...{{/CHARACTER_SECTION}} blocks based on the
  # `characters:` kwarg. Empty array → strip the blocks; populated array → keep
  # the contents; nil → leave template unchanged.
  def self.apply_character_section(template, characters)
    return template if characters.nil?

    if characters.empty?
      template.gsub(/\{\{#CHARACTER_SECTION\}\}.*?\{\{\/CHARACTER_SECTION\}\}/m, '')
    else
      template
        .gsub('{{#CHARACTER_SECTION}}', '')
        .gsub('{{/CHARACTER_SECTION}}', '')
    end
  end

  # Extract all placeholder names from a template string
  # @param template [String] The template string
  # @return [Array<String>] Array of placeholder names (without the braces)
  def self.extract_placeholders(template)
    # Look for {{PLACEHOLDER}} format (double braces, no spaces)
    # This distinguishes from Jekyll Liquid syntax like {{ site.title }} (with spaces)
    template.scan(/\{\{([A-Z_][A-Z0-9_]*)\}\}/).flatten.uniq
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
  # @param context [String] Context description for warning messages (default: nil)
  # @return [String] The processed prompt
  # @raise [UnfilledPlaceholdersError] If any placeholders remain unfilled
  # @raise [StandardError] If template file doesn't exist
  def self.build_prompt_from_file(template_file, placeholders, warn_unused: true, context: nil)
    raise "Template file not found: #{template_file}" unless File.exist?(template_file)

    template = File.read(template_file, encoding: 'UTF-8')
    build_prompt(template, placeholders, warn_unused: warn_unused, context: context)
  end
end
end
