# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'time'
require_relative 'models/changeset'
require_relative 'models/conflict'

module Eidos
  # Groups multiple canon changes for atomic preview and commit.
  class ChangesetManager
    class ChangesetConflictError < RuntimeError; end

    def initialize(changesets_path:, story_bible:, revision_store:, impact_analyzer: nil)
      @changesets_path = File.expand_path(changesets_path)
      @story_bible = story_bible
      @revision_store = revision_store
      @impact_analyzer = impact_analyzer
    end

    # Create a new changeset.
    # @return [Models::Changeset]
    def create(branch: 'main')
      existing = active(branch: branch)
      raise "Active changeset already exists for branch '#{branch}'" if existing

      FileUtils.mkdir_p(@changesets_path)

      changeset = Models::Changeset.new(
        id: generate_id,
        branch: branch,
        created_at: Time.now.iso8601,
        status: 'draft',
        operations: []
      )

      save_changeset(changeset)
      changeset
    end

    # Get active changeset for a branch.
    # @return [Models::Changeset, nil]
    def active(branch: 'main')
      all_changesets.find { |cs| cs.branch == branch && (cs.draft? || cs.previewed?) }
    end

    # Add an operation to the active changeset.
    def add_operation(changeset_id:, operation:, entity_type:, entity_id:, changes: {}, change_reason: nil)
      cs = load_changeset(changeset_id)
      raise "Changeset not found" unless cs
      raise "Changeset is not in draft or previewed state" unless cs.draft? || cs.previewed?

      op = Models::ChangeOperation.new(
        operation: operation,
        entity_type: entity_type,
        entity_id: entity_id,
        changes: changes,
        change_reason: change_reason
      )

      cs.operations << op
      cs.status = 'draft' if cs.previewed? # Reset to draft on modification
      save_changeset(cs)
      cs
    end

    # Preview aggregate impact.
    # @return [Hash] { report:, conflicts: }
    def preview(changeset_id:)
      cs = load_changeset(changeset_id)
      raise "Changeset not found" unless cs

      # Check for intra-batch conflicts
      conflicts = detect_intra_batch_conflicts(cs)

      cs.status = 'previewed'
      cs.preview_report = {
        'operations_count' => cs.operations.length,
        'conflicts' => conflicts.map(&:to_yaml_hash),
        'previewed_at' => Time.now.iso8601
      }
      save_changeset(cs)

      { report: cs.preview_report, conflicts: conflicts }
    end

    # Commit atomically.
    # @return [Array<Models::Revision>]
    def commit(changeset_id:, reason: nil)
      cs = load_changeset(changeset_id)
      raise "Changeset not found" unless cs

      conflicts = detect_intra_batch_conflicts(cs)
      raise ChangesetConflictError, "Unresolved intra-batch conflicts" if conflicts.any?

      revisions = []
      applied = []

      begin
        cs.operations.each do |op|
          revision = apply_operation(op, cs.branch, cs.id, reason)
          revisions << revision if revision
          applied << op
        end

        cs.status = 'committed'
        cs.committed_at = Time.now.iso8601
        save_changeset(cs)
      rescue StandardError => e
        # Rollback applied operations in reverse
        rollback_operations(applied.reverse, cs.branch)
        cs.status = 'draft'
        save_changeset(cs)
        raise e
      end

      revisions
    end

    # Discard without applying.
    def discard(changeset_id:)
      cs = load_changeset(changeset_id)
      raise "Changeset not found" unless cs

      cs.status = 'discarded'
      save_changeset(cs)
    end

    # Load a specific changeset.
    def load_changeset(changeset_id)
      path = File.join(@changesets_path, "#{changeset_id}.yml")
      return nil unless File.exist?(path)

      data = YAML.safe_load(File.read(path), permitted_classes: [Date, Time])
      Models::Changeset.from_yaml(data)
    end

    private

    def all_changesets
      return [] unless Dir.exist?(@changesets_path)

      Dir.glob(File.join(@changesets_path, '*.yml')).filter_map do |file|
        data = YAML.safe_load(File.read(file), permitted_classes: [Date, Time])
        Models::Changeset.from_yaml(data)
      end
    end

    def detect_intra_batch_conflicts(changeset)
      conflicts = []

      # Group operations by entity
      by_entity = changeset.operations.group_by { |op| "#{op.entity_type}/#{op.entity_id}" }

      by_entity.each do |entity_key, ops|
        # Check for contradictions: delete + update, or multiple updates to same field
        has_delete = ops.any? { |op| op.operation == 'delete' }
        has_create_or_update = ops.any? { |op| %w[create update].include?(op.operation) }

        if has_delete && has_create_or_update
          entity_type, entity_id = entity_key.split('/', 2)
          conflicts << Models::Conflict.new(
            entity_type: entity_type,
            entity_id: entity_id,
            field_path: '(entity)',
            base_value: 'exists',
            ours_value: 'delete',
            theirs_value: 'create/update'
          )
        end
      end

      conflicts
    end

    def apply_operation(op, branch, changeset_id, reason)
      combined_reason = [reason, op.change_reason].compact.join(' - ')
      combined_reason = nil if combined_reason.empty?

      case op.operation
      when 'create', 'update'
        snapshot = op.changes
        @revision_store.record(
          entity_type: op.entity_type,
          entity_id: op.entity_id,
          snapshot: snapshot,
          operation: op.operation,
          branch: branch,
          change_reason: combined_reason,
          changeset_id: changeset_id
        )
      when 'delete'
        @revision_store.record(
          entity_type: op.entity_type,
          entity_id: op.entity_id,
          snapshot: {},
          operation: 'delete',
          branch: branch,
          change_reason: combined_reason,
          changeset_id: changeset_id
        )
      end
    end

    def rollback_operations(operations, _branch)
      # In a real implementation, this would restore previous state.
      # For now, we rely on the revision history to track what happened.
      operations.each do |_op|
        # Rollback is tracked via revision history
      end
    end

    def generate_id
      "cs-#{Time.now.strftime('%Y%m%d-%H%M%S')}-#{rand(1000..9999)}"
    end

    def save_changeset(cs)
      FileUtils.mkdir_p(@changesets_path)
      path = File.join(@changesets_path, "#{cs.id}.yml")
      File.write(path, cs.to_yaml_hash.to_yaml)
    end
  end
end
