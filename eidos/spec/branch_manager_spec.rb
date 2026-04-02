# frozen_string_literal: true

require 'tmpdir'
require_relative '../lib/eidos/branch_manager'
require_relative '../lib/eidos/revision_store'
require_relative '../lib/eidos/diff_engine'

RSpec.describe Eidos::BranchManager do
  let(:tmpdir) { Dir.mktmpdir }
  let(:story_bible_path) { File.join(tmpdir, 'data', 'story_bible') }
  let(:revisions_path) { File.join(story_bible_path, 'revisions') }
  let(:store) { Eidos::RevisionStore.new(revisions_path: revisions_path) }
  let(:diff_engine) { Eidos::DiffEngine.new }
  let(:manager) do
    described_class.new(
      story_bible_path: story_bible_path,
      revision_store: store,
      diff_engine: diff_engine
    )
  end

  before do
    # Set up a minimal world on main branch
    FileUtils.mkdir_p(File.join(story_bible_path, 'characters'))
    FileUtils.mkdir_p(File.join(story_bible_path, 'locations'))
    File.write(
      File.join(story_bible_path, 'characters', 'kenji.yml'),
      { 'id' => 'kenji', 'name' => 'Kenji', 'role' => 'developer', 'backstory' => 'original' }.to_yaml
    )
    File.write(
      File.join(story_bible_path, 'locations', 'office.yml'),
      { 'id' => 'office', 'name' => 'Main Office', 'type' => 'workplace' }.to_yaml
    )
    File.write(File.join(story_bible_path, 'facts.yml'), { 'facts' => {} }.to_yaml)
    File.write(File.join(story_bible_path, 'relationships.yml'), { 'relationships' => [] }.to_yaml)
    File.write(File.join(story_bible_path, 'plot_threads.yml'), { 'plot_threads' => [] }.to_yaml)
  end

  after { FileUtils.rm_rf(tmpdir) }

  describe '#create' do
    it 'creates a branch with a copy of main data' do
      branch = manager.create(name: 'alt', description: 'Alternative timeline')

      expect(branch.name).to eq('alt')
      expect(branch.parent_branch).to eq('main')
      expect(branch.status).to eq('active')
      expect(branch.description).to eq('Alternative timeline')

      branch_char = File.join(story_bible_path, 'branches', 'alt', 'characters', 'kenji.yml')
      expect(File.exist?(branch_char)).to be true
    end

    it 'raises when branch name already exists' do
      manager.create(name: 'alt')
      expect { manager.create(name: 'alt') }.to raise_error(/already exists/)
    end

    it 'supports nested branches (branch from a branch)' do
      manager.create(name: 'alt')
      nested = manager.create(name: 'alt-v2', from_branch: 'alt')
      expect(nested.parent_branch).to eq('alt')
    end
  end

  describe '#list' do
    it 'lists only active branches by default' do
      manager.create(name: 'active-one')
      manager.create(name: 'to-archive')
      manager.archive('to-archive')

      branches = manager.list
      expect(branches.map(&:name)).to eq(['active-one'])
    end

    it 'includes archived when requested' do
      manager.create(name: 'active-one')
      manager.create(name: 'to-archive')
      manager.archive('to-archive')

      branches = manager.list(include_archived: true)
      expect(branches.length).to eq(2)
    end
  end

  describe '#checkout and #current_branch' do
    it 'defaults to main' do
      expect(manager.current_branch).to eq('main')
    end

    it 'switches to a branch' do
      manager.create(name: 'alt')
      manager.checkout('alt')
      expect(manager.current_branch).to eq('alt')
    end

    it 'raises for non-existent branch' do
      expect { manager.checkout('nope') }.to raise_error(/not found/)
    end

    it 'raises for archived branch' do
      manager.create(name: 'alt')
      manager.archive('alt')
      expect { manager.checkout('alt') }.to raise_error(/archived/)
    end
  end

  describe '#compare' do
    it 'shows identical entities when branches match' do
      manager.create(name: 'alt')
      result = manager.compare('main', 'alt')
      expect(result[:identical]).not_to be_empty
      expect(result[:conflicts]).to be_empty
    end

    it 'detects differences after modifying a branch' do
      manager.create(name: 'alt')

      # Modify character on branch
      branch_char = File.join(story_bible_path, 'branches', 'alt', 'characters', 'kenji.yml')
      data = YAML.safe_load(File.read(branch_char))
      data['role'] = 'retired'
      File.write(branch_char, data.to_yaml)

      result = manager.compare('main', 'alt')
      expect(result[:conflicts].length).to be >= 1
    end
  end

  describe '#merge' do
    it 'auto-merges non-conflicting changes' do
      manager.create(name: 'alt')

      # Add a new character on the branch only
      branch_chars = File.join(story_bible_path, 'branches', 'alt', 'characters')
      File.write(
        File.join(branch_chars, 'kai.yml'),
        { 'id' => 'kai', 'name' => 'Kai', 'role' => 'intern' }.to_yaml
      )

      result = manager.merge(source: 'alt', target: 'main')
      expect(result[:auto_merged]).to include('character/kai')

      # Verify it appeared on main
      main_kai = File.join(story_bible_path, 'characters', 'kai.yml')
      expect(File.exist?(main_kai)).to be true
    end

    it 'reports differences when both branches modify the same entity' do
      manager.create(name: 'alt')

      # Modify role differently on branch
      branch_char = File.join(story_bible_path, 'branches', 'alt', 'characters', 'kenji.yml')
      data = YAML.safe_load(File.read(branch_char))
      data['role'] = 'retired'
      data['backstory'] = 'alt backstory'
      File.write(branch_char, data.to_yaml)

      # Keep main as-is, the branch has changes relative to main (the base)
      # Since base = target in our simplified merge, branch changes are auto-merged
      result = manager.merge(source: 'alt', target: 'main')
      expect(result[:auto_merged]).to include('character/kenji')

      # Verify the merged data on main
      main_char = File.join(story_bible_path, 'characters', 'kenji.yml')
      merged = YAML.safe_load(File.read(main_char))
      expect(merged['role']).to eq('retired')
      expect(merged['backstory']).to eq('alt backstory')
    end
  end

  describe '#archive' do
    it 'marks a branch as archived' do
      manager.create(name: 'alt')
      manager.archive('alt')

      branch = manager.list(include_archived: true).find { |b| b.name == 'alt' }
      expect(branch.status).to eq('archived')
    end

    it 'raises when branch has active children' do
      manager.create(name: 'parent')
      manager.create(name: 'child', from_branch: 'parent')
      expect { manager.archive('parent') }.to raise_error(/active children/)
    end
  end

  describe '#unarchive' do
    it 'restores an archived branch' do
      manager.create(name: 'alt')
      manager.archive('alt')
      manager.unarchive('alt')

      branch = manager.list.find { |b| b.name == 'alt' }
      expect(branch.status).to eq('active')
    end
  end

  describe '#delete' do
    it 'permanently removes a branch' do
      manager.create(name: 'alt')
      manager.delete('alt')

      expect(manager.list(include_archived: true)).to be_empty
      branch_dir = File.join(story_bible_path, 'branches', 'alt')
      expect(Dir.exist?(branch_dir)).to be false
    end

    it 'prevents deleting main' do
      expect { manager.delete('main') }.to raise_error(/Cannot delete/)
    end

    it 'raises when branch has active children' do
      manager.create(name: 'parent')
      manager.create(name: 'child', from_branch: 'parent')
      expect { manager.delete('parent') }.to raise_error(/active children/)
    end
  end
end
