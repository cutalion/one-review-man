# frozen_string_literal: true

require 'fileutils'
require 'yaml'

module Eidos
  # Reads and atomically advances `canon.revision` in `data/world_state.yml`.
  #
  # Feature 018a (US2). Contract:
  # `specs/018-unify-piece-producer/contracts/world-state-migration.md` and
  # `specs/018-unify-piece-producer/contracts/canon-revision-atomicity.md`.
  #
  # FR-006a: the in-place migration branch in #current_revision is
  # *temporary scaffolding* scheduled for retirement in/after feature 018c.
  # Once `worlds/one-review-man` is migrated explicitly, the migration code
  # path has no caller and gets deleted; the contract tightens to
  # "raise CorruptWorldError when canon.revision is missing".
  class WorldState
    class CorruptWorldError < StandardError; end

    def initialize(world_path:)
      @world_path = File.expand_path(world_path)
      @state_path = File.join(@world_path, 'data', 'world_state.yml')
      @deltas_dir = File.join(@world_path, 'data', 'canon_deltas')
    end

    # Returns the current `canon.revision` integer.
    #
    # If the field is present and well-formed, returns it.
    # If the field is absent, runs the FR-006 in-place migration:
    #   - Counts files in data/canon_deltas/ to derive the value retroactively.
    #   - Writes the field back atomically.
    #   - Logs one "Migrating ..." line to stderr.
    #   - Returns the counted value.
    # Raises CorruptWorldError if world_state.yml is missing, canon_deltas/
    # is absent on a missing-field world, or the field is non-integer/negative.
    def current_revision
      raise CorruptWorldError, "world_state.yml not found at #{@state_path}" unless File.exist?(@state_path)

      data = YAML.safe_load_file(@state_path) || {}
      raw = data.dig('canon', 'revision')

      return validated_revision(raw) unless raw.nil?

      migrate_in_place!(data)
    end

    # Atomically increments canon.revision by 1. Returns the new integer.
    #
    # Atomicity: writes to world_state.yml.tmp then File.rename, so a
    # partial-write failure (disk full, permissions) leaves the previous
    # value intact. The caller (CanonDelta#apply!) wraps this in its
    # rescue/rollback block so a raise here unwinds the bible mutation.
    def advance_revision!
      data = YAML.safe_load_file(@state_path) || {}
      current = validated_revision(data.dig('canon', 'revision'))
      new_value = current + 1

      data['canon'] ||= {}
      data['canon']['revision'] = new_value
      atomic_write(data)
      new_value
    end

    private

    def validated_revision(raw)
      unless raw.is_a?(Integer)
        raise CorruptWorldError,
              "canon.revision in #{@state_path} must be a non-negative integer, got #{raw.inspect}"
      end
      if raw.negative?
        raise CorruptWorldError,
              "canon.revision in #{@state_path} is negative (#{raw}); refusing to proceed"
      end

      raw
    end

    def migrate_in_place!(data)
      unless Dir.exist?(@deltas_dir)
        raise CorruptWorldError,
              "Cannot migrate #{@state_path}: data/canon_deltas/ directory is absent. Investigate before proceeding."
      end

      count = Dir.glob(File.join(@deltas_dir, '*.yml')).count
      data['canon'] ||= {}
      data['canon']['revision'] = count
      atomic_write(data)
      $stderr.puts "Migrating #{@state_path}: adding canon.revision = #{count}"
      count
    end

    def atomic_write(data)
      tmp_path = "#{@state_path}.tmp"
      File.write(tmp_path, data.to_yaml)
      File.rename(tmp_path, @state_path)
    end
  end
end
