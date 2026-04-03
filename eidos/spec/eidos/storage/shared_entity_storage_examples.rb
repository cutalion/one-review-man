# frozen_string_literal: true

# Shared examples for EntityStorage contract conformance.
# Include in any backend spec with:
#   it_behaves_like 'entity storage contract'
# The including context must define:
#   let(:entity_storage) { ... } — an instance of the adapter under test

RSpec.shared_examples 'entity storage contract' do
  describe 'setup' do
    it 'runs without error' do
      expect { entity_storage.setup }.not_to raise_error
    end
  end

  describe 'characters' do
    before { entity_storage.setup }

    it 'returns empty hash when no characters exist' do
      expect(entity_storage.all_characters).to eq({})
    end

    it 'saves and retrieves a character' do
      entity_storage.save_character('kenji', { 'name' => 'Kenji Yamamoto', 'role' => 'developer' })

      char = entity_storage.get_character('kenji')
      expect(char['name']).to eq('Kenji Yamamoto')
      expect(char['id']).to eq('kenji')
    end

    it 'returns nil for non-existent character' do
      expect(entity_storage.get_character('nobody')).to be_nil
    end

    it 'lists all characters with id and name' do
      entity_storage.save_character('char1', { 'name' => 'Character 1' })
      entity_storage.save_character('char2', { 'name' => 'Character 2' })

      list = entity_storage.list_characters
      expect(list.size).to eq(2)
      expect(list.map { |c| c['id'] }).to contain_exactly('char1', 'char2')
      expect(list.map { |c| c['name'] }).to contain_exactly('Character 1', 'Character 2')
    end

    it 'filters characters by appeared_in chapter' do
      entity_storage.save_character('hero', { 'name' => 'Hero', 'mentions' => [1, 2] })
      entity_storage.save_character('villain', { 'name' => 'Villain', 'mentions' => [3] })

      list = entity_storage.list_characters(appeared_in: 1)
      expect(list.size).to eq(1)
      expect(list.first['id']).to eq('hero')
    end

    it 'updates an existing character' do
      entity_storage.save_character('kenji', { 'name' => 'Original' })
      entity_storage.save_character('kenji', { 'name' => 'Updated' })

      expect(entity_storage.get_character('kenji')['name']).to eq('Updated')
    end

    it 'returns all characters keyed by id' do
      entity_storage.save_character('a', { 'name' => 'A' })
      entity_storage.save_character('b', { 'name' => 'B' })

      all = entity_storage.all_characters
      expect(all.keys).to contain_exactly('a', 'b')
      expect(all['a']['name']).to eq('A')
    end
  end

  describe 'locations' do
    before { entity_storage.setup }

    it 'returns empty hash when no locations exist' do
      expect(entity_storage.all_locations).to eq({})
    end

    it 'saves and retrieves a location' do
      entity_storage.save_location('office', { 'name' => 'Office', 'type' => 'building' })

      loc = entity_storage.get_location('office')
      expect(loc['name']).to eq('Office')
      expect(loc['id']).to eq('office')
    end

    it 'returns nil for non-existent location' do
      expect(entity_storage.get_location('nowhere')).to be_nil
    end

    it 'returns all locations keyed by id' do
      entity_storage.save_location('a', { 'name' => 'A' })
      entity_storage.save_location('b', { 'name' => 'B' })

      all = entity_storage.all_locations
      expect(all.keys).to contain_exactly('a', 'b')
    end
  end

  describe 'facts' do
    before { entity_storage.setup }

    it 'returns empty hash when no facts exist' do
      expect(entity_storage.all_facts).to eq({})
    end

    it 'adds and retrieves facts by category' do
      entity_storage.add_fact('events', 'explosion', { 'name' => 'Big Explosion', 'description' => 'Boom' })

      facts = entity_storage.get_facts_by_category('events')
      expect(facts['explosion']['name']).to eq('Big Explosion')
    end

    it 'returns empty hash for non-existent category' do
      expect(entity_storage.get_facts_by_category('nonexistent')).to eq({})
    end

    it 'searches facts case-insensitively across name, description, and rule' do
      entity_storage.add_fact('events', 'e1', { 'name' => 'Big Explosion' })
      entity_storage.add_fact('world_rules', 'r1', { 'rule' => 'Gravity is strong' })
      entity_storage.add_fact('events', 'e2', { 'description' => 'A quiet moment' })

      results = entity_storage.search_facts('explosion')
      expect(results.size).to eq(1)
      expect(results.first['id']).to eq('e1')

      results = entity_storage.search_facts('GRAVITY')
      expect(results.size).to eq(1)
      expect(results.first['id']).to eq('r1')
    end

    it 'returns empty array when search finds nothing' do
      expect(entity_storage.search_facts('nonexistent')).to eq([])
    end

    it 'returns all facts organized by category' do
      entity_storage.add_fact('events', 'e1', { 'name' => 'Event 1' })
      entity_storage.add_fact('world_rules', 'r1', { 'rule' => 'Rule 1' })

      all = entity_storage.all_facts
      expect(all.keys).to contain_exactly('events', 'world_rules')
    end
  end

  describe 'relationships' do
    before { entity_storage.setup }

    it 'returns empty array when no relationships exist' do
      expect(entity_storage.all_relationships).to eq([])
    end

    it 'adds and retrieves relationships' do
      entity_storage.add_relationship({
        'character1' => 'alice', 'character2' => 'bob', 'type' => 'friends'
      })

      rels = entity_storage.all_relationships
      expect(rels.size).to eq(1)
      expect(rels.first['type']).to eq('friends')
    end

    it 'gets relationships for a specific character' do
      entity_storage.add_relationship({ 'character1' => 'alice', 'character2' => 'bob', 'type' => 'friends' })
      entity_storage.add_relationship({ 'character1' => 'charlie', 'character2' => 'diana', 'type' => 'rivals' })

      alice_rels = entity_storage.get_relationships_for('alice')
      expect(alice_rels.size).to eq(1)
      expect(alice_rels.first['character2']).to eq('bob')
    end
  end

  describe 'plot threads' do
    before { entity_storage.setup }

    it 'returns empty array when no plot threads exist' do
      expect(entity_storage.all_plot_threads).to eq([])
    end

    it 'adds plot threads with active status' do
      entity_storage.add_plot_thread({ 'id' => 'mystery', 'description' => 'The mystery' })

      threads = entity_storage.all_plot_threads
      expect(threads.size).to eq(1)
      expect(threads.first['status']).to eq('active')
    end

    it 'filters active plot threads' do
      entity_storage.add_plot_thread({ 'id' => 'active1', 'description' => 'Active' })

      active = entity_storage.active_plot_threads
      expect(active.size).to eq(1)
      expect(active.first['id']).to eq('active1')
    end
  end
end
