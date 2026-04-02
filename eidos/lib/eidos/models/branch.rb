# frozen_string_literal: true

module Eidos
  module Models
    # Value object representing a named, independent copy of a world's canon state.
    Branch = Struct.new(
      :name,
      :display_name,
      :parent_branch,
      :created_at,
      :created_from,
      :status,
      :archived_at,
      :description,
      keyword_init: true
    ) do
      def active?
        status == 'active'
      end

      def archived?
        status == 'archived'
      end

      def deleted?
        status == 'deleted'
      end

      def to_yaml_hash
        h = {
          'name' => name,
          'parent_branch' => parent_branch,
          'created_at' => created_at.is_a?(String) ? created_at : created_at&.iso8601,
          'created_from' => created_from,
          'status' => status || 'active'
        }
        h['display_name'] = display_name if display_name
        h['archived_at'] = archived_at.is_a?(String) ? archived_at : archived_at&.iso8601 if archived_at
        h['description'] = description if description
        h
      end

      def self.from_yaml(hash)
        new(
          name: hash['name'],
          display_name: hash['display_name'],
          parent_branch: hash['parent_branch'],
          created_at: hash['created_at'],
          created_from: hash['created_from'],
          status: hash['status'] || 'active',
          archived_at: hash['archived_at'],
          description: hash['description']
        )
      end
    end
  end
end
