# frozen_string_literal: true

require 'spec_helper'
require 'book_core/story_bible'
require 'book_core/snapshot_store'
require 'book_core/snapshot_errors'
require 'tmpdir'
require 'fileutils'

RSpec.describe BookCore::StoryBible do
  let(:project_root) { Dir.mktmpdir('story_bible_test') }
  let(:story_bible) { described_class.new(project_root: project_root) }

  before do
    story_bible.setup
  end

  after do
    FileUtils.rm_rf(project_root)
  end

  describe '#setup' do
    it 'creates the story bible directory structure' do
      expect(Dir.exist?(story_bible.characters_dir)).to be true
      expect(Dir.exist?(story_bible.locations_dir)).to be true
      expect(File.exist?(story_bible.facts_path)).to be true
      expect(File.exist?(story_bible.relationships_path)).to be true
      expect(File.exist?(story_bible.plot_threads_path)).to be true
    end
  end

  describe 'character management' do
    let(:character_data) do
      {
        'name' => 'Test Character',
        'description' => 'A test character for specs',
        'personality_traits' => ['brave', 'curious'],
        'first_appearance' => 1
      }
    end

    it 'saves and retrieves a character' do
      story_bible.save_character('test_char', character_data)
      
      retrieved = story_bible.get_character('test_char')
      expect(retrieved['name']).to eq('Test Character')
      expect(retrieved['personality_traits']).to include('brave')
    end

    it 'lists all characters' do
      story_bible.save_character('char1', { 'name' => 'Character 1' })
      story_bible.save_character('char2', { 'name' => 'Character 2' })

      list = story_bible.list_characters
      expect(list.size).to eq(2)
      expect(list.map { |c| c['id'] }).to include('char1', 'char2')
    end

    it 'invalidates cache after saving' do
      story_bible.save_character('char1', { 'name' => 'Original' })
      expect(story_bible.get_character('char1')['name']).to eq('Original')

      story_bible.save_character('char1', { 'name' => 'Updated' })
      expect(story_bible.get_character('char1')['name']).to eq('Updated')
    end
  end

  describe 'location management' do
    let(:location_data) do
      {
        'name' => 'Test Location',
        'description' => 'A test location',
        'type' => 'office'
      }
    end

    it 'saves and retrieves a location' do
      story_bible.save_location('test_loc', location_data)
      
      retrieved = story_bible.get_location('test_loc')
      expect(retrieved['name']).to eq('Test Location')
      expect(retrieved['type']).to eq('office')
    end
  end

  describe 'fact management' do
    it 'adds and retrieves facts by category' do
      story_bible.add_fact('events', 'test_event', { 
        'name' => 'Test Event', 
        'description' => 'Something happened' 
      })

      facts = story_bible.get_facts_by_category('events')
      expect(facts['test_event']['name']).to eq('Test Event')
    end

    it 'searches facts by keyword' do
      story_bible.add_fact('events', 'explosion', { 
        'name' => 'Big Explosion', 
        'description' => 'A massive explosion occurred' 
      })
      story_bible.add_fact('world_rules', 'gravity', { 
        'rule' => 'Gravity is 10x normal' 
      })

      results = story_bible.search_facts('explosion')
      expect(results.size).to eq(1)
      expect(results.first['id']).to eq('explosion')
    end

    it 'searches case-insensitively' do
      story_bible.add_fact('events', 'test', { 
        'description' => 'Contains UPPERCASE text' 
      })

      results = story_bible.search_facts('uppercase')
      expect(results.size).to eq(1)
    end
  end

  describe 'relationship management' do
    it 'adds and retrieves relationships' do
      story_bible.add_relationship({
        'character1' => 'alice',
        'character2' => 'bob',
        'type' => 'friends',
        'since_chapter' => 1
      })

      rels = story_bible.relationships
      expect(rels.size).to eq(1)
      expect(rels.first['type']).to eq('friends')
    end

    it 'gets relationships for a specific character' do
      story_bible.add_relationship({
        'character1' => 'alice',
        'character2' => 'bob',
        'type' => 'friends'
      })
      story_bible.add_relationship({
        'character1' => 'charlie',
        'character2' => 'diana',
        'type' => 'rivals'
      })

      alice_rels = story_bible.get_relationships_for('alice')
      expect(alice_rels.size).to eq(1)
      expect(alice_rels.first['character2']).to eq('bob')
    end
  end

  describe 'plot thread management' do
    it 'adds plot threads with active status' do
      story_bible.add_plot_thread({
        'id' => 'mystery',
        'description' => 'The main mystery'
      })

      threads = story_bible.plot_threads
      expect(threads.size).to eq(1)
      expect(threads.first['status']).to eq('active')
    end

    it 'filters active plot threads' do
      # Add via the add method (auto-active)
      story_bible.add_plot_thread({
        'id' => 'active_thread',
        'description' => 'Active plot'
      })

      active = story_bible.active_plot_threads
      expect(active.size).to eq(1)
    end
  end

  describe '#chapter_context' do
    before do
      story_bible.save_character('hero', { 'name' => 'Hero' })
      story_bible.save_location('castle', { 'name' => 'The Castle' })
      story_bible.add_fact('world_rules', 'gravity', { 'rule' => 'Normal gravity' })
      story_bible.add_plot_thread({ 'id' => 'quest', 'description' => 'Main quest' })
    end

    it 'returns comprehensive context for a chapter' do
      ctx = story_bible.chapter_context(5)

      expect(ctx['characters']).to be_an(Array)
      expect(ctx['locations']).to include('castle')
      expect(ctx['active_plot_threads']).to be_an(Array)
      expect(ctx['world_rules']).to include('Normal gravity')
      expect(ctx['current_chapter']).to eq(5)
    end
  end

  describe '#reload!' do
    it 'clears all cached data' do
      story_bible.save_character('char1', { 'name' => 'Test' })
      story_bible.characters # Load into cache

      story_bible.reload!

      # Cache should be cleared, next access reloads from disk
      expect(story_bible.instance_variable_get(:@cache)).to be_empty
    end
  end

  describe '.from_snapshot' do
    let(:snapshot_store) { BookCore::SnapshotStore.new(story_bible_path: story_bible.story_bible_path) }

    before do
      # Populate Story Bible with some data
      story_bible.save_character('kenji', { 'name' => 'Kenji Yamamoto', 'mentions' => [1, 2, 3] })
      story_bible.save_character('emily', { 'name' => 'Emily Chen' })
      story_bible.save_location('office', { 'name' => 'Company Office' })
      story_bible.add_fact('world_rules', 'rule1', { 'description' => 'test rule' })
      story_bible.add_relationship({ 'character1' => 'kenji', 'character2' => 'emily', 'type' => 'colleague' })
      story_bible.add_plot_thread({ 'id' => 'thread1', 'title' => 'Main Plot' })

      # Create a snapshot
      snapshot_store.create(name: 'initial')

      # Modify live data after snapshot
      story_bible.save_character('kenji', { 'name' => 'Kenji Yamamoto', 'mentions' => [1, 2, 3, 4] })
      story_bible.save_character('new-char', { 'name' => 'New Character' })
    end

    it 'returns a StoryBible reading from snapshot directory' do
      loaded = described_class.from_snapshot(
        project_root: project_root,
        snapshot_name: 'initial',
        snapshot_store: snapshot_store
      )

      expect(loaded).to be_a(BookCore::StoryBible)
    end

    it 'returns snapshot data, not live data' do
      loaded = described_class.from_snapshot(
        project_root: project_root,
        snapshot_name: 'initial',
        snapshot_store: snapshot_store
      )

      # Snapshot should have original 3 mentions, not the modified 4
      kenji = loaded.get_character('kenji')
      expect(kenji['mentions']).to eq([1, 2, 3])

      # Snapshot should not have the character added after snapshot
      expect(loaded.get_character('new-char')).to be_nil
      expect(loaded.characters.keys).to contain_exactly('kenji', 'emily')
    end

    it 'loads all entity types from snapshot' do
      loaded = described_class.from_snapshot(
        project_root: project_root,
        snapshot_name: 'initial',
        snapshot_store: snapshot_store
      )

      expect(loaded.locations.keys).to include('office')
      expect(loaded.facts).to have_key('world_rules')
      expect(loaded.relationships.length).to eq(1)
      expect(loaded.plot_threads.length).to eq(1)
    end

    it 'raises SnapshotNotFoundError for unknown name' do
      expect do
        described_class.from_snapshot(
          project_root: project_root,
          snapshot_name: 'nonexistent',
          snapshot_store: snapshot_store
        )
      end.to raise_error(BookCore::SnapshotNotFoundError)
    end

    it 'raises FrozenSnapshotError on write attempts' do
      loaded = described_class.from_snapshot(
        project_root: project_root,
        snapshot_name: 'initial',
        snapshot_store: snapshot_store
      )

      expect { loaded.save_character('test', { 'name' => 'Test' }) }.to raise_error(BookCore::FrozenSnapshotError)
      expect { loaded.save_location('test', { 'name' => 'Test' }) }.to raise_error(BookCore::FrozenSnapshotError)
      expect { loaded.add_fact('cat', 'id', { 'desc' => 'x' }) }.to raise_error(BookCore::FrozenSnapshotError)
      expect { loaded.add_relationship({ 'character1' => 'a', 'character2' => 'b' }) }.to raise_error(BookCore::FrozenSnapshotError)
      expect { loaded.add_plot_thread({ 'id' => 'x' }) }.to raise_error(BookCore::FrozenSnapshotError)
    end

    it 'raises SnapshotCorruptError when snapshot data is incomplete' do
      # Create a snapshot then delete a required file
      snapshot_store.create(name: 'corrupt-test')
      snapshot_dir = snapshot_store.snapshot_path('corrupt-test')
      FileUtils.rm_rf(File.join(snapshot_dir, 'characters'))

      expect do
        described_class.from_snapshot(
          project_root: project_root,
          snapshot_name: 'corrupt-test',
          snapshot_store: snapshot_store
        )
      end.to raise_error(BookCore::SnapshotCorruptError)
    end

    it 'raises SnapshotCorruptError when manifest is malformed' do
      snapshot_store.create(name: 'bad-manifest')
      snapshot_dir = snapshot_store.snapshot_path('bad-manifest')
      File.write(File.join(snapshot_dir, 'manifest.yml'), '{{invalid yaml')

      expect do
        described_class.from_snapshot(
          project_root: project_root,
          snapshot_name: 'bad-manifest',
          snapshot_store: snapshot_store
        )
      end.to raise_error(BookCore::SnapshotCorruptError)
    end
  end
end
