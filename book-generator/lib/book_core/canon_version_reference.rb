# frozen_string_literal: true

require_relative 'snapshot_errors'

module BookCore
  # Builds canon_version metadata for derivative artifacts.
  # Returns a hash identifying the snapshot used, or "unversioned".
  module CanonVersionReference
    # Resolve the canon version reference for a derivative.
    # @param snapshot_store [SnapshotStore] The snapshot store to query
    # @param explicit_snapshot [String, nil] User-specified snapshot name
    # @return [Hash, String] Canon version hash or "unversioned"
    def self.resolve(snapshot_store:, explicit_snapshot: nil)
      if explicit_snapshot
        manifest = snapshot_store.get(explicit_snapshot)
        raise SnapshotNotFoundError, "Snapshot \"#{explicit_snapshot}\" not found" unless manifest

        build_reference(manifest)
      else
        manifest = snapshot_store.latest
        return 'unversioned' unless manifest

        build_reference(manifest)
      end
    end

    def self.build_reference(manifest)
      {
        'snapshot' => manifest['name'],
        'version' => manifest['version'],
        'branch' => manifest['branch']
      }
    end
    private_class_method :build_reference
  end
end
