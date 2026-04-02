# frozen_string_literal: true

module Eidos
  module Models
    # Immutable value object representing a versioned snapshot of a canon entry.
    Revision = Struct.new(
      :sequence,
      :entity_type,
      :entity_id,
      :snapshot,
      :timestamp,
      :change_reason,
      :parent_seq,
      :operation,
      :branch,
      :changeset_id,
      keyword_init: true
    ) do
      def to_h
        super.compact
      end

      def to_yaml_hash
        h = {
          'sequence' => sequence,
          'entity_type' => entity_type,
          'entity_id' => entity_id,
          'snapshot' => snapshot,
          'timestamp' => timestamp.is_a?(String) ? timestamp : timestamp&.iso8601,
          'operation' => operation,
          'branch' => branch || 'main'
        }
        h['change_reason'] = change_reason if change_reason
        h['parent_seq'] = parent_seq if parent_seq
        h['changeset_id'] = changeset_id if changeset_id
        h
      end

      def self.from_yaml(hash)
        new(
          sequence: hash['sequence'],
          entity_type: hash['entity_type'],
          entity_id: hash['entity_id'],
          snapshot: hash['snapshot'],
          timestamp: hash['timestamp'],
          change_reason: hash['change_reason'],
          parent_seq: hash['parent_seq'],
          operation: hash['operation'],
          branch: hash['branch'] || 'main',
          changeset_id: hash['changeset_id']
        )
      end
    end
  end
end
