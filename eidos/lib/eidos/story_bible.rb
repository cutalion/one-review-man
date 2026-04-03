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

    def initialize(project_root: Dir.pwd, revision_store: nil, impact_analyzer: nil, branch_manager: nil, frozen: false,
                   entity_storage: nil)
      @project_root = File.expand_path(project_root)
      @cache = {}
      @revision_store = revision_store
      @impact_analyzer = impact_analyzer
      @branch_manager = branch_manager
      @frozen = frozen
      @entity_storage = entity_storage
    end

    # Returns the entity storage adapter, lazily building a YamlFile one if not injected.
    def entity_storage
      @entity_storage ||= begin
        require_relative 'storage/yaml_file/entity_storage'
        Storage::YamlFile::EntityStorage.new(project_root: @project_root)
      end
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

      # Create a read-only StoryBible backed by a YamlFile adapter pointing at snapshot dir
      require_relative 'storage/yaml_file/entity_storage'
      snapshot_entity_storage = Storage::YamlFile::EntityStorage.new(story_bible_path: snapshot_dir)
      instance = new(project_root: project_root, frozen: true, entity_storage: snapshot_entity_storage)
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
      @snapshot_bible_path || entity_storage.story_bible_path
    end

    def characters_dir
      entity_storage.characters_dir
    end

    def locations_dir
      entity_storage.locations_dir
    end

    # === Setup ===

    # Initialize the story bible directory structure
    def setup
      entity_storage.setup
      FileUtils.mkdir_p(revisions_dir) if @revision_store
    end

    def revisions_dir
      File.join(story_bible_path, 'revisions')
    end

    # === Characters ===

    # Get all characters
    # @return [Hash<String, Hash>] Character ID => Character data
    def characters
      @cache[:characters] ||= entity_storage.all_characters
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
      entity_storage.save_character(id, data)
      invalidate_cache(:characters)

      record_revision('character', id, merged, operation, change_reason: change_reason)
    end

    # === Locations ===

    # Get all locations
    # @return [Hash<String, Hash>] Location ID => Location data
    def locations
      @cache[:locations] ||= entity_storage.all_locations
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
      entity_storage.save_location(id, data)
      invalidate_cache(:locations)

      record_revision('location', id, merged, operation, change_reason: change_reason)
    end

    # === Facts ===

    def facts_path
      entity_storage.facts_path
    end

    # Get all facts
    # @return [Hash] Facts organized by category
    def facts
      @cache[:facts] ||= entity_storage.all_facts
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

      entity_storage.add_fact(category, id, data)
      invalidate_cache(:facts)

      fact_id = "#{category}/#{id}"
      record_revision('fact', fact_id, data, operation, change_reason: change_reason)
    end

    # Search facts by keyword (case-insensitive)
    # @param query [String] Search query
    # @return [Array<Hash>] Matching facts with category and id
    def search_facts(query)
      entity_storage.search_facts(query)
    end

    # === Relationships ===

    def relationships_path
      entity_storage.relationships_path
    end

    # Get all relationships
    # @return [Array<Hash>] List of relationships
    def relationships
      @cache[:relationships] ||= entity_storage.all_relationships
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
      entity_storage.add_relationship(data)
      invalidate_cache(:relationships)

      rel_id = "#{data['character1']}-#{data['character2']}"
      record_revision('relationship', rel_id, data, 'create', change_reason: change_reason)
    end

    # === Plot Threads ===

    def plot_threads_path
      entity_storage.plot_threads_path
    end

    # Get all plot threads
    # @return [Array<Hash>] List of plot threads
    def plot_threads
      @cache[:plot_threads] ||= entity_storage.all_plot_threads
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
      entity_storage.add_plot_thread(data)
      invalidate_cache(:plot_threads)

      thread_id = data['id'] || "thread-#{plot_threads.length}"
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

    def load_yaml_file(path)
      return {} unless File.exist?(path)

      YAML.safe_load(File.read(path), permitted_classes: [Date, Time]) || {}
    rescue Psych::SyntaxError => e
      warn "Warning: Failed to parse #{path}: #{e.message}"
      {}
    end
  end
end
