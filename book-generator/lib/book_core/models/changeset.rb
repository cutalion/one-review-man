# frozen_string_literal: true

module BookCore
  module Models
    # Value object for a single operation within a changeset.
    ChangeOperation = Struct.new(
      :operation,
      :entity_type,
      :entity_id,
      :changes,
      :change_reason,
      keyword_init: true
    ) do
      def to_yaml_hash
        h = {
          'operation' => operation,
          'entity_type' => entity_type,
          'entity_id' => entity_id,
          'changes' => changes || {}
        }
        h['change_reason'] = change_reason if change_reason
        h
      end

      def self.from_yaml(hash)
        new(
          operation: hash['operation'],
          entity_type: hash['entity_type'],
          entity_id: hash['entity_id'],
          changes: hash['changes'] || {},
          change_reason: hash['change_reason']
        )
      end
    end

    # Value object for a batch of pending canon changes.
    Changeset = Struct.new(
      :id,
      :branch,
      :created_at,
      :status,
      :operations,
      :preview_report,
      :committed_at,
      keyword_init: true
    ) do
      def draft?
        status == 'draft'
      end

      def previewed?
        status == 'previewed'
      end

      def committed?
        status == 'committed'
      end

      def discarded?
        status == 'discarded'
      end

      def to_yaml_hash
        h = {
          'id' => id,
          'branch' => branch || 'main',
          'created_at' => created_at.is_a?(String) ? created_at : created_at&.iso8601,
          'status' => status || 'draft',
          'operations' => (operations || []).map(&:to_yaml_hash)
        }
        h['preview_report'] = preview_report if preview_report
        h['committed_at'] = committed_at.is_a?(String) ? committed_at : committed_at&.iso8601 if committed_at
        h
      end

      def self.from_yaml(hash)
        ops = (hash['operations'] || []).map { |h| ChangeOperation.from_yaml(h) }
        new(
          id: hash['id'],
          branch: hash['branch'] || 'main',
          created_at: hash['created_at'],
          status: hash['status'] || 'draft',
          operations: ops,
          preview_report: hash['preview_report'],
          committed_at: hash['committed_at']
        )
      end
    end
  end
end
