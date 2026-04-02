# frozen_string_literal: true

require 'tmpdir'
require_relative '../lib/eidos/story_bible'
require_relative '../lib/eidos/revision_store'

RSpec.describe 'StoryBible revision integration' do
  let(:tmpdir) { Dir.mktmpdir }
  let(:revisions_path) { File.join(tmpdir, 'data', 'story_bible', 'revisions') }
  let(:store) { Eidos::RevisionStore.new(revisions_path: revisions_path) }
  let(:bible) { Eidos::StoryBible.new(project_root: tmpdir, revision_store: store) }

  before { bible.setup }
  after { FileUtils.rm_rf(tmpdir) }

  describe 'character revisions' do
    it 'records a create revision when saving a new character' do
      bible.save_character('kenji', { 'name' => 'Kenji', 'role' => 'developer' })

      revisions = store.history(entity_type: 'character', entity_id: 'kenji')
      expect(revisions.length).to eq(1)
      expect(revisions[0].operation).to eq('create')
      expect(revisions[0].snapshot['name']).to eq('Kenji')
    end

    it 'records an update revision when saving an existing character' do
      bible.save_character('kenji', { 'name' => 'Kenji', 'role' => 'junior' })
      bible.save_character('kenji', { 'name' => 'Kenji', 'role' => 'senior' },
                           change_reason: 'Promoted')

      revisions = store.history(entity_type: 'character', entity_id: 'kenji')
      expect(revisions.length).to eq(2)
      expect(revisions[1].operation).to eq('update')
      expect(revisions[1].change_reason).to eq('Promoted')
    end

    it 'supports rollback by restoring a previous snapshot' do
      bible.save_character('kenji', { 'name' => 'Kenji', 'role' => 'junior' })
      bible.save_character('kenji', { 'name' => 'Kenji', 'role' => 'senior' })

      # Get revision 1 and save it back
      rev1 = store.get(entity_type: 'character', entity_id: 'kenji', sequence: 1)
      bible.save_character('kenji', rev1.snapshot, change_reason: 'Rollback to rev 1')

      # Should now have 3 revisions, current state matches rev 1
      revisions = store.history(entity_type: 'character', entity_id: 'kenji')
      expect(revisions.length).to eq(3)

      current = bible.get_character('kenji')
      expect(current['role']).to eq('junior')
    end
  end

  describe 'location revisions' do
    it 'records revisions for location saves' do
      bible.save_location('office', { 'name' => 'Main Office', 'type' => 'workplace' })

      revisions = store.history(entity_type: 'location', entity_id: 'office')
      expect(revisions.length).to eq(1)
      expect(revisions[0].operation).to eq('create')
    end
  end

  describe 'fact revisions' do
    it 'records revisions for new facts' do
      bible.add_fact('events', 'launch', { 'name' => 'Product Launch' })

      revisions = store.history(entity_type: 'fact', entity_id: 'events/launch')
      expect(revisions.length).to eq(1)
      expect(revisions[0].operation).to eq('create')
    end
  end

  describe 'without revision store' do
    it 'still works when revision_store is nil' do
      plain_bible = Eidos::StoryBible.new(project_root: tmpdir)
      plain_bible.setup
      plain_bible.save_character('test', { 'name' => 'Test' })

      expect(plain_bible.get_character('test')['name']).to eq('Test')
    end
  end
end
