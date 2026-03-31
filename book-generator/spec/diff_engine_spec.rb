# frozen_string_literal: true

require_relative '../lib/book_core/diff_engine'

RSpec.describe BookCore::DiffEngine do
  subject(:engine) { described_class.new }

  describe '#diff' do
    it 'returns empty hash for identical snapshots' do
      snap = { 'name' => 'Kenji', 'role' => 'developer' }
      expect(engine.diff(snap, snap)).to eq({})
    end

    it 'detects added fields' do
      a = { 'name' => 'Kenji' }
      b = { 'name' => 'Kenji', 'role' => 'developer' }
      result = engine.diff(a, b)
      expect(result).to eq({ 'role' => { old: nil, new: 'developer' } })
    end

    it 'detects removed fields' do
      a = { 'name' => 'Kenji', 'role' => 'developer' }
      b = { 'name' => 'Kenji' }
      result = engine.diff(a, b)
      expect(result).to eq({ 'role' => { old: 'developer', new: nil } })
    end

    it 'detects changed fields' do
      a = { 'name' => 'Kenji', 'role' => 'junior' }
      b = { 'name' => 'Kenji', 'role' => 'senior' }
      result = engine.diff(a, b)
      expect(result).to eq({ 'role' => { old: 'junior', new: 'senior' } })
    end

    it 'handles nested hashes with dot-notation paths' do
      a = { 'appearance' => { 'hair' => 'black', 'eyes' => 'brown' } }
      b = { 'appearance' => { 'hair' => 'gray', 'eyes' => 'brown' } }
      result = engine.diff(a, b)
      expect(result).to eq({ 'appearance.hair' => { old: 'black', new: 'gray' } })
    end

    it 'handles deeply nested changes' do
      a = { 'stats' => { 'skills' => { 'ruby' => 'expert' } } }
      b = { 'stats' => { 'skills' => { 'ruby' => 'legend' } } }
      result = engine.diff(a, b)
      expect(result).to eq({ 'stats.skills.ruby' => { old: 'expert', new: 'legend' } })
    end

    it 'handles nil snapshots' do
      expect(engine.diff(nil, { 'name' => 'Kenji' })).to eq({ 'name' => { old: nil, new: 'Kenji' } })
      expect(engine.diff({ 'name' => 'Kenji' }, nil)).to eq({ 'name' => { old: 'Kenji', new: nil } })
    end
  end

  describe '#find_conflicts' do
    it 'returns no conflicts when changes are to different fields' do
      base = { 'name' => 'Kenji', 'role' => 'developer', 'backstory' => 'original' }
      ours = { 'name' => 'Kenji', 'role' => 'senior', 'backstory' => 'original' }
      theirs = { 'name' => 'Kenji', 'role' => 'developer', 'backstory' => 'updated' }

      conflicts = engine.find_conflicts(base: base, ours: ours, theirs: theirs)
      expect(conflicts).to be_empty
    end

    it 'detects conflict when both change the same field differently' do
      base = { 'backstory' => 'original' }
      ours = { 'backstory' => 'ours version' }
      theirs = { 'backstory' => 'theirs version' }

      conflicts = engine.find_conflicts(base: base, ours: ours, theirs: theirs)
      expect(conflicts.length).to eq(1)
      expect(conflicts[0].field_path).to eq('backstory')
      expect(conflicts[0].base_value).to eq('original')
      expect(conflicts[0].ours_value).to eq('ours version')
      expect(conflicts[0].theirs_value).to eq('theirs version')
    end

    it 'no conflict when both change the same field to the same value' do
      base = { 'role' => 'junior' }
      ours = { 'role' => 'senior' }
      theirs = { 'role' => 'senior' }

      conflicts = engine.find_conflicts(base: base, ours: ours, theirs: theirs)
      expect(conflicts).to be_empty
    end

    it 'detects nested field conflicts' do
      base = { 'appearance' => { 'hair' => 'black', 'eyes' => 'brown' } }
      ours = { 'appearance' => { 'hair' => 'gray', 'eyes' => 'brown' } }
      theirs = { 'appearance' => { 'hair' => 'white', 'eyes' => 'brown' } }

      conflicts = engine.find_conflicts(base: base, ours: ours, theirs: theirs)
      expect(conflicts.length).to eq(1)
      expect(conflicts[0].field_path).to eq('appearance.hair')
    end
  end

  describe '#three_way_merge' do
    it 'auto-merges non-conflicting changes from both branches' do
      base = { 'name' => 'Kenji', 'role' => 'developer', 'backstory' => 'original' }
      ours = { 'name' => 'Kenji', 'role' => 'senior', 'backstory' => 'original' }
      theirs = { 'name' => 'Kenji', 'role' => 'developer', 'backstory' => 'updated' }

      result = engine.three_way_merge(base: base, ours: ours, theirs: theirs)
      expect(result[:conflicts]).to be_empty
      expect(result[:merged]['role']).to eq('senior')
      expect(result[:merged]['backstory']).to eq('updated')
    end

    it 'returns conflicts and partial merge for conflicting fields' do
      base = { 'name' => 'Kenji', 'role' => 'dev', 'backstory' => 'old' }
      ours = { 'name' => 'Kenji', 'role' => 'senior', 'backstory' => 'ours' }
      theirs = { 'name' => 'Kenji', 'role' => 'lead', 'backstory' => 'theirs' }

      result = engine.three_way_merge(base: base, ours: ours, theirs: theirs)
      expect(result[:conflicts].length).to eq(2)
      expect(result[:merged]['name']).to eq('Kenji')
    end

    it 'does not mutate input hashes' do
      base = { 'name' => 'Kenji' }
      ours = { 'name' => 'Kenji', 'role' => 'senior' }
      theirs = { 'name' => 'Kenji', 'extra' => 'data' }

      engine.three_way_merge(base: base, ours: ours, theirs: theirs)
      expect(ours.key?('extra')).to be false
    end
  end
end
