# frozen_string_literal: true

require 'time'
require_relative '../snapshot_storage'
require_relative '../../snapshot_errors'

module Eidos
  module Storage
    module Memory
      # In-memory snapshot storage using plain Ruby hashes.
      # Suitable for testing — fast, isolated, no filesystem I/O.
      class SnapshotStorage
        include Storage::SnapshotStorage

        NAME_PATTERN = /\A[a-z0-9][a-z0-9\-]*\z/
        MAX_NAME_LENGTH = 64

        def initialize(entity_storage:, **_opts)
          @entity_storage = entity_storage
          @snapshots = []
        end

        def create(name:, branch: 'main')
          validate_name!(name)

          if @snapshots.any? { |s| s[:manifest]['name'] == name }
            raise DuplicateSnapshotError, "Snapshot \"#{name}\" already exists"
          end

          version = next_version

          # Capture current entity state as a deep copy
          data = {
            'characters' => deep_copy(@entity_storage.all_characters),
            'locations' => deep_copy(@entity_storage.all_locations),
            'facts' => deep_copy(@entity_storage.all_facts),
            'relationships' => deep_copy(@entity_storage.all_relationships),
            'plot_threads' => deep_copy(@entity_storage.all_plot_threads)
          }

          counts = {
            'characters' => data['characters'].size,
            'locations' => data['locations'].size,
            'facts' => data['facts'].keys.size,
            'relationships' => data['relationships'].size,
            'plot_threads' => data['plot_threads'].size
          }

          manifest = {
            'name' => name,
            'version' => version,
            'timestamp' => Time.now.iso8601,
            'created_at' => Time.now.iso8601,
            'branch' => branch,
            'entity_counts' => counts
          }

          @snapshots << { manifest: manifest, data: data }
          manifest
        end

        def list
          @snapshots.map { |s| deep_copy(s[:manifest]) }
        end

        def get(name_or_version)
          entry = find_entry(name_or_version)
          entry ? deep_copy(entry[:manifest]) : nil
        end

        def latest
          entry = @snapshots.last
          entry ? deep_copy(entry[:manifest]) : nil
        end

        def snapshot_data(name_or_version)
          entry = find_entry(name_or_version)
          entry ? deep_copy(entry[:data]) : nil
        end

        private

        def validate_name!(name)
          unless name.match?(NAME_PATTERN)
            raise InvalidSnapshotNameError,
                  "Invalid snapshot name \"#{name}\". Use lowercase alphanumeric and hyphens only."
          end
          if name.length > MAX_NAME_LENGTH
            raise InvalidSnapshotNameError,
                  "Snapshot name \"#{name}\" exceeds maximum length of #{MAX_NAME_LENGTH} characters."
          end
        end

        def find_entry(name_or_version)
          if name_or_version.is_a?(Integer) || name_or_version.to_s.match?(/\A\d+\z/)
            version = name_or_version.to_i
            @snapshots.find { |s| s[:manifest]['version'] == version }
          else
            @snapshots.find { |s| s[:manifest]['name'] == name_or_version.to_s }
          end
        end

        def next_version
          return 1 if @snapshots.empty?

          @snapshots.map { |s| s[:manifest]['version'] }.max + 1
        end

        def deep_copy(obj)
          Marshal.load(Marshal.dump(obj))
        end
      end
    end
  end
end
