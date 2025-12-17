# frozen_string_literal: true

require 'yaml'
require 'date'
require 'fileutils'

module BookCore
  # Unified API for reading and writing Story Bible data.
  # The Story Bible is the canonical source of truth for all story entities:
  # characters, locations, facts, relationships, and plot threads.
  #
  # Data is stored in YAML files under `data/story_bible/` with the structure:
  #   data/story_bible/
  #   ├── characters/
  #   │   ├── kenji_yamamoto.yml
  #   │   └── ...
  #   ├── locations/
  #   │   └── ...
  #   ├── facts.yml
  #   ├── relationships.yml
  #   └── plot_threads.yml
  #
  class StoryBible
    STORY_BIBLE_DIR = 'data/story_bible'

    attr_reader :project_root

    def initialize(project_root: Dir.pwd)
      @project_root = File.expand_path(project_root)
      @cache = {}
    end

    # === Directory Paths ===

    def story_bible_path
      File.join(@project_root, STORY_BIBLE_DIR)
    end

    def characters_dir
      File.join(story_bible_path, 'characters')
    end

    def locations_dir
      File.join(story_bible_path, 'locations')
    end

    # === Setup ===

    # Initialize the story bible directory structure
    def setup
      FileUtils.mkdir_p(characters_dir)
      FileUtils.mkdir_p(locations_dir)
      # Create empty files if they don't exist
      touch_yaml_file(facts_path, { 'facts' => {} })
      touch_yaml_file(relationships_path, { 'relationships' => [] })
      touch_yaml_file(plot_threads_path, { 'plot_threads' => [] })
    end

    # === Characters ===

    # Get all characters
    # @return [Hash<String, Hash>] Character ID => Character data
    def characters
      @cache[:characters] ||= load_entities_from_dir(characters_dir)
    end

    # Get a single character by ID
    # @param id [String] Character slug/ID
    # @return [Hash, nil] Character data or nil if not found
    def get_character(id)
      characters[id.to_s]
    end

    # List character IDs and names (for quick lookup)
    # @param appeared_in [Integer, nil] Filter to characters who appeared in this chapter
    # @return [Array<Hash>] List of { id:, name: }
    def list_characters(appeared_in: nil)
      chars = characters.map do |id, data|
        { 'id' => id, 'name' => data['name'] }
      end

      if appeared_in
        chars.select! do |c|
          char_data = characters[c['id']]
          mentions = char_data['mentions'] || []
          mentions.include?(appeared_in)
        end
      end

      chars
    end

    # Save a character
    # @param id [String] Character slug/ID
    # @param data [Hash] Character data
    def save_character(id, data)
      path = File.join(characters_dir, "#{id}.yml")
      write_yaml_file(path, data.merge('id' => id))
      invalidate_cache(:characters)
    end

    # === Locations ===

    # Get all locations
    # @return [Hash<String, Hash>] Location ID => Location data
    def locations
      @cache[:locations] ||= load_entities_from_dir(locations_dir)
    end

    # Get a single location by ID
    # @param id [String] Location slug/ID
    # @return [Hash, nil] Location data or nil if not found
    def get_location(id)
      locations[id.to_s]
    end

    # Save a location
    # @param id [String] Location slug/ID
    # @param data [Hash] Location data
    def save_location(id, data)
      path = File.join(locations_dir, "#{id}.yml")
      write_yaml_file(path, data.merge('id' => id))
      invalidate_cache(:locations)
    end

    # === Facts ===

    def facts_path
      File.join(story_bible_path, 'facts.yml')
    end

    # Get all facts
    # @return [Hash] Facts organized by category
    def facts
      @cache[:facts] ||= load_yaml_file(facts_path)['facts'] || {}
    end

    # Get facts by category
    # @param category [String] Category name (events, world_rules, etc.)
    # @return [Hash] Facts in that category
    def get_facts_by_category(category)
      facts[category.to_s] || {}
    end

    # Add a new fact
    # @param category [String] Category (events, world_rules, etc.)
    # @param id [String] Fact ID
    # @param data [Hash] Fact data
    def add_fact(category, id, data)
      all_facts = load_yaml_file(facts_path)
      all_facts['facts'] ||= {}
      all_facts['facts'][category] ||= {}
      all_facts['facts'][category][id] = data
      write_yaml_file(facts_path, all_facts)
      invalidate_cache(:facts)
    end

    # Search facts by keyword (case-insensitive)
    # @param query [String] Search query
    # @return [Array<Hash>] Matching facts with category and id
    def search_facts(query)
      results = []
      query_downcase = query.downcase

      facts.each do |category, category_facts|
        category_facts.each do |id, data|
          searchable = [
            data['name'],
            data['description'],
            data['rule']
          ].compact.join(' ').downcase

          if searchable.include?(query_downcase)
            results << { 'category' => category, 'id' => id, 'data' => data }
          end
        end
      end

      results
    end

    # === Relationships ===

    def relationships_path
      File.join(story_bible_path, 'relationships.yml')
    end

    # Get all relationships
    # @return [Array<Hash>] List of relationships
    def relationships
      @cache[:relationships] ||= load_yaml_file(relationships_path)['relationships'] || []
    end

    # Get relationships for a character
    # @param character_id [String] Character ID
    # @return [Array<Hash>] Relationships involving this character
    def get_relationships_for(character_id)
      relationships.select do |rel|
        rel['character1'] == character_id || rel['character2'] == character_id
      end
    end

    # Add a relationship
    # @param data [Hash] Relationship data with :character1, :character2, :type, :since
    def add_relationship(data)
      all_rels = load_yaml_file(relationships_path)
      all_rels['relationships'] ||= []
      all_rels['relationships'] << data
      write_yaml_file(relationships_path, all_rels)
      invalidate_cache(:relationships)
    end

    # === Plot Threads ===

    def plot_threads_path
      File.join(story_bible_path, 'plot_threads.yml')
    end

    # Get all plot threads
    # @return [Array<Hash>] List of plot threads
    def plot_threads
      @cache[:plot_threads] ||= load_yaml_file(plot_threads_path)['plot_threads'] || []
    end

    # Get active plot threads
    # @return [Array<Hash>] Plot threads with status 'active'
    def active_plot_threads
      plot_threads.select { |pt| pt['status'] == 'active' }
    end

    # Add a plot thread
    # @param data [Hash] Plot thread data
    def add_plot_thread(data)
      all_threads = load_yaml_file(plot_threads_path)
      all_threads['plot_threads'] ||= []
      all_threads['plot_threads'] << data.merge('status' => 'active')
      write_yaml_file(plot_threads_path, all_threads)
      invalidate_cache(:plot_threads)
    end

    # === World Rules ===

    # Convenience method to get world rules
    # @return [Hash] World rules from facts
    def world_rules
      get_facts_by_category('world_rules')
    end

    # === Chapter Context ===

    # Get condensed context for a chapter (for agent prompts)
    # @param chapter_number [Integer] Current chapter number
    # @return [Hash] Context data
    def chapter_context(chapter_number)
      {
        'characters' => list_characters,
        'locations' => locations.keys,
        'active_plot_threads' => active_plot_threads,
        'world_rules' => world_rules.values.map { |r| r['rule'] || r['description'] }.compact,
        'current_chapter' => chapter_number
      }
    end

    # === Cache Management ===

    def invalidate_cache(key = nil)
      if key
        @cache.delete(key)
      else
        @cache.clear
      end
    end

    def reload!
      invalidate_cache
    end

    private

    def load_entities_from_dir(dir)
      return {} unless Dir.exist?(dir)

      entities = {}
      Dir.glob(File.join(dir, '*.yml')).each do |file|
        data = load_yaml_file(file)
        id = data['id'] || File.basename(file, '.yml')
        entities[id] = data
      end
      entities
    end

    def load_yaml_file(path)
      return {} unless File.exist?(path)

      YAML.safe_load(File.read(path), permitted_classes: [Date, Time]) || {}
    rescue Psych::SyntaxError => e
      warn "Warning: Failed to parse #{path}: #{e.message}"
      {}
    end

    def write_yaml_file(path, data)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, data.to_yaml)
    end

    def touch_yaml_file(path, default_content = {})
      return if File.exist?(path)

      write_yaml_file(path, default_content)
    end
  end
end
