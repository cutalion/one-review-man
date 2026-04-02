# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'time'
require_relative 'models/snapshot'
require_relative 'snapshot_errors'

module Eidos
  # Manages creation, listing, and loading of canon snapshots.
  # Stores snapshots under data/story_bible/snapshots/.
  #
  # Each snapshot is a directory containing copied YAML files:
  #   snapshots/<version>-<name>/
  #   ├── manifest.yml
  #   ├── characters/
  #   ├── locations/
  #   ├── facts.yml
  #   ├── relationships.yml
  #   └── plot_threads.yml
  class SnapshotStore
    ENTITY_DIRS = %w[characters locations].freeze
    ENTITY_FILES = %w[facts.yml relationships.yml plot_threads.yml].freeze
    NAME_PATTERN = /\A[a-z0-9][a-z0-9\-]*\z/
    MAX_NAME_LENGTH = 64

    attr_reader :story_bible_path, :snapshots_path

    def initialize(story_bible_path:)
      @story_bible_path = File.expand_path(story_bible_path)
      @snapshots_path = File.join(@story_bible_path, 'snapshots')
      @index_path = File.join(@snapshots_path, '_index.yml')
    end

    # Create a new snapshot from current Story Bible state.
    # @param name [String] Human-readable name (validated)
    # @param branch [String] Branch being captured (default: "main")
    # @return [Hash] Snapshot manifest data
    def create(name:, branch: 'main')
      validate_name!(name)
      FileUtils.mkdir_p(@snapshots_path)

      index = load_index
      raise DuplicateSnapshotError, "Snapshot \"#{name}\" already exists" if index.any? { |s| s['name'] == name }

      version = next_version(index)
      dir_name = format('%03d', version) + "-#{name}"
      snapshot_dir = File.join(@snapshots_path, dir_name)

      FileUtils.mkdir_p(snapshot_dir)
      copy_canon_data(@story_bible_path, snapshot_dir)

      counts = count_entities(snapshot_dir)
      manifest = {
        'name' => name,
        'version' => version,
        'timestamp' => Time.now.iso8601,
        'branch' => branch,
        'entity_counts' => counts
      }

      write_manifest(snapshot_dir, manifest)

      index << manifest
      save_index(index)

      manifest
    end

    # List all snapshots ordered by version number.
    # @return [Array<Hash>] Array of manifest data
    def list
      load_index
    end

    # Get a specific snapshot by name or version number.
    # @param name_or_version [String, Integer] Snapshot name or version
    # @return [Hash, nil] Manifest data or nil if not found
    def get(name_or_version)
      index = load_index
      if name_or_version.is_a?(Integer) || name_or_version.to_s.match?(/\A\d+\z/)
        version = name_or_version.to_i
        index.find { |s| s['version'] == version }
      else
        index.find { |s| s['name'] == name_or_version.to_s }
      end
    end

    # Get the latest snapshot.
    # @return [Hash, nil] Manifest data or nil if no snapshots exist
    def latest
      index = load_index
      index.last
    end

    # Get the absolute path to a snapshot's data directory.
    # @param name_or_version [String, Integer] Snapshot name or version
    # @return [String, nil] Path or nil if not found
    def snapshot_path(name_or_version)
      manifest = get(name_or_version)
      return nil unless manifest

      dir_name = format('%03d', manifest['version']) + "-#{manifest['name']}"
      File.join(@snapshots_path, dir_name)
    end

    private

    def validate_name!(name)
      raise InvalidSnapshotNameError,
            "Invalid snapshot name \"#{name}\". Use lowercase alphanumeric and hyphens only." unless name.match?(NAME_PATTERN)
      raise InvalidSnapshotNameError,
            "Snapshot name \"#{name}\" exceeds maximum length of #{MAX_NAME_LENGTH} characters." if name.length > MAX_NAME_LENGTH
    end

    def load_index
      return [] unless File.exist?(@index_path)

      data = YAML.safe_load(File.read(@index_path), permitted_classes: [Date, Time]) || {}
      data['snapshots'] || []
    end

    def save_index(index)
      FileUtils.mkdir_p(@snapshots_path)
      File.write(@index_path, { 'snapshots' => index }.to_yaml)
    end

    def next_version(index)
      return 1 if index.empty?

      index.map { |s| s['version'] }.max + 1
    end

    def copy_canon_data(source, dest)
      ENTITY_DIRS.each do |dir|
        src_dir = File.join(source, dir)
        next unless Dir.exist?(src_dir)

        dest_dir = File.join(dest, dir)
        FileUtils.mkdir_p(dest_dir)
        FileUtils.cp_r(Dir.glob(File.join(src_dir, '*')), dest_dir)
      end

      ENTITY_FILES.each do |file|
        src_file = File.join(source, file)
        FileUtils.cp(src_file, File.join(dest, file)) if File.exist?(src_file)
      end
    end

    def write_manifest(snapshot_dir, manifest)
      File.write(File.join(snapshot_dir, 'manifest.yml'), manifest.to_yaml)
    end

    def count_entities(snapshot_dir)
      counts = {}

      %w[characters locations].each do |dir|
        dir_path = File.join(snapshot_dir, dir)
        counts[dir] = Dir.exist?(dir_path) ? Dir.glob(File.join(dir_path, '*.yml')).length : 0
      end

      facts_path = File.join(snapshot_dir, 'facts.yml')
      if File.exist?(facts_path)
        facts_data = YAML.safe_load(File.read(facts_path), permitted_classes: [Date, Time]) || {}
        counts['facts'] = (facts_data['facts'] || {}).keys.length
      else
        counts['facts'] = 0
      end

      rels_path = File.join(snapshot_dir, 'relationships.yml')
      if File.exist?(rels_path)
        rels_data = YAML.safe_load(File.read(rels_path), permitted_classes: [Date, Time]) || {}
        counts['relationships'] = (rels_data['relationships'] || []).length
      else
        counts['relationships'] = 0
      end

      threads_path = File.join(snapshot_dir, 'plot_threads.yml')
      if File.exist?(threads_path)
        threads_data = YAML.safe_load(File.read(threads_path), permitted_classes: [Date, Time]) || {}
        counts['plot_threads'] = (threads_data['plot_threads'] || []).length
      else
        counts['plot_threads'] = 0
      end

      counts
    end
  end
end
