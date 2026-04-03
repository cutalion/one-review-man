# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'time'
require_relative '../revision_storage'
require_relative '../../models/revision'

module Eidos
  module Storage
    module YamlFile
      # File-based revision storage using numbered YAML files.
      # Extracted from the original RevisionStore.
      class RevisionStorage
        include Storage::RevisionStorage

        attr_reader :revisions_path

        def initialize(revisions_path:)
          @revisions_path = File.expand_path(revisions_path)
        end

        def record(entity_type:, entity_id:, snapshot:, operation:,
                   branch: 'main', change_reason: nil, changeset_id: nil)
          dir = entity_dir(entity_type, entity_id, branch)
          FileUtils.mkdir_p(dir)

          seq = next_sequence(dir)
          parent = seq > 1 ? seq - 1 : nil

          revision = Models::Revision.new(
            sequence: seq,
            entity_type: entity_type,
            entity_id: entity_id,
            snapshot: snapshot,
            timestamp: Time.now.iso8601,
            change_reason: change_reason,
            parent_seq: parent,
            operation: operation,
            branch: branch,
            changeset_id: changeset_id
          )

          path = File.join(dir, "#{format('%03d', seq)}.yml")
          File.write(path, revision.to_yaml_hash.to_yaml)

          revision
        end

        def history(entity_type:, entity_id:, branch: 'main')
          dir = entity_dir(entity_type, entity_id, branch)
          return [] unless Dir.exist?(dir)

          Dir.glob(File.join(dir, '*.yml')).sort.map do |file|
            data = YAML.safe_load(File.read(file), permitted_classes: [Date, Time])
            Models::Revision.from_yaml(data)
          end
        end

        def get(entity_type:, entity_id:, sequence:, branch: 'main')
          path = revision_path(entity_type, entity_id, sequence, branch)
          return nil unless File.exist?(path)

          data = YAML.safe_load(File.read(path), permitted_classes: [Date, Time])
          Models::Revision.from_yaml(data)
        end

        def latest(entity_type:, entity_id:, branch: 'main')
          revisions = history(entity_type: entity_type, entity_id: entity_id, branch: branch)
          revisions.last
        end

        private

        def entity_dir(entity_type, entity_id, branch)
          if branch == 'main'
            File.join(@revisions_path, entity_type.to_s, entity_id.to_s)
          else
            File.join(@revisions_path, 'branches', branch, entity_type.to_s, entity_id.to_s)
          end
        end

        def revision_path(entity_type, entity_id, sequence, branch)
          dir = entity_dir(entity_type, entity_id, branch)
          File.join(dir, "#{format('%03d', sequence)}.yml")
        end

        def next_sequence(dir)
          existing = Dir.glob(File.join(dir, '*.yml')).map do |f|
            File.basename(f, '.yml').to_i
          end
          existing.empty? ? 1 : existing.max + 1
        end
      end
    end
  end
end
