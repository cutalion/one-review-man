# frozen_string_literal: true

module Eidos
  module Models
    # Immutable value object representing a canon snapshot manifest.
    Snapshot = Struct.new(
      :name,
      :version,
      :timestamp,
      :branch,
      :entity_counts,
      keyword_init: true
    ) do
      def to_h
        super.compact
      end

      def to_yaml_hash
        {
          'name' => name,
          'version' => version,
          'timestamp' => timestamp.is_a?(String) ? timestamp : timestamp&.iso8601,
          'branch' => branch || 'main',
          'entity_counts' => entity_counts || {}
        }
      end

      def self.from_yaml(hash)
        new(
          name: hash['name'],
          version: hash['version'],
          timestamp: hash['timestamp'],
          branch: hash['branch'] || 'main',
          entity_counts: hash['entity_counts'] || {}
        )
      end
    end
  end
end
