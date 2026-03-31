# frozen_string_literal: true

module BookCore
  module Models
    # Value object for a field-level inconsistency detected during merge or batch preview.
    Conflict = Struct.new(
      :entity_type,
      :entity_id,
      :field_path,
      :base_value,
      :ours_value,
      :theirs_value,
      :resolution,
      :custom_value,
      keyword_init: true
    ) do
      def resolved?
        !resolution.nil?
      end

      def resolved_value
        case resolution
        when 'keep_ours' then ours_value
        when 'keep_theirs' then theirs_value
        when 'custom' then custom_value
        end
      end

      def to_yaml_hash
        h = {
          'entity_type' => entity_type,
          'entity_id' => entity_id,
          'field_path' => field_path,
          'base_value' => base_value,
          'ours_value' => ours_value,
          'theirs_value' => theirs_value
        }
        h['resolution'] = resolution if resolution
        h['custom_value'] = custom_value if custom_value
        h
      end

      def self.from_yaml(hash)
        new(
          entity_type: hash['entity_type'],
          entity_id: hash['entity_id'],
          field_path: hash['field_path'],
          base_value: hash['base_value'],
          ours_value: hash['ours_value'],
          theirs_value: hash['theirs_value'],
          resolution: hash['resolution'],
          custom_value: hash['custom_value']
        )
      end
    end
  end
end
