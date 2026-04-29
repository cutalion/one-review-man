# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'eidos/cli/bible'
require 'eidos/story_bible'
require 'eidos/revision_store'

# Feature 019 — bible authoring CLI: `bible add` / `bible update` /
# `bible remove` for all five canonical entity types
# (character, location, fact, relationship, plot_thread). Replaces
# the legacy `canon update character|location` shape.
RSpec.describe Eidos::CLI::Bible, 'authoring (feature 019)' do
  let(:tmp_dir) { Dir.mktmpdir('bible_authoring_spec') }

  before do
    FileUtils.mkdir_p(File.join(tmp_dir, 'data'))
    File.write(File.join(tmp_dir, 'data', 'world_config.yml'),
               { 'localized' => { 'en' => { 'title' => 'x' } } }.to_yaml)
    Eidos::StoryBible.new(project_root: tmp_dir).setup
  end

  after { FileUtils.rm_rf(tmp_dir) }

  def run_cli(*argv)
    real_stdout = $stdout
    real_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    described_class.start(argv + ['-w', tmp_dir])
    [$stdout.string, $stderr.string]
  rescue SystemExit => e
    [$stdout.string, $stderr.string, e.status]
  ensure
    $stdout = real_stdout
    $stderr = real_stderr
  end

  def reload_bible
    Eidos::StoryBible.new(project_root: tmp_dir)
  end

  # --- bible add character -------------------------------------------------

  describe 'bible add character' do
    it 'creates a new character with the given fields' do
      out, _ = run_cli('add', 'character', 'thorin', 'name=Thorin', 'race=dwarf', 'role=engineer')

      expect(out).to match(/Added character\/thorin/)
      char = reload_bible.get_character('thorin')
      expect(char['name']).to eq('Thorin')
      expect(char['race']).to eq('dwarf')
      expect(char['role']).to eq('engineer')
    end

    it 'errors when the character already exists' do
      run_cli('add', 'character', 'thorin', 'name=Thorin')
      _out, err, status = run_cli('add', 'character', 'thorin', 'name=Different')

      expect(status).to eq(1)
      expect(err).to match(/already exists/i)
      expect(reload_bible.get_character('thorin')['name']).to eq('Thorin')
    end

    it 'records the change reason in the revision history' do
      run_cli('add', 'character', 'thorin', 'name=Thorin', '--reason', 'founding cast')
      hist = Eidos::RevisionStore.new(revisions_path: File.join(tmp_dir, 'data', 'story_bible', 'revisions'))
                                  .history(entity_type: 'character', entity_id: 'thorin')
      expect(hist.first.change_reason).to eq('founding cast')
    end

    it 'works with zero fields (creates a minimal record)' do
      out, _ = run_cli('add', 'character', 'mystery_one')
      expect(out).to match(/Added character\/mystery_one/)
      expect(reload_bible.get_character('mystery_one')['id']).to eq('mystery_one')
    end
  end

  # --- bible update character ----------------------------------------------

  describe 'bible update character' do
    it 'merges new fields into an existing character' do
      run_cli('add', 'character', 'thorin', 'name=Thorin', 'race=dwarf')
      run_cli('update', 'character', 'thorin', 'role=High-Engineer')

      char = reload_bible.get_character('thorin')
      expect(char['name']).to eq('Thorin')
      expect(char['race']).to eq('dwarf')
      expect(char['role']).to eq('High-Engineer')
    end

    it 'errors when the character does not exist' do
      _out, err, status = run_cli('update', 'character', 'nope', 'name=Anyone')
      expect(status).to eq(1)
      expect(err).to match(/does not exist|not found/i)
    end

    it 'overwrites a field when re-set' do
      run_cli('add', 'character', 'thorin', 'role=engineer')
      run_cli('update', 'character', 'thorin', 'role=lord')
      expect(reload_bible.get_character('thorin')['role']).to eq('lord')
    end
  end

  # --- bible add/update location -------------------------------------------

  describe 'bible add/update location' do
    it 'creates and updates a location' do
      run_cli('add', 'location', 'citadel', 'name=Citadel', 'type=city')
      expect(reload_bible.get_location('citadel')['type']).to eq('city')

      run_cli('update', 'location', 'citadel', 'description=Half-mountain, half-foundry.')
      expect(reload_bible.get_location('citadel')['description']).to start_with('Half-mountain')
    end

    it 'errors on duplicate add' do
      run_cli('add', 'location', 'citadel', 'name=Citadel')
      _out, err, status = run_cli('add', 'location', 'citadel', 'name=Other')
      expect(status).to eq(1)
      expect(err).to match(/already exists/i)
    end
  end

  # --- bible add/update fact (slash-keyed by category) ---------------------

  describe 'bible add/update fact' do
    it 'creates a fact under category/id' do
      out, _ = run_cli('add', 'fact', 'world_rules/silver_focus',
                       'rule=Spellcasters require silver to focus arcane energy.',
                       'category=magic')
      expect(out).to match(%r{Added fact/world_rules/silver_focus})

      fact = reload_bible.get_facts_by_category('world_rules')['silver_focus']
      expect(fact['rule']).to start_with('Spellcasters')
    end

    it 'errors when the slash form is missing' do
      _out, err, status = run_cli('add', 'fact', 'just_an_id', 'rule=…')
      expect(status).to eq(1)
      expect(err).to match(/CATEGORY\/ID/i)
    end

    it 'updates an existing fact' do
      run_cli('add', 'fact', 'events/collapse', 'name=Deep Collapse', 'year=873')
      run_cli('update', 'fact', 'events/collapse', 'description=A mining accident that killed 1,400.')

      fact = reload_bible.get_facts_by_category('events')['collapse']
      expect(fact['name']).to eq('Deep Collapse')
      expect(fact['description']).to start_with('A mining accident')
    end
  end

  # --- bible add relationship ----------------------------------------------

  describe 'bible add relationship' do
    it 'appends a relationship between two characters' do
      run_cli('add', 'character', 'thorin', 'name=Thorin')
      run_cli('add', 'character', 'lyara',  'name=Lyara')
      out, _ = run_cli('add', 'relationship', 'thorin', 'lyara',
                       'type=rival', 'status=established')

      expect(out).to match(/Added relationship thorin <-> lyara/)
      rels = reload_bible.relationships
      expect(rels.size).to eq(1)
      expect(rels.first['character1']).to eq('thorin')
      expect(rels.first['character2']).to eq('lyara')
      expect(rels.first['type']).to eq('rival')
    end

    # Relationships are append-only in the existing storage layer; no
    # bible update relationship for v1 (direct YAML edit covers it).
  end

  # --- bible add/update plot_thread ----------------------------------------

  describe 'bible add/update plot_thread' do
    it 'creates a plot thread keyed by id' do
      run_cli('add', 'plot_thread', 'underground_threat',
              'description=A subterranean menace approaches.',
              'status=active')

      threads = reload_bible.plot_threads
      thread = threads.find { |t| t['id'] == 'underground_threat' }
      expect(thread).not_to be_nil
      expect(thread['description']).to start_with('A subterranean')
    end

    it 'updates an existing plot thread' do
      run_cli('add', 'plot_thread', 'underground_threat', 'description=A menace.')
      run_cli('update', 'plot_thread', 'underground_threat', 'status=resolved')

      threads = reload_bible.plot_threads
      thread = threads.find { |t| t['id'] == 'underground_threat' }
      expect(thread['status']).to eq('resolved')
    end
  end

  # --- unknown TYPE --------------------------------------------------------

  describe 'unknown TYPE' do
    it 'errors with a helpful message for both add and update' do
      _out, err, status = run_cli('add', 'gizmo', 'foo', 'name=Bar')
      expect(status).to eq(1)
      expect(err).to match(/Unknown TYPE: gizmo/i)
      expect(err).to match(/character|location|fact|relationship|plot_thread/i)
    end
  end
end
