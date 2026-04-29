# frozen_string_literal: true

require 'fileutils'
require 'yaml'

module Eidos
  # Reads and atomically advances `canon.revision` in `data/world_state.yml`.
  #
  # Feature 018a (US2). Contract:
  # `specs/018-unify-piece-producer/contracts/canon-revision-atomicity.md`.
  #
  # 018c retired the FR-006a temporary in-place migration branch: every
  # active world now has `canon.revision` written by the scaffold (post-018a)
  # or by the 018c one-shot migration (`specs/018c-orm-migration/migrate.rb`).
  # Missing `canon.revision` is now a corrupt-world signal — we raise rather
  # than retroactively synthesizing the value.
  class WorldState
    class CorruptWorldError < StandardError; end

    def initialize(world_path:)
      @world_path = File.expand_path(world_path)
      @state_path = File.join(@world_path, 'data', 'world_state.yml')
    end

    # Returns the current `canon.revision` integer. Raises
    # CorruptWorldError if `world_state.yml` is missing, `canon.revision`
    # is missing, or the value is non-integer / negative.
    def current_revision
      raise CorruptWorldError, "world_state.yml not found at #{@state_path}" unless File.exist?(@state_path)

      data = YAML.safe_load_file(@state_path) || {}
      raw = data.dig('canon', 'revision')

      if raw.nil?
        raise CorruptWorldError,
              "canon.revision missing from #{@state_path}. " \
              'Worlds scaffolded before feature 018a need an explicit migration ' \
              "(see specs/018c-orm-migration/migrate.rb)."
      end

      validated_revision(raw)
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

    def atomic_write(data)
      tmp_path = "#{@state_path}.tmp"
      File.write(tmp_path, data.to_yaml)
      File.rename(tmp_path, @state_path)
    end
  end
end
