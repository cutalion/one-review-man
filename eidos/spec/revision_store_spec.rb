# frozen_string_literal: true

require 'tmpdir'
require_relative '../lib/eidos/revision_store'

RSpec.describe Eidos::RevisionStore do
  let(:tmpdir) { Dir.mktmpdir }
  let(:store) { described_class.new(revisions_path: tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  describe '#record' do
    it 'creates a revision file with sequence 1 for new entity' do
      rev = store.record(
        entity_type: 'character',
        entity_id: 'kenji',
        snapshot: { 'name' => 'Kenji', 'role' => 'developer' },
        operation: 'create'
      )

      expect(rev.sequence).to eq(1)
      expect(rev.entity_type).to eq('character')
      expect(rev.entity_id).to eq('kenji')
      expect(rev.operation).to eq('create')
      expect(rev.branch).to eq('main')
      expect(rev.parent_seq).to be_nil

      path = File.join(tmpdir, 'character', 'kenji', '001.yml')
      expect(File.exist?(path)).to be true
    end

    it 'increments sequence for subsequent revisions' do
      store.record(entity_type: 'character', entity_id: 'kenji',
                   snapshot: { 'v' => 1 }, operation: 'create')
      rev2 = store.record(entity_type: 'character', entity_id: 'kenji',
                          snapshot: { 'v' => 2 }, operation: 'update',
                          change_reason: 'Updated backstory')

      expect(rev2.sequence).to eq(2)
      expect(rev2.parent_seq).to eq(1)
      expect(rev2.change_reason).to eq('Updated backstory')
    end

    it 'stores revisions on a branch in a separate directory' do
      rev = store.record(entity_type: 'character', entity_id: 'kenji',
                         snapshot: { 'v' => 1 }, operation: 'create',
                         branch: 'what-if')

      expect(rev.branch).to eq('what-if')
      path = File.join(tmpdir, 'branches', 'what-if', 'character', 'kenji', '001.yml')
      expect(File.exist?(path)).to be true
    end

    it 'records changeset_id when provided' do
      rev = store.record(entity_type: 'character', entity_id: 'kenji',
                         snapshot: { 'v' => 1 }, operation: 'update',
                         changeset_id: 'cs-001')

      expect(rev.changeset_id).to eq('cs-001')
    end
  end

  describe '#history' do
    it 'returns all revisions in chronological order' do
      store.record(entity_type: 'character', entity_id: 'kenji',
                   snapshot: { 'v' => 1 }, operation: 'create')
      store.record(entity_type: 'character', entity_id: 'kenji',
                   snapshot: { 'v' => 2 }, operation: 'update')
      store.record(entity_type: 'character', entity_id: 'kenji',
                   snapshot: { 'v' => 3 }, operation: 'update')

      revisions = store.history(entity_type: 'character', entity_id: 'kenji')
      expect(revisions.length).to eq(3)
      expect(revisions.map(&:sequence)).to eq([1, 2, 3])
    end

    it 'returns empty array for non-existent entity' do
      revisions = store.history(entity_type: 'character', entity_id: 'nobody')
      expect(revisions).to eq([])
    end

    it 'returns branch-specific history' do
      store.record(entity_type: 'character', entity_id: 'kenji',
                   snapshot: { 'v' => 1 }, operation: 'create', branch: 'main')
      store.record(entity_type: 'character', entity_id: 'kenji',
                   snapshot: { 'v' => 2 }, operation: 'create', branch: 'alt')

      main_hist = store.history(entity_type: 'character', entity_id: 'kenji', branch: 'main')
      alt_hist = store.history(entity_type: 'character', entity_id: 'kenji', branch: 'alt')

      expect(main_hist.length).to eq(1)
      expect(alt_hist.length).to eq(1)
    end
  end

  describe '#get' do
    it 'returns a specific revision by sequence' do
      store.record(entity_type: 'character', entity_id: 'kenji',
                   snapshot: { 'v' => 1 }, operation: 'create')
      store.record(entity_type: 'character', entity_id: 'kenji',
                   snapshot: { 'v' => 2 }, operation: 'update')

      rev = store.get(entity_type: 'character', entity_id: 'kenji', sequence: 1)
      expect(rev.sequence).to eq(1)
      expect(rev.snapshot['v']).to eq(1)
    end

    it 'returns nil for non-existent revision' do
      rev = store.get(entity_type: 'character', entity_id: 'kenji', sequence: 99)
      expect(rev).to be_nil
    end
  end

  describe '#latest' do
    it 'returns the most recent revision' do
      store.record(entity_type: 'character', entity_id: 'kenji',
                   snapshot: { 'v' => 1 }, operation: 'create')
      store.record(entity_type: 'character', entity_id: 'kenji',
                   snapshot: { 'v' => 2 }, operation: 'update')

      latest = store.latest(entity_type: 'character', entity_id: 'kenji')
      expect(latest.sequence).to eq(2)
      expect(latest.snapshot['v']).to eq(2)
    end

    it 'returns nil for non-existent entity' do
      latest = store.latest(entity_type: 'character', entity_id: 'nobody')
      expect(latest).to be_nil
    end
  end
end
