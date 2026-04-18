# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module Eidos
  # Encapsulates world configuration with clean access patterns
  # Handles split configuration (static config vs dynamic state)
  class WorldConfig
    class ValidationError < StandardError; end
    class NotFoundError < StandardError; end

    attr_reader :config_path, :state_path

    def initialize(config_data, state_data, config_path = nil, state_path = nil)
      @config_data = config_data.dup
      @state_data = state_data.dup
      @config_path = config_path
      @state_path = state_path
      @dirty_config = false
      @dirty_state = false
      validate_structure!
    end

    # Factory methods
    def self.load_from_project(project_root)
      config_path = File.join(project_root, 'data', 'world_config.yml')
      state_path = File.join(project_root, 'data', 'world_state.yml')
      legacy_path = File.join(project_root, 'data', 'world_metadata.yml')

      if File.exist?(config_path) || File.exist?(state_path)
        load_split_config(config_path, state_path)
      elsif File.exist?(legacy_path)
        load_legacy_config(legacy_path)
      else
        new({}, {}, config_path, state_path)
      end
    end

    def self.load_split_config(config_path, state_path)
      config_data = File.exist?(config_path) ? YAML.safe_load_file(config_path) : {}
      state_data = File.exist?(state_path) ? YAML.safe_load_file(state_path) : {}
      new(config_data, state_data, config_path, state_path)
    end

    def self.load_legacy_config(path)
      data = YAML.safe_load_file(path) || {}
      # Split in memory for consistent internal API
      state_keys = %w[world status]
      state_data = data.slice(*state_keys)
      config_data = data.except(*state_keys)
      
      # We store the legacy path in both to indicate where to save back to
      # (special handling in save! will be needed if we want to support legacy saving,
      # but ideally we migrate)
      instance = new(config_data, state_data, path, path)
      instance.instance_variable_set(:@legacy_mode, true)
      instance
    end

    # Language-specific data access
    def en_metadata
      @config_data.dig('localized', 'en') || {}
    end

    def ru_metadata
      @config_data.dig('localized', 'ru') || {}
    end

    def localized_data(lang)
      @config_data.dig('localized', lang.to_s) || {}
    end

    def update_localized(lang, updates)
      @config_data['localized'] ||= {}
      @config_data['localized'][lang.to_s] ||= {}
      @config_data['localized'][lang.to_s].merge!(updates)
      mark_config_dirty!
      self
    end

    # Generation configuration
    def content_rules
      @config_data.dig('generation', 'content_rules') || {}
    end

    def main_characters
      @config_data.dig('generation', 'main_characters') || []
    end

    def chapter_length_target
      @config_data.dig('generation', 'chapter_length_target') || '1500-3000 words'
    end

    def translation_rules_for(lang)
      @config_data.dig('generation', 'translation_rules', lang.to_s) || {}
    end

    def generation_config
      @config_data['generation'] || {}
    end

    # World status management (State)
    def current_chapter
      @state_data.dig('world', 'current_chapter') || 0
    end

    def update_current_chapter(chapter_num)
      @state_data['world'] ||= {}
      @state_data['world']['current_chapter'] = chapter_num.to_i
      mark_state_dirty!
      self
    end

    def world_status
      @state_data['world'] || {}
    end

    # Convenient accessors (Config)
    # -----------------------------------------------------------------
    # Canonical `story_*` accessors per Clarifications Q2 + FR-021.
    # Read precedence: `story_<field>` wins; then `book_<field>` (pre-0.3
    # key shape); then the bare `<field>` (pre-localized key shape). Any
    # fallback path emits a one-time deprecation notice to $stderr.
    # Contract: specs/013-spec-coverage-backfill/contracts/story-placeholder-compat.md
    # TODO(follow-up): remove the book_/bare-name branches after two releases.
    def story_title(lang = 'en')
      localized_field_with_compat(lang, 'title') || @config_data['title'] || 'Untitled'
    end

    def story_genre(lang = 'en')
      localized_field_with_compat(lang, 'genre') || 'Fiction'
    end

    def story_setting(lang = 'en')
      localized_field_with_compat(lang, 'setting')
    end

    def story_style(lang = 'en')
      localized_field_with_compat(lang, 'style', extra_bare_names: %w[humor_style]) || 'narrative'
    end

    # Legacy accessors — kept for back-compat; delegate to the story_*
    # versions so a single read-path change propagates everywhere.
    def title(lang = 'en')
      story_title(lang)
    end

    def genre(lang = 'en')
      story_genre(lang)
    end

    def setting(lang = 'en')
      story_setting(lang)
    end

    def humor_style(lang = 'en')
      story_style(lang)
    end

    def author(lang = 'en')
      localized_data(lang)['author'] || @config_data['author'] || 'Unknown'
    end

    def themes(lang = 'en')
      localized_data(lang)['themes'] || {}
    end

    def primary_theme(lang = 'en')
      themes(lang)['primary']
    end

    def description(lang = 'en')
      localized_data(lang)['description'] || @config_data['description']
    end

    # Neutral, genre-agnostic default so new worlds don't inherit ORM framing.
    def story_description(lang = 'en')
      localized_data(lang)['story_description'] ||
        localized_data(lang)['description'] ||
        localized_data(lang)['subtitle'] ||
        @config_data['description'] ||
        'A fresh story to be developed.'
    end

    # Site configuration (Config)
    def site_url
      @config_data['site_url']
    end

    def twitter_username
      @config_data['twitter_username']
    end

    def github_username
      @config_data['github_username']
    end

    def site_domain
      @config_data['site_domain']
    end

    # Direct access for edge cases
    # Note: This is ambiguous now, defaulting to config for read, but we should deprecate this usage
    def get(key)
      @config_data[key.to_s] || @state_data[key.to_s]
    end

    def set(key, value)
      # Heuristic to decide where to put it
      if %w[world status].include?(key.to_s)
        @state_data[key.to_s] = value
        mark_state_dirty!
      else
        @config_data[key.to_s] = value
        mark_config_dirty!
      end
      self
    end

    # Persistence
    def save!
      if @legacy_mode
        save_legacy!
      else
        save_split!
      end
      self
    end

    def save_split!
      if @dirty_config && @config_path
        FileUtils.mkdir_p(File.dirname(@config_path))
        File.write(@config_path, @config_data.to_yaml)
        @dirty_config = false
      end

      if @dirty_state && @state_path
        FileUtils.mkdir_p(File.dirname(@state_path))
        File.write(@state_path, @state_data.to_yaml)
        @dirty_state = false
      end
    end

    def save_legacy!
      return unless @config_path # In legacy mode, both paths are the same

      merged_data = @config_data.merge(@state_data)
      FileUtils.mkdir_p(File.dirname(@config_path))
      File.write(@config_path, merged_data.to_yaml)
      @dirty_config = false
      @dirty_state = false
    end

    def dirty?
      @dirty_config || @dirty_state
    end

    # Validation
    def validate!
      validate_structure!
      validate_required_fields!
      self
    end

    def valid?
      validate!
      true
    rescue ValidationError
      false
    end

    # Access to raw data for compatibility during migration
    def raw_data
      # Return merged view
      deep_dup(@config_data).merge(deep_dup(@state_data))
    end

    # Useful predicates
    def language?(lang)
      localized_lang_data = @config_data.dig('localized', lang.to_s)
      return false unless localized_lang_data.is_a?(Hash)

      localized_lang_data.any? { |_, v| !v.to_s.strip.empty? }
    end

    def multilingual?
      (@config_data['localized'] || {}).keys.length > 1
    end

    def localized_structure?
      @config_data['localized'].is_a?(Hash)
    end

    private

    # Read a localized field with the BOOK→STORY back-compat chain.
    # `extra_bare_names` carries pre-migration aliases for fields whose
    # bare spelling isn't the same as the suffix (e.g. `style` fell out
    # of the legacy `humor_style` key).
    def localized_field_with_compat(lang, field, extra_bare_names: [])
      localized = localized_data(lang)
      story_key = "story_#{field}"
      return localized[story_key] if localized.key?(story_key)

      book_key = "book_#{field}"
      if localized.key?(book_key) && !localized[book_key].nil?
        emit_deprecation_notice_once(lang, field, key: book_key)
        return localized[book_key]
      end

      ([field] + extra_bare_names).each do |bare|
        next unless localized.key?(bare) && !localized[bare].nil?

        emit_deprecation_notice_once(lang, field, key: bare)
        return localized[bare]
      end

      nil
    end

    # Process-scoped memoization of deprecation notices. Key shape:
    # (config_file_path, locale, field) — fires at most once per tuple
    # per process so multi-world sessions don't spam stderr.
    @@emitted_deprecation_notices = {} # rubocop:disable Style/ClassVars
    def emit_deprecation_notice_once(locale, field, key:)
      path = @config_path.to_s
      tuple = [path, locale.to_s, field.to_s]
      return if @@emitted_deprecation_notices[tuple]

      @@emitted_deprecation_notices[tuple] = true
      warn "⚠️  DEPRECATED: #{path.empty? ? '<unsaved world>' : path} uses legacy `#{key}` key for locale `#{locale}`."
      warn "   Rename to `story_#{field}` before the next release."
      warn '   See specs/013-spec-coverage-backfill/spec.md Clarifications Q2.'
    end

    def mark_config_dirty!
      @dirty_config = true
    end

    def mark_state_dirty!
      @dirty_state = true
    end

    def deep_dup(obj)
      case obj
      when Hash
        obj.transform_values { |v| deep_dup(v) }
      when Array
        obj.map { |v| deep_dup(v) }
      else
        begin
          obj.dup
        rescue StandardError
          obj
        end
      end
    end

    def validate_structure!
      # Basic structure validation
      raise ValidationError, 'Config data must be a Hash' unless @config_data.is_a?(Hash)
      raise ValidationError, 'State data must be a Hash' unless @state_data.is_a?(Hash)

      raise ValidationError, 'localized must be a Hash' if @config_data['localized'] && !@config_data['localized'].is_a?(Hash)

      raise ValidationError, 'generation must be a Hash' if @config_data['generation'] && !@config_data['generation'].is_a?(Hash)

      return unless @state_data['world']
      raise ValidationError, 'world state must be a Hash' unless @state_data['world'].is_a?(Hash)
    end

    def validate_required_fields!
      # For now, just ensure basic structure is present
      # Could add more specific validation rules here if needed
      # This method will raise exceptions if validation fails, otherwise returns nil
      nil
    end
  end
end
