# frozen_string_literal: true

require 'tmpdir'
require_relative '../lib/book_core/changeset_manager'
require_relative '../lib/book_core/revision_store'
require_relative '../lib/book_core/story_bible'

RSpec.describe BookCore::ChangesetManager do
  let(:tmpdir) { Dir.mktmpdir }
  let(:changesets_path) { File.join(tmpdir, 'data', 'changesets') }
  let(:revisions_path) { File.join(tmpdir, 'data', 'story_bible', 'revisions') }
  let(:store) { BookCore::RevisionStore.new(revisions_path: revisions_path) }
  let(:bible) { BookCore::StoryBible.new(project_root: tmpdir, revision_store: store) }
  let(:manager) do
    described_class.new(
      changesets_path: changesets_path,
      story_bible: bible,
      revision_store: store
    )
  end

  before { bible.setup }
  after { FileUtils.rm_rf(tmpdir) }

  describe '#create' do
    it 'creates a new changeset in draft status' do
      cs = manager.create
      expect(cs.status).to eq('draft')
      expect(cs.branch).to eq('main')
      expect(cs.operations).to be_empty
    end

    it 'raises when an active changeset already exists' do
      manager.create
      expect { manager.create }.to raise_error(/already exists/)
    end
  end

  describe '#active' do
    it 'returns nil when no active changeset' do
      expect(manager.active).to be_nil
    end

    it 'returns the active changeset' do
      cs = manager.create
      active = manager.active
      expect(active.id).to eq(cs.id)
    end

    it 'does not return committed changesets' do
      cs = manager.create
      manager.add_operation(
        changeset_id: cs.id, operation: 'create',
        entity_type: 'character', entity_id: 'test',
        changes: { 'name' => 'Test' }
      )
      manager.commit(changeset_id: cs.id)
      expect(manager.active).to be_nil
    end
  end

  describe '#add_operation' do
    it 'adds an operation to the changeset' do
      cs = manager.create
      updated = manager.add_operation(
        changeset_id: cs.id, operation: 'update',
        entity_type: 'character', entity_id: 'kenji',
        changes: { 'role' => 'senior' },
        change_reason: 'Promotion'
      )

      expect(updated.operations.length).to eq(1)
      expect(updated.operations[0].operation).to eq('update')
      expect(updated.operations[0].entity_id).to eq('kenji')
    end

    it 'resets previewed status to draft when modified' do
      cs = manager.create
      manager.add_operation(
        changeset_id: cs.id, operation: 'create',
        entity_type: 'character', entity_id: 'test',
        changes: { 'name' => 'Test' }
      )
      manager.preview(changeset_id: cs.id)
      manager.add_operation(
        changeset_id: cs.id, operation: 'create',
        entity_type: 'character', entity_id: 'test2',
        changes: { 'name' => 'Test2' }
      )

      reloaded = manager.load_changeset(cs.id)
      expect(reloaded.status).to eq('draft')
    end
  end

  describe '#preview' do
    it 'sets status to previewed' do
      cs = manager.create
      manager.add_operation(
        changeset_id: cs.id, operation: 'create',
        entity_type: 'character', entity_id: 'test',
        changes: { 'name' => 'Test' }
      )

      result = manager.preview(changeset_id: cs.id)
      expect(result[:report]['operations_count']).to eq(1)
      expect(result[:conflicts]).to be_empty

      reloaded = manager.load_changeset(cs.id)
      expect(reloaded.status).to eq('previewed')
    end

    it 'detects intra-batch conflicts (delete + update same entity)' do
      cs = manager.create
      manager.add_operation(
        changeset_id: cs.id, operation: 'delete',
        entity_type: 'character', entity_id: 'kenji'
      )
      manager.add_operation(
        changeset_id: cs.id, operation: 'update',
        entity_type: 'character', entity_id: 'kenji',
        changes: { 'role' => 'senior' }
      )

      result = manager.preview(changeset_id: cs.id)
      expect(result[:conflicts].length).to eq(1)
    end
  end

  describe '#commit' do
    it 'applies all operations and creates revisions' do
      cs = manager.create
      manager.add_operation(
        changeset_id: cs.id, operation: 'create',
        entity_type: 'character', entity_id: 'new_char',
        changes: { 'name' => 'New Character', 'role' => 'sidekick' }
      )
      manager.add_operation(
        changeset_id: cs.id, operation: 'create',
        entity_type: 'character', entity_id: 'another',
        changes: { 'name' => 'Another' }
      )

      revisions = manager.commit(changeset_id: cs.id, reason: 'Batch creation')
      expect(revisions.length).to eq(2)
      expect(revisions[0].changeset_id).to eq(cs.id)

      reloaded = manager.load_changeset(cs.id)
      expect(reloaded.status).to eq('committed')
    end

    it 'raises on intra-batch conflicts' do
      cs = manager.create
      manager.add_operation(
        changeset_id: cs.id, operation: 'delete',
        entity_type: 'character', entity_id: 'kenji'
      )
      manager.add_operation(
        changeset_id: cs.id, operation: 'update',
        entity_type: 'character', entity_id: 'kenji',
        changes: { 'role' => 'senior' }
      )

      expect { manager.commit(changeset_id: cs.id) }
        .to raise_error(BookCore::ChangesetManager::ChangesetConflictError)
    end

    it 'rolls back applied operations when a later operation fails' do
      cs = manager.create
      manager.add_operation(
        changeset_id: cs.id, operation: 'create',
        entity_type: 'character', entity_id: 'first_char',
        changes: { 'name' => 'First' }
      )
      manager.add_operation(
        changeset_id: cs.id, operation: 'create',
        entity_type: 'character', entity_id: 'second_char',
        changes: { 'name' => 'Second' }
      )

      # Stub apply_operation to succeed once then fail
      call_count = 0
      allow(manager).to receive(:apply_operation).and_wrap_original do |m, *args|
        call_count += 1
        raise 'simulated failure' if call_count == 2

        m.call(*args)
      end

      expect { manager.commit(changeset_id: cs.id) }.to raise_error('simulated failure')

      # Changeset should be reset to draft, not committed
      reloaded = manager.load_changeset(cs.id)
      expect(reloaded.status).to eq('draft')

      # The first character should have been rolled back
      char = bible.get_character('first_char')
      expect(char).to be_nil
    end
  end

  describe '#discard' do
    it 'marks the changeset as discarded' do
      cs = manager.create
      manager.discard(changeset_id: cs.id)

      reloaded = manager.load_changeset(cs.id)
      expect(reloaded.status).to eq('discarded')
      expect(manager.active).to be_nil
    end
  end
end
