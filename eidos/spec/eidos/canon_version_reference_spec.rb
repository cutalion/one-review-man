# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'eidos/snapshot_store'
require 'eidos/canon_version_reference'

RSpec.describe Eidos::CanonVersionReference do
  let(:tmpdir) { Dir.mktmpdir('canon_version_ref_test') }
  let(:story_bible_path) { File.join(tmpdir, 'data', 'story_bible') }
  let(:store) { Eidos::SnapshotStore.new(story_bible_path: story_bible_path) }

  before do
    FileUtils.mkdir_p(File.join(story_bible_path, 'characters'))
    FileUtils.mkdir_p(File.join(story_bible_path, 'locations'))
    File.write(File.join(story_bible_path, 'facts.yml'), { 'facts' => {} }.to_yaml)
    File.write(File.join(story_bible_path, 'relationships.yml'), { 'relationships' => [] }.to_yaml)
    File.write(File.join(story_bible_path, 'plot_threads.yml'), { 'plot_threads' => [] }.to_yaml)
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe '.resolve' do
    context 'when explicit snapshot is given' do
      it 'returns versioned hash for the specified snapshot' do
        store.create(name: 'initial')
        store.create(name: 'second')

        result = described_class.resolve(snapshot_store: store, explicit_snapshot: 'initial')

        expect(result).to be_a(Hash)
        expect(result['snapshot']).to eq('initial')
        expect(result['version']).to eq(1)
        expect(result['branch']).to eq('main')
      end

      it 'raises SnapshotNotFoundError for invalid name' do
        expect do
          described_class.resolve(snapshot_store: store, explicit_snapshot: 'nonexistent')
        end.to raise_error(Eidos::SnapshotNotFoundError)
      end
    end

    context 'when no explicit snapshot is given' do
      it 'returns latest snapshot hash when snapshots exist' do
        store.create(name: 'first')
        store.create(name: 'second')

        result = described_class.resolve(snapshot_store: store)

        expect(result).to be_a(Hash)
        expect(result['snapshot']).to eq('second')
        expect(result['version']).to eq(2)
      end

      it 'returns "unversioned" when no snapshots exist' do
        result = described_class.resolve(snapshot_store: store)
        expect(result).to eq('unversioned')
      end
    end
  end
end
