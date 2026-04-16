# frozen_string_literal: true

require_relative 'revision_store'
require_relative 'snapshot_store'
require_relative 'story_bible'
require_relative 'diff_engine'
require_relative 'branch_manager'

module Eidos
  # SDK facade for canon versioning: revisions, snapshots, branches.
  class Canon
    def initialize(world_path:)
      @world_path = world_path
      @bible_path = File.join(world_path, 'data', 'story_bible')
      @revisions_path = File.join(@bible_path, 'revisions')
    end

    def history(entity_type, entity_id, branch: 'main')
      revision_store.history(entity_type: entity_type, entity_id: entity_id, branch: branch)
    end

    def diff(entity_type, entity_id, rev1, rev2, branch: 'main')
      r1 = revision_store.get(entity_type: entity_type, entity_id: entity_id, sequence: rev1, branch: branch)
      r2 = revision_store.get(entity_type: entity_type, entity_id: entity_id, sequence: rev2, branch: branch)
      return nil unless r1 && r2

      diff_engine.diff(r1.snapshot, r2.snapshot)
    end

    def snapshots
      snapshot_store.list
    end

    def create_snapshot(name)
      snapshot_store.create(name: name)
    end

    def branches
      branch_manager.list
    end

    def current_branch
      branch_manager.current_branch
    end

    def create_branch(name, from: 'main', description: nil)
      branch_manager.create(name: name, from_branch: from, description: description)
    end

    def compare_branches(branch_a, branch_b)
      branch_manager.compare(branch_a, branch_b)
    end

    def merge_branch(source, into:)
      branch_manager.merge(source: source, target: into)
    end

    private

    def revision_store
      @revision_store ||= RevisionStore.new(revisions_path: @revisions_path)
    end

    def snapshot_store
      @snapshot_store ||= SnapshotStore.new(story_bible_path: @bible_path)
    end

    def diff_engine
      @diff_engine ||= DiffEngine.new
    end

    def branch_manager
      @branch_manager ||= BranchManager.new(
        story_bible_path: @bible_path,
        revision_store: revision_store,
        diff_engine: diff_engine
      )
    end
  end
end
