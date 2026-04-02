# frozen_string_literal: true

require 'yaml'
require 'date'
require 'fileutils'
require_relative 'snapshot_errors'

module Eidos
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

    def initialize(project_root: Dir.pwd, revision_store: nil, impact_analyzer: nil, branch_manager: nil, frozen: false)
      @project_root = File.expand_path(project_root)
      @cache = {}
      @revision_store = revision_store
      @impact_analyzer = impact_analyzer
      @branch_manager = branch_manager
      @frozen = frozen
    end

    # Load a read-only Story Bible from a named snapshot.
    # @param project_root [String] Project root path
    # @param snapshot_name [String] Snapshot name to load from
    # @param snapshot_store [SnapshotStore] Injected snapshot store
    # @return [StoryBible] Read-only instance
    def self.from_snapshot(project_root:, snapshot_name:, snapshot_store:)
      manifest = snapshot_store.get(snapshot_name)
      raise SnapshotNotFoundError, "Snapshot \"#{snapshot_name}\" not found" unless manifest

      snapshot_dir = snapshot_store.snapshot_path(snapshot_name)

      # Validate integrity
      validate_snapshot_integrity!(snapshot_dir)

      # Create a StoryBible that reads from the snapshot directory.
      # We set project_root to a synthetic path so that story_bible_path
      # resolves to the snapshot directory.
      # snapshot_dir IS the story_bible content, so we need project_root
      # such that project_root/data/story_bible == snapshot_dir
      # Instead, we create the instance and override the path.
      instance = new(project_root: project_root, frozen: true)
      instance.instance_variable_set(:@snapshot_bible_path, snapshot_dir)
      instance
    end

    def self.validate_snapshot_integrity!(snapshot_dir)
      required_dirs = %w[characters locations]
      required_files = %w[facts.yml relationships.yml plot_threads.yml]

      # Check manifest is valid YAML
      manifest_path = File.join(snapshot_dir, 'manifest.yml')
      if File.exist?(manifest_path)
        begin
          YAML.safe_load(File.read(manifest_path), permitted_classes: [Date, Time])
        rescue Psych::SyntaxError => e
          raise SnapshotCorruptError, "Snapshot manifest is malformed: #{e.message}"
        end
      end

      required_dirs.each do |dir|
        unless Dir.exist?(File.join(snapshot_dir, dir))
          raise SnapshotCorruptError, "Snapshot is missing required directory: #{dir}"
        end
      end

      required_files.each do |file|
        unless File.exist?(File.join(snapshot_dir, file))
          raise SnapshotCorruptError, "Snapshot is missing required file: #{file}"
        end
      end
    end
    private_class_method :validate_snapshot_integrity!

    # === Directory Paths ===

    def story_bible_path
      @snapshot_bible_path || File.join(@project_root, STORY_BIBLE_DIR)
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
      FileUtils.mkdir_p(revisions_dir) if @revision_store
      # Create empty files if they don't exist
      touch_yaml_file(facts_path, { 'facts' => {} })
      touch_yaml_file(relationships_path, { 'relationships' => [] })
      touch_yaml_file(plot_threads_path, { 'plot_threads' => [] })
    end

    def revisions_dir
      File.join(story_bible_path, 'revisions')
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
    # @param change_reason [String, nil] Optional reason for the change
    def save_character(id, data, change_reason: nil)
      check_frozen!
      existing = get_character(id)
      operation = existing ? 'update' : 'create'

      merged = data.merge('id' => id)
      path = File.join(characters_dir, "#{id}.yml")
      write_yaml_file(path, merged)
      invalidate_cache(:characters)

      record_revision('character', id, merged, operation, change_reason: change_reason)
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
    # @param change_reason [String, nil] Optional reason for the change
    def save_location(id, data, change_reason: nil)
      check_frozen!
      existing = get_location(id)
      operation = existing ? 'update' : 'create'

      merged = data.merge('id' => id)
      path = File.join(locations_dir, "#{id}.yml")
      write_yaml_file(path, merged)
      invalidate_cache(:locations)

      record_revision('location', id, merged, operation, change_reason: change_reason)
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
    # @param change_reason [String, nil] Optional reason for the change
    def add_fact(category, id, data, change_reason: nil)
      check_frozen!
      existing = get_facts_by_category(category)[id]
      operation = existing ? 'update' : 'create'

      all_facts = load_yaml_file(facts_path)
      all_facts['facts'] ||= {}
      all_facts['facts'][category] ||= {}
      all_facts['facts'][category][id] = data
      write_yaml_file(facts_path, all_facts)
      invalidate_cache(:facts)

      fact_id = "#{category}/#{id}"
      record_revision('fact', fact_id, data, operation, change_reason: change_reason)
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
    # @param change_reason [String, nil] Optional reason for the change
    def add_relationship(data, change_reason: nil)
      check_frozen!
      all_rels = load_yaml_file(relationships_path)
      all_rels['relationships'] ||= []
      all_rels['relationships'] << data
      write_yaml_file(relationships_path, all_rels)
      invalidate_cache(:relationships)

      rel_id = "#{data['character1']}-#{data['character2']}"
      record_revision('relationship', rel_id, data, 'create', change_reason: change_reason)
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
    # @param change_reason [String, nil] Optional reason for the change
    def add_plot_thread(data, change_reason: nil)
      check_frozen!
      merged = data.merge('status' => 'active')
      all_threads = load_yaml_file(plot_threads_path)
      all_threads['plot_threads'] ||= []
      all_threads['plot_threads'] << merged
      write_yaml_file(plot_threads_path, all_threads)
      invalidate_cache(:plot_threads)

      thread_id = data['id'] || "thread-#{all_threads['plot_threads'].length}"
      record_revision('plot_thread', thread_id, merged, 'create', change_reason: change_reason)
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

    def check_frozen!
      raise FrozenSnapshotError, 'Cannot modify a snapshot-loaded Story Bible' if @frozen
    end

    def record_revision(entity_type, entity_id, snapshot, operation, change_reason: nil)
      return unless @revision_store

      @revision_store.record(
        entity_type: entity_type,
        entity_id: entity_id,
        snapshot: snapshot,
        operation: operation,
        change_reason: change_reason
      )
    end

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
