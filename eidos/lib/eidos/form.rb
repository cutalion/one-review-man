# frozen_string_literal: true

require 'yaml'

module Eidos
  # A Form is the recipe for generating a Piece. It declares a name, a
  # category (text/image/script), a default length or shape, a prompt
  # template, and which canon-context slices its template expects.
  #
  # Forms are shipped as YAML files — built-ins at eidos/lib/eidos/forms/
  # and optional world-local overrides at worlds/<name>/data/forms/.
  # The FormRegistry merges them into the registry used for a single
  # CLI invocation.
  class Form
    CATEGORIES = %i[text image script].freeze
    CANON_CONTEXT_KEYS = %i[all_characters recent_events current_chapter all_locations none].freeze
    ORIGINS = %i[builtin world_local].freeze
    NAME_PATTERN = /\A[a-z][a-z0-9-]*\z/

    attr_reader :name, :category, :default_length, :default_shape,
                :prompt_template_path, :canon_context, :origin

    def initialize(name:, category:, prompt_template_path:, origin:,
                   default_length: nil, default_shape: nil, canon_context: nil)
      @name = name.to_s
      @category = category.to_s.to_sym
      @default_length = default_length
      @default_shape = default_shape
      @prompt_template_path = prompt_template_path
      @canon_context = Array(canon_context).map(&:to_sym)
      @canon_context = [:all_characters] if @canon_context.empty?
      @origin = origin.to_sym

      validate!
    end

    # Load a Form from a YAML file on disk. `origin` MUST be supplied by the
    # caller (the FormRegistry knows whether the file came from the gem's
    # builtin directory or a world-local directory). Returns nil and logs a
    # warning if the file is unparseable or references a missing template.
    def self.from_file(yaml_path, origin:)
      raw = YAML.safe_load_file(yaml_path, permitted_classes: [Symbol])
      return nil unless raw.is_a?(Hash)

      template_path = resolve_template_path(yaml_path, raw['prompt_template_path'])
      unless template_path && File.exist?(template_path)
        warn "⚠️  Form '#{raw['name']}' at #{yaml_path}: prompt template not found (#{raw['prompt_template_path'].inspect}) — skipping."
        return nil
      end

      ctx = normalize_canon_context(raw['canon_context'])
      return nil if ctx.nil?

      new(
        name: raw['name'],
        category: raw['category'],
        default_length: raw['default_length'],
        default_shape: raw['default_shape'],
        prompt_template_path: template_path,
        canon_context: ctx,
        origin: origin
      )
    rescue StandardError => e
      warn "⚠️  Failed to load form from #{yaml_path}: #{e.message}"
      nil
    end

    def text?
      @category == :text
    end

    def image?
      @category == :image
    end

    def script?
      @category == :script
    end

    def builtin?
      @origin == :builtin
    end

    def world_local?
      @origin == :world_local
    end

    # Read the prompt template contents from disk. Forms load templates lazily
    # so a registry of 8 built-ins doesn't pay the filesystem cost upfront.
    def prompt_template
      @prompt_template ||= File.read(@prompt_template_path)
    end

    def self.resolve_template_path(yaml_path, declared)
      return nil if declared.nil? || declared.to_s.empty?

      # Relative paths resolve against the form YAML's directory.
      if declared.to_s.start_with?('/')
        declared.to_s
      else
        File.expand_path(declared.to_s, File.dirname(yaml_path))
      end
    end

    def self.normalize_canon_context(raw)
      return [:all_characters] if raw.nil?

      list = Array(raw).map { |k| k.to_s.to_sym }
      unknown = list - CANON_CONTEXT_KEYS
      if unknown.any?
        warn "⚠️  Unknown canon_context values #{unknown.inspect} — form will be skipped."
        return nil
      end

      list
    end

    private

    def validate!
      raise ArgumentError, "Form name '#{@name}' invalid (must match #{NAME_PATTERN.source})" unless @name.match?(NAME_PATTERN)
      raise ArgumentError, "Form '#{@name}' has unknown category: #{@category}" unless CATEGORIES.include?(@category)
      raise ArgumentError, "Form '#{@name}' has unknown origin: #{@origin}" unless ORIGINS.include?(@origin)
      raise ArgumentError, "Form '#{@name}' needs default_length or default_shape" if @default_length.nil? && (@default_shape.nil? || @default_shape.to_s.strip.empty?)
    end
  end
end
