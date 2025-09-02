# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module BookCore
  # Encapsulates book metadata configuration with clean access patterns
  # Eliminates the need to pass around raw metadata hashes
  class BookConfig
    class ValidationError < StandardError; end
    class NotFoundError < StandardError; end

    def initialize(data = {}, file_path = nil)
      @data = data.dup
      @file_path = file_path
      @dirty = false
      validate_structure!
    end

    # Factory methods
    def self.load_from_file(path)
      raise NotFoundError, "Config file not found: #{path}" unless File.exist?(path)

      data = YAML.safe_load_file(path) || {}
      new(data, path)
    end

    def self.load_from_project(project_root)
      path = File.join(project_root, 'data', 'book_metadata.yml')
      load_from_file(path)
    end

    # Language-specific data access
    def en_metadata
      @data.dig('localized', 'en') || {}
    end

    def ru_metadata
      @data.dig('localized', 'ru') || {}
    end

    def localized_data(lang)
      @data.dig('localized', lang.to_s) || {}
    end

    def update_localized(lang, updates)
      @data['localized'] ||= {}
      @data['localized'][lang.to_s] ||= {}
      @data['localized'][lang.to_s].merge!(updates)
      mark_dirty!
      self
    end

    # Generation configuration
    def content_rules
      @data.dig('generation', 'content_rules') || {}
    end

    def main_characters
      @data.dig('generation', 'main_characters') || []
    end

    def chapter_length_target
      @data.dig('generation', 'chapter_length_target') || '1500-3000 words'
    end

    def translation_rules_for(lang)
      @data.dig('generation', 'translation_rules', lang.to_s) || {}
    end

    def generation_config
      @data['generation'] || {}
    end

    # Book status management
    def current_chapter
      @data.dig('book', 'current_chapter') || 0
    end

    def update_current_chapter(chapter_num)
      @data['book'] ||= {}
      @data['book']['current_chapter'] = chapter_num.to_i
      mark_dirty!
      self
    end

    def book_status
      @data['book'] || {}
    end

    # Convenient accessors
    def title(lang = 'en')
      localized_data(lang)['title'] || @data['title'] || 'Untitled'
    end

    def author(lang = 'en')
      localized_data(lang)['author'] || @data['author'] || 'Unknown'
    end

    def genre(lang = 'en')
      localized_data(lang)['genre'] || 'Fiction'
    end

    def humor_style(lang = 'en')
      localized_data(lang)['humor_style'] || 'narrative'
    end

    def themes(lang = 'en')
      localized_data(lang)['themes'] || {}
    end

    def primary_theme(lang = 'en')
      themes(lang)['primary']
    end

    def setting(lang = 'en')
      localized_data(lang)['setting']
    end

    def description(lang = 'en')
      localized_data(lang)['description'] || @data['description']
    end

    # Site configuration
    def site_url
      @data['site_url']
    end

    def twitter_username
      @data['twitter_username']
    end

    def github_username
      @data['github_username']
    end

    def site_domain
      @data['site_domain']
    end

    # Direct access for edge cases
    def get(key)
      @data[key.to_s]
    end

    def set(key, value)
      @data[key.to_s] = value
      mark_dirty!
      self
    end

    # Persistence
    def save!
      raise NotFoundError, 'No file path specified for save' unless @file_path

      FileUtils.mkdir_p(File.dirname(@file_path))
      File.write(@file_path, @data.to_yaml)
      @dirty = false
      self
    end

    def dirty?
      @dirty
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
      deep_dup(@data)
    end

    # Useful predicates
    def one_review_man_book?
      title.include?('One Review Man') || title.include?('Ванревьюмэн')
    end

    def language?(lang)
      localized_lang_data = @data.dig('localized', lang.to_s)
      return false unless localized_lang_data.is_a?(Hash)

      localized_lang_data.any? { |_, v| !v.to_s.strip.empty? }
    end

    def multilingual?
      (@data['localized'] || {}).keys.length > 1
    end

    # Check if localized structure exists
    def localized_structure?
      @data['localized'].is_a?(Hash)
    end

    private

    def mark_dirty!
      @dirty = true
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
      raise ValidationError, 'Data must be a Hash' unless @data.is_a?(Hash)

      raise ValidationError, 'localized must be a Hash' if @data['localized'] && !@data['localized'].is_a?(Hash)

      raise ValidationError, 'generation must be a Hash' if @data['generation'] && !@data['generation'].is_a?(Hash)

      return unless @data['book']
      raise ValidationError, 'book must be a Hash' unless @data['book'].is_a?(Hash)
    end

    def validate_required_fields!
      # For now, just ensure basic structure is present
      # Could add more specific validation rules here if needed
      # This method will raise exceptions if validation fails, otherwise returns nil
      nil
    end
  end
end
