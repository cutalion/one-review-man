# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'eidos/snapshot_store'

RSpec.describe Eidos::SnapshotStore do
  let(:tmpdir) { Dir.mktmpdir('snapshot_store_test') }
  let(:story_bible_path) { File.join(tmpdir, 'data', 'story_bible') }
  let(:store) { described_class.new(story_bible_path: story_bible_path) }

  before do
    # Set up a minimal Story Bible structure
    FileUtils.mkdir_p(File.join(story_bible_path, 'characters'))
    FileUtils.mkdir_p(File.join(story_bible_path, 'locations'))

    File.write(
      File.join(story_bible_path, 'characters', 'kenji.yml'),
      { 'id' => 'kenji', 'name' => 'Kenji Yamamoto', 'mentions' => [1, 2, 3] }.to_yaml
    )
    File.write(
      File.join(story_bible_path, 'characters', 'emily.yml'),
      { 'id' => 'emily', 'name' => 'Emily Chen' }.to_yaml
    )
    File.write(
      File.join(story_bible_path, 'locations', 'office.yml'),
      { 'id' => 'office', 'name' => 'Company Office' }.to_yaml
    )
    File.write(
      File.join(story_bible_path, 'facts.yml'),
      { 'facts' => { 'world_rules' => { 'rule1' => { 'description' => 'test' } } } }.to_yaml
    )
    File.write(
      File.join(story_bible_path, 'relationships.yml'),
      { 'relationships' => [{ 'character1' => 'kenji', 'character2' => 'emily', 'type' => 'colleague' }] }.to_yaml
    )
    File.write(
      File.join(story_bible_path, 'plot_threads.yml'),
      { 'plot_threads' => [{ 'id' => 'thread1', 'status' => 'active' }] }.to_yaml
    )
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe '#initialize' do
    it 'sets story_bible_path and snapshots_path' do
      expect(store.story_bible_path).to eq(File.expand_path(story_bible_path))
      expect(store.snapshots_path).to eq(File.join(File.expand_path(story_bible_path), 'snapshots'))
    end
  end

  describe 'name validation' do
    it 'accepts valid names' do
      %w[initial after-chapter-10 v1 my-snapshot-2].each do |name|
        expect { store.create(name: name) }.not_to raise_error
      end
    end

    it 'rejects names with invalid characters' do
      %w[UPPERCASE has_underscore has.dot has\ space].each do |name|
        expect { store.create(name: name) }.to raise_error(Eidos::InvalidSnapshotNameError)
      end
    end

    it 'rejects names starting with a hyphen' do
      expect { store.create(name: '-bad') }.to raise_error(Eidos::InvalidSnapshotNameError)
    end

    it 'rejects names exceeding 64 characters' do
      long_name = 'a' * 65
      expect { store.create(name: long_name) }.to raise_error(Eidos::InvalidSnapshotNameError)
    end

    it 'accepts names exactly 64 characters long' do
      name = 'a' * 64
      expect { store.create(name: name) }.not_to raise_error
    end
  end

  describe '#create' do
    it 'creates a snapshot directory with version-name prefix' do
      store.create(name: 'initial')

      snapshot_dir = File.join(store.snapshots_path, '001-initial')
      expect(Dir.exist?(snapshot_dir)).to be true
    end

    it 'copies all entity files into snapshot directory' do
      store.create(name: 'initial')

      snapshot_dir = File.join(store.snapshots_path, '001-initial')
      expect(File.exist?(File.join(snapshot_dir, 'characters', 'kenji.yml'))).to be true
      expect(File.exist?(File.join(snapshot_dir, 'characters', 'emily.yml'))).to be true
      expect(File.exist?(File.join(snapshot_dir, 'locations', 'office.yml'))).to be true
      expect(File.exist?(File.join(snapshot_dir, 'facts.yml'))).to be true
      expect(File.exist?(File.join(snapshot_dir, 'relationships.yml'))).to be true
      expect(File.exist?(File.join(snapshot_dir, 'plot_threads.yml'))).to be true
    end

    it 'writes manifest.yml with correct entity counts' do
      result = store.create(name: 'initial')

      expect(result['entity_counts']['characters']).to eq(2)
      expect(result['entity_counts']['locations']).to eq(1)
      expect(result['entity_counts']['facts']).to eq(1)
      expect(result['entity_counts']['relationships']).to eq(1)
      expect(result['entity_counts']['plot_threads']).to eq(1)

      manifest_path = File.join(store.snapshots_path, '001-initial', 'manifest.yml')
      manifest = YAML.safe_load(File.read(manifest_path))
      expect(manifest['name']).to eq('initial')
      expect(manifest['version']).to eq(1)
      expect(manifest['branch']).to eq('main')
    end

    it 'assigns monotonically increasing version numbers' do
      r1 = store.create(name: 'first')
      r2 = store.create(name: 'second')
      r3 = store.create(name: 'third')

      expect(r1['version']).to eq(1)
      expect(r2['version']).to eq(2)
      expect(r3['version']).to eq(3)
    end

    it 'updates _index.yml with each new snapshot' do
      store.create(name: 'first')
      store.create(name: 'second')

      index = YAML.safe_load(File.read(File.join(store.snapshots_path, '_index.yml')))
      expect(index['snapshots'].length).to eq(2)
      expect(index['snapshots'][0]['name']).to eq('first')
      expect(index['snapshots'][1]['name']).to eq('second')
    end

    it 'rejects duplicate snapshot names' do
      store.create(name: 'initial')
      expect { store.create(name: 'initial') }.to raise_error(
        Eidos::DuplicateSnapshotError, /already exists/
      )
    end

    it 'records branch in manifest' do
      result = store.create(name: 'feature-snap', branch: 'what-if-kenji-quits')
      expect(result['branch']).to eq('what-if-kenji-quits')
    end

    it 'returns manifest hash with all required fields' do
      result = store.create(name: 'initial')

      expect(result).to include('name', 'version', 'timestamp', 'branch', 'entity_counts')
      expect(result['name']).to eq('initial')
      expect(result['version']).to eq(1)
      expect(result['branch']).to eq('main')
    end
  end

  describe 'snapshot immutability' do
    it 'snapshot files match original Story Bible state' do
      store.create(name: 'initial')

      snapshot_char = YAML.safe_load(
        File.read(File.join(store.snapshots_path, '001-initial', 'characters', 'kenji.yml'))
      )
      expect(snapshot_char['name']).to eq('Kenji Yamamoto')
      expect(snapshot_char['mentions']).to eq([1, 2, 3])
    end

    it 'modifying live Story Bible after snapshot does not affect snapshot data' do
      store.create(name: 'initial')

      # Modify live data
      File.write(
        File.join(story_bible_path, 'characters', 'kenji.yml'),
        { 'id' => 'kenji', 'name' => 'Kenji Yamamoto', 'mentions' => [1, 2, 3, 4] }.to_yaml
      )

      # Snapshot should still have original data
      snapshot_char = YAML.safe_load(
        File.read(File.join(store.snapshots_path, '001-initial', 'characters', 'kenji.yml'))
      )
      expect(snapshot_char['mentions']).to eq([1, 2, 3])
    end
  end

  describe '#get' do
    before do
      store.create(name: 'first')
      store.create(name: 'second')
    end

    it 'finds snapshot by name' do
      result = store.get('first')
      expect(result['name']).to eq('first')
      expect(result['version']).to eq(1)
    end

    it 'finds snapshot by version number (Integer)' do
      result = store.get(2)
      expect(result['name']).to eq('second')
    end

    it 'finds snapshot by version number (String)' do
      result = store.get('2')
      expect(result['name']).to eq('second')
    end

    it 'returns nil for non-existent name' do
      expect(store.get('nonexistent')).to be_nil
    end

    it 'returns nil for non-existent version' do
      expect(store.get(99)).to be_nil
    end
  end

  describe '#latest' do
    it 'returns the most recent snapshot' do
      store.create(name: 'first')
      store.create(name: 'second')

      result = store.latest
      expect(result['name']).to eq('second')
      expect(result['version']).to eq(2)
    end

    it 'returns nil when no snapshots exist' do
      expect(store.latest).to be_nil
    end
  end

  describe '#snapshot_path' do
    it 'returns the absolute path to a snapshot directory' do
      store.create(name: 'initial')

      path = store.snapshot_path('initial')
      expect(path).to eq(File.join(store.snapshots_path, '001-initial'))
      expect(Dir.exist?(path)).to be true
    end

    it 'returns nil for non-existent snapshot' do
      expect(store.snapshot_path('nonexistent')).to be_nil
    end
  end

  describe '#list' do
    it 'returns all snapshots ordered by version' do
      store.create(name: 'first')
      store.create(name: 'second')
      store.create(name: 'third')

      result = store.list
      expect(result.length).to eq(3)
      expect(result.map { |s| s['version'] }).to eq([1, 2, 3])
      expect(result.map { |s| s['name'] }).to eq(%w[first second third])
    end

    it 'returns empty array when no snapshots exist' do
      expect(store.list).to eq([])
    end

    it 'each entry has required metadata fields' do
      store.create(name: 'initial')

      result = store.list.first
      expect(result).to include('name', 'version', 'timestamp', 'branch', 'entity_counts')
      expect(result['entity_counts']).to include('characters', 'locations', 'facts', 'relationships', 'plot_threads')
    end
  end

  describe 'index file management' do
    it 'creates _index.yml on first snapshot' do
      index_path = File.join(store.snapshots_path, '_index.yml')
      expect(File.exist?(index_path)).to be false

      store.create(name: 'first')

      expect(File.exist?(index_path)).to be true
      data = YAML.safe_load(File.read(index_path))
      expect(data['snapshots'].length).to eq(1)
    end

    it 'returns empty list when no snapshots exist' do
      expect(store.list).to eq([])
    end
  end
end
