# frozen_string_literal: true

# Shared examples for SnapshotStorage contract conformance.
# Include in any backend spec with:
#   it_behaves_like 'snapshot storage contract'
# The including context must define:
#   let(:snapshot_storage) { ... } — an instance of the adapter under test
#   let(:entity_storage) { ... } — a populated entity storage for snapshot creation
#
# The entity_storage should be set up with test data before these examples run.
# Call populate_entity_storage helper before snapshot tests.

RSpec.shared_examples 'snapshot storage contract' do
  # Helper to populate entity storage with test data
  def populate_test_data(es)
    es.setup
    es.save_character('kenji', { 'name' => 'Kenji Yamamoto', 'mentions' => [1, 2, 3] })
    es.save_character('emily', { 'name' => 'Emily Chen' })
    es.save_location('office', { 'name' => 'Company Office' })
    es.add_fact('world_rules', 'rule1', { 'description' => 'test rule' })
    es.add_relationship({ 'character1' => 'kenji', 'character2' => 'emily', 'type' => 'colleague' })
    es.add_plot_thread({ 'id' => 'thread1', 'title' => 'Main Plot' })
  end

  describe 'name validation' do
    before { populate_test_data(entity_storage) }

    it 'accepts valid names' do
      expect { snapshot_storage.create(name: 'initial') }.not_to raise_error
    end

    it 'rejects duplicate names' do
      snapshot_storage.create(name: 'taken')
      expect { snapshot_storage.create(name: 'taken') }.to raise_error(Eidos::DuplicateSnapshotError)
    end

    it 'rejects names with invalid characters' do
      expect { snapshot_storage.create(name: 'UPPERCASE') }.to raise_error(Eidos::InvalidSnapshotNameError)
    end

    it 'rejects names starting with a hyphen' do
      expect { snapshot_storage.create(name: '-bad') }.to raise_error(Eidos::InvalidSnapshotNameError)
    end

    it 'rejects names exceeding 64 characters' do
      expect { snapshot_storage.create(name: 'a' * 65) }.to raise_error(Eidos::InvalidSnapshotNameError)
    end
  end

  describe '#create' do
    before { populate_test_data(entity_storage) }

    it 'returns a manifest hash with required fields' do
      manifest = snapshot_storage.create(name: 'test-snapshot')

      expect(manifest['name']).to eq('test-snapshot')
      expect(manifest['version']).to be_a(Integer)
      expect(manifest['branch']).to eq('main')
      expect(manifest['created_at']).not_to be_nil
      expect(manifest['entity_counts']).to be_a(Hash)
    end

    it 'assigns monotonically increasing version numbers' do
      m1 = snapshot_storage.create(name: 'first')
      m2 = snapshot_storage.create(name: 'second')

      expect(m2['version']).to be > m1['version']
    end
  end

  describe '#list' do
    before { populate_test_data(entity_storage) }

    it 'returns empty array when no snapshots exist' do
      expect(snapshot_storage.list).to eq([])
    end

    it 'returns all snapshots ordered by version' do
      snapshot_storage.create(name: 'first')
      snapshot_storage.create(name: 'second')

      snapshots = snapshot_storage.list
      expect(snapshots.length).to eq(2)
      expect(snapshots.first['name']).to eq('first')
      expect(snapshots.last['name']).to eq('second')
    end
  end

  describe '#get' do
    before do
      populate_test_data(entity_storage)
      snapshot_storage.create(name: 'my-snapshot')
    end

    it 'finds snapshot by name' do
      result = snapshot_storage.get('my-snapshot')
      expect(result['name']).to eq('my-snapshot')
    end

    it 'finds snapshot by version number' do
      result = snapshot_storage.get(1)
      expect(result['name']).to eq('my-snapshot')
    end

    it 'returns nil for non-existent snapshot' do
      expect(snapshot_storage.get('nonexistent')).to be_nil
      expect(snapshot_storage.get(999)).to be_nil
    end
  end

  describe '#latest' do
    before { populate_test_data(entity_storage) }

    it 'returns nil when no snapshots exist' do
      expect(snapshot_storage.latest).to be_nil
    end

    it 'returns the most recent snapshot' do
      snapshot_storage.create(name: 'first')
      snapshot_storage.create(name: 'second')

      latest = snapshot_storage.latest
      expect(latest['name']).to eq('second')
    end
  end

  describe '#snapshot_data' do
    before do
      populate_test_data(entity_storage)
      snapshot_storage.create(name: 'data-test')
    end

    it 'returns full entity data as hashes' do
      data = snapshot_storage.snapshot_data('data-test')

      expect(data).to be_a(Hash)
      expect(data['characters']).to be_a(Hash)
      expect(data['characters']['kenji']['name']).to eq('Kenji Yamamoto')
      expect(data['characters']['emily']['name']).to eq('Emily Chen')
      expect(data['locations']['office']['name']).to eq('Company Office')
      expect(data['facts']).to have_key('world_rules')
      expect(data['relationships']).to be_an(Array)
      expect(data['relationships'].length).to eq(1)
      expect(data['plot_threads']).to be_an(Array)
      expect(data['plot_threads'].length).to eq(1)
    end

    it 'returns nil for non-existent snapshot' do
      expect(snapshot_storage.snapshot_data('nonexistent')).to be_nil
    end

    it 'returns immutable data (changes to live entities do not affect snapshot)' do
      # Modify live data after snapshot
      entity_storage.save_character('kenji', { 'name' => 'Modified Kenji', 'mentions' => [1, 2, 3, 4] })
      entity_storage.save_character('new-char', { 'name' => 'New Character' })

      data = snapshot_storage.snapshot_data('data-test')
      expect(data['characters']['kenji']['name']).to eq('Kenji Yamamoto')
      expect(data['characters']).not_to have_key('new-char')
    end
  end
end
