# frozen_string_literal: true

# Shared examples for RevisionStorage contract conformance.
# Include in any backend spec with:
#   it_behaves_like 'revision storage contract'
# The including context must define:
#   let(:revision_storage) { ... } — an instance of the adapter under test

RSpec.shared_examples 'revision storage contract' do
  describe '#record' do
    it 'creates a revision with sequence 1 for new entity' do
      rev = revision_storage.record(
        entity_type: 'character', entity_id: 'kenji',
        snapshot: { 'name' => 'Kenji' }, operation: 'create'
      )

      expect(rev.sequence).to eq(1)
      expect(rev.entity_type).to eq('character')
      expect(rev.entity_id).to eq('kenji')
      expect(rev.operation).to eq('create')
      expect(rev.branch).to eq('main')
      expect(rev.parent_seq).to be_nil
    end

    it 'increments sequence for subsequent revisions' do
      revision_storage.record(entity_type: 'character', entity_id: 'kenji',
                              snapshot: { 'v' => 1 }, operation: 'create')
      rev2 = revision_storage.record(entity_type: 'character', entity_id: 'kenji',
                                     snapshot: { 'v' => 2 }, operation: 'update',
                                     change_reason: 'Updated backstory')

      expect(rev2.sequence).to eq(2)
      expect(rev2.parent_seq).to eq(1)
      expect(rev2.change_reason).to eq('Updated backstory')
    end

    it 'stores revisions on a branch separately' do
      revision_storage.record(entity_type: 'character', entity_id: 'kenji',
                              snapshot: { 'v' => 1 }, operation: 'create', branch: 'main')
      rev = revision_storage.record(entity_type: 'character', entity_id: 'kenji',
                                    snapshot: { 'v' => 1 }, operation: 'create', branch: 'what-if')

      expect(rev.branch).to eq('what-if')
      expect(rev.sequence).to eq(1) # Independent sequence per branch
    end

    it 'records changeset_id when provided' do
      rev = revision_storage.record(entity_type: 'character', entity_id: 'kenji',
                                    snapshot: { 'v' => 1 }, operation: 'update',
                                    changeset_id: 'cs-001')

      expect(rev.changeset_id).to eq('cs-001')
    end

    it 'sets timestamp' do
      rev = revision_storage.record(entity_type: 'character', entity_id: 'kenji',
                                    snapshot: { 'v' => 1 }, operation: 'create')

      expect(rev.timestamp).not_to be_nil
    end
  end

  describe '#history' do
    it 'returns all revisions in chronological order' do
      revision_storage.record(entity_type: 'character', entity_id: 'kenji',
                              snapshot: { 'v' => 1 }, operation: 'create')
      revision_storage.record(entity_type: 'character', entity_id: 'kenji',
                              snapshot: { 'v' => 2 }, operation: 'update')

      revisions = revision_storage.history(entity_type: 'character', entity_id: 'kenji')
      expect(revisions.length).to eq(2)
      expect(revisions.map(&:sequence)).to eq([1, 2])
    end

    it 'returns empty array for non-existent entity' do
      expect(revision_storage.history(entity_type: 'character', entity_id: 'nobody')).to eq([])
    end

    it 'returns branch-specific history' do
      revision_storage.record(entity_type: 'character', entity_id: 'kenji',
                              snapshot: { 'v' => 1 }, operation: 'create', branch: 'main')
      revision_storage.record(entity_type: 'character', entity_id: 'kenji',
                              snapshot: { 'v' => 2 }, operation: 'create', branch: 'alt')

      main_hist = revision_storage.history(entity_type: 'character', entity_id: 'kenji', branch: 'main')
      alt_hist = revision_storage.history(entity_type: 'character', entity_id: 'kenji', branch: 'alt')

      expect(main_hist.length).to eq(1)
      expect(alt_hist.length).to eq(1)
    end
  end

  describe '#get' do
    it 'returns a specific revision by sequence' do
      revision_storage.record(entity_type: 'character', entity_id: 'kenji',
                              snapshot: { 'v' => 1 }, operation: 'create')
      revision_storage.record(entity_type: 'character', entity_id: 'kenji',
                              snapshot: { 'v' => 2 }, operation: 'update')

      rev = revision_storage.get(entity_type: 'character', entity_id: 'kenji', sequence: 1)
      expect(rev.sequence).to eq(1)
      expect(rev.snapshot['v']).to eq(1)
    end

    it 'returns nil for non-existent revision' do
      expect(revision_storage.get(entity_type: 'character', entity_id: 'kenji', sequence: 99)).to be_nil
    end
  end

  describe '#latest' do
    it 'returns the most recent revision' do
      revision_storage.record(entity_type: 'character', entity_id: 'kenji',
                              snapshot: { 'v' => 1 }, operation: 'create')
      revision_storage.record(entity_type: 'character', entity_id: 'kenji',
                              snapshot: { 'v' => 2 }, operation: 'update')

      latest = revision_storage.latest(entity_type: 'character', entity_id: 'kenji')
      expect(latest.sequence).to eq(2)
    end

    it 'returns nil for non-existent entity' do
      expect(revision_storage.latest(entity_type: 'character', entity_id: 'nobody')).to be_nil
    end
  end
end
