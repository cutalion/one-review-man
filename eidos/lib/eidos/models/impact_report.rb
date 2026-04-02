# frozen_string_literal: true

module Eidos
  module Models
    # Value object for an item affected by a canon change.
    AffectedItem = Struct.new(
      :content_type,
      :content_path,
      :references,
      :severity,
      :review_status,
      :reviewed_at,
      keyword_init: true
    ) do
      def to_yaml_hash
        h = {
          'content_type' => content_type,
          'content_path' => content_path,
          'references' => references,
          'severity' => severity,
          'review_status' => review_status || 'pending'
        }
        h['reviewed_at'] = reviewed_at.is_a?(String) ? reviewed_at : reviewed_at&.iso8601 if reviewed_at
        h
      end

      def self.from_yaml(hash)
        new(
          content_type: hash['content_type'],
          content_path: hash['content_path'],
          references: hash['references'] || [],
          severity: hash['severity'],
          review_status: hash['review_status'] || 'pending',
          reviewed_at: hash['reviewed_at']
        )
      end
    end

    # Value object for the result of analyzing a canon change against dependent content.
    ImpactReport = Struct.new(
      :id,
      :trigger,
      :created_at,
      :branch,
      :affected_items,
      :summary,
      keyword_init: true
    ) do
      def to_yaml_hash
        {
          'id' => id,
          'trigger' => trigger,
          'created_at' => created_at.is_a?(String) ? created_at : created_at&.iso8601,
          'branch' => branch || 'main',
          'affected_items' => (affected_items || []).map(&:to_yaml_hash),
          'summary' => summary
        }
      end

      def self.from_yaml(hash)
        items = (hash['affected_items'] || []).map { |h| AffectedItem.from_yaml(h) }
        new(
          id: hash['id'],
          trigger: hash['trigger'],
          created_at: hash['created_at'],
          branch: hash['branch'] || 'main',
          affected_items: items,
          summary: hash['summary'] || {}
        )
      end
    end
  end
end
