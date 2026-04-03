# frozen_string_literal: true

require 'time'
require_relative '../revision_storage'
require_relative '../../models/revision'

module Eidos
  module Storage
    module Memory
      # In-memory revision storage using plain Ruby arrays and hashes.
      # Suitable for testing — fast, isolated, no filesystem I/O.
      class RevisionStorage
        include Storage::RevisionStorage

        def initialize(**_opts)
          @store = {}
        end

        def record(entity_type:, entity_id:, snapshot:, operation:,
                   branch: 'main', change_reason: nil, changeset_id: nil)
          key = storage_key(entity_type, entity_id, branch)
          @store[key] ||= []

          seq = @store[key].length + 1
          parent = seq > 1 ? seq - 1 : nil

          revision = Models::Revision.new(
            sequence: seq,
            entity_type: entity_type,
            entity_id: entity_id,
            snapshot: deep_copy(snapshot),
            timestamp: Time.now.iso8601,
            change_reason: change_reason,
            parent_seq: parent,
            operation: operation,
            branch: branch,
            changeset_id: changeset_id
          )

          @store[key] << revision
          revision
        end

        def history(entity_type:, entity_id:, branch: 'main')
          key = storage_key(entity_type, entity_id, branch)
          (@store[key] || []).map { |rev| deep_copy_revision(rev) }
        end

        def get(entity_type:, entity_id:, sequence:, branch: 'main')
          key = storage_key(entity_type, entity_id, branch)
          revisions = @store[key] || []
          rev = revisions.find { |r| r.sequence == sequence }
          rev ? deep_copy_revision(rev) : nil
        end

        def latest(entity_type:, entity_id:, branch: 'main')
          key = storage_key(entity_type, entity_id, branch)
          revisions = @store[key] || []
          rev = revisions.last
          rev ? deep_copy_revision(rev) : nil
        end

        private

        def storage_key(entity_type, entity_id, branch)
          "#{branch}/#{entity_type}/#{entity_id}"
        end

        def deep_copy(obj)
          Marshal.load(Marshal.dump(obj))
        end

        def deep_copy_revision(rev)
          Models::Revision.new(
            sequence: rev.sequence,
            entity_type: rev.entity_type,
            entity_id: rev.entity_id,
            snapshot: deep_copy(rev.snapshot),
            timestamp: rev.timestamp,
            change_reason: rev.change_reason,
            parent_seq: rev.parent_seq,
            operation: rev.operation,
            branch: rev.branch,
            changeset_id: rev.changeset_id
          )
        end
      end
    end
  end
end
