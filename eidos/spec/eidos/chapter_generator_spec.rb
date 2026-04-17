# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'stringio'
require 'eidos/chapter_generator'
require 'eidos/configuration'
require 'eidos/world_config'

RSpec.describe Eidos::ChapterGenerator do
  # Specs covering US1 fixes in feature 012-fix-ux-unify-bible:
  #   T005 – no "Migrated" message on chapter generation
  #   T007 – LLM-supplied title is used (with fallback)
  #   T008 – no "Not specified" in chapter summary stdout

  let(:tmp_dir) { Dir.mktmpdir('chapter_generator_spec') }

  after { FileUtils.rm_rf(tmp_dir) }

  def setup_world(with_legacy_world_yml: false)
    FileUtils.mkdir_p(File.join(tmp_dir, 'content', 'chapters'))
    FileUtils.mkdir_p(File.join(tmp_dir, 'data', 'story_bible'))

    File.write(File.join(tmp_dir, 'data', 'world_config.yml'), <<~YAML)
      generation:
        chapter_length_target: "500-1000 words"
        main_characters: []
      localized:
        en:
          title: "Test Book"
          author: "Test"
          genre: "Comedy"
          humor_style: "narrative"
    YAML
    File.write(File.join(tmp_dir, 'data', 'world_state.yml'),
               "book:\n  current_chapter: 0\n  target_chapters: 10\n")
    File.write(File.join(tmp_dir, 'data', 'settings.yml'),
               "llm:\n  model: mock\n")
    File.write(File.join(tmp_dir, 'data', 'story_bible', 'facts.yml'), "facts: {}\n")
    File.write(File.join(tmp_dir, 'data', 'story_bible', 'relationships.yml'),
               "relationships: []\n")
    File.write(File.join(tmp_dir, 'data', 'story_bible', 'plot_threads.yml'),
               "plot_threads: []\n")

    return unless with_legacy_world_yml

    # Simulate what `world new --quick` writes today (to be removed in US2).
    File.write(File.join(tmp_dir, 'data', 'world.yml'), {
      'en' => {
        'world' => {
          'established_facts' => ['Test fact']
        }
      }
    }.to_yaml)
  end

  def build_generator
    config = Eidos::WorldConfig.load_from_project(tmp_dir)
    configuration = Eidos::Configuration.load(tmp_dir, {})
    described_class.new(
      configuration: configuration,
      project_root: tmp_dir,
      book_config: config
    )
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def read_front_matter
    chapter_file = Dir.glob(File.join(tmp_dir, 'content', 'chapters', '*.md')).first
    return nil unless chapter_file

    body = File.read(chapter_file)
    parts = body.split(/^---\s*$/, 3)
    YAML.safe_load(parts[1]) if parts.length >= 3
  end

  # ----- T005 ---------------------------------------------------------------

  describe 'legacy world.yml handling (T005 / US1 / feature 012)' do
    it 'does not emit "Migrated" to stdout even when data/world.yml exists' do
      setup_world(with_legacy_world_yml: true)
      generator = build_generator

      out = capture_stdout { generator.generate_next_chapter(auto_generate: true) }

      expect(out).not_to include('Migrated')
    end

    it 'does not create data/story_facts.yml as a migration side-effect' do
      setup_world(with_legacy_world_yml: true)
      generator = build_generator

      capture_stdout { generator.generate_next_chapter(auto_generate: true) }

      expect(File.exist?(File.join(tmp_dir, 'data', 'story_facts.yml'))).to be(false)
    end
  end

  # ----- T007 ---------------------------------------------------------------

  describe 'chapter title (T007 / US1 / feature 012)' do
    it 'uses the LLM-supplied title in the chapter generation summary' do
      setup_world
      generator = build_generator
      llm = generator.instance_variable_get(:@llm_service)
      allow(llm).to receive(:generate_chapter_structured).and_return(
        'title' => 'The Rejection Letter',
        'summary' => 'summary',
        'content' => ('word ' * 120).strip,
        'new_characters' => []
      )

      out = capture_stdout { generator.generate_next_chapter(auto_generate: true) }

      expect(out).to include('Title: The Rejection Letter')
    end

    it 'falls back to "Chapter N" when LLM omits a title' do
      setup_world
      generator = build_generator
      llm = generator.instance_variable_get(:@llm_service)
      allow(llm).to receive(:generate_chapter_structured).and_return(
        'summary' => 'summary',
        'content' => ('word ' * 120).strip,
        'new_characters' => []
      )

      out = capture_stdout { generator.generate_next_chapter(auto_generate: true) }

      expect(out).to include('Title: Chapter 1')
      expect(read_front_matter['title']).to eq('Chapter 1')
    end
  end

  # ----- T008 ---------------------------------------------------------------

  describe 'chapter summary output (T008 / US1 / feature 012)' do
    it 'does not print "Not specified" in the generation summary' do
      setup_world
      generator = build_generator

      out = capture_stdout { generator.generate_next_chapter(auto_generate: true) }

      expect(out).not_to include('Not specified')
    end
  end

  # ----- T021 + T022 --------------------------------------------------------

  describe 'unified lore store (T021/T022 / US2 / feature 012)' do
    it 'includes a character saved via StoryBible in the LLM prompt' do
      setup_world
      # Populate the canonical store that the SDK writes to.
      bible = Eidos::StoryBible.new(project_root: tmp_dir)
      bible.setup
      bible.save_character('jax_patel', {
        'name' => 'Jax Patel',
        'description' => 'A fresh-faced DevOps intern who is convinced every outage is his fault.',
        'traits' => %w[anxious curious]
      })

      generator = build_generator
      captured_prompt = nil
      llm = generator.instance_variable_get(:@llm_service)
      allow(llm).to receive(:generate_chapter_structured) do |prompt, _opts|
        captured_prompt = prompt
        {
          'title' => 'T', 'summary' => 's',
          'content' => ('word ' * 120).strip,
          'new_characters' => []
        }
      end

      capture_stdout { generator.generate_next_chapter(auto_generate: true) }

      expect(captured_prompt).to include('Jax Patel')
    end
  end

  # ----- T024 ---------------------------------------------------------------

  describe 'stray legacy files are ignored (T024 / US2 / feature 012)' do
    it 'does not read, write, or log about data/world.yml or data/story_facts.yml' do
      setup_world
      world_path = File.join(tmp_dir, 'data', 'world.yml')
      facts_path = File.join(tmp_dir, 'data', 'story_facts.yml')
      # Distinctive strings that would surface if Eidos silently read these.
      File.write(world_path, {
        'en' => { 'world' => { 'established_facts' => ['STRAY_WORLD_FACT_9ZQ'] } }
      }.to_yaml)
      File.write(facts_path, {
        'en' => { 'facts' => {
          'locations' => { 'loc1' => { 'name' => 'STRAY_LOC_9ZQ', 'description' => 'x', 'type' => 't' } }
        } }
      }.to_yaml)
      world_mtime_before = File.mtime(world_path)
      facts_mtime_before = File.mtime(facts_path)

      generator = build_generator
      captured_prompt = nil
      llm = generator.instance_variable_get(:@llm_service)
      allow(llm).to receive(:generate_chapter_structured) do |prompt, _opts|
        captured_prompt = prompt
        { 'title' => 't', 'summary' => 's', 'content' => ('word ' * 120).strip, 'new_characters' => [] }
      end

      out = capture_stdout { generator.generate_next_chapter(auto_generate: true) }

      expect(out).not_to include('Migrated')
      expect(out).not_to match(/world\.yml|story_facts\.yml/)
      expect(File.mtime(world_path)).to eq(world_mtime_before)
      expect(File.mtime(facts_path)).to eq(facts_mtime_before)
      expect(captured_prompt).not_to include('STRAY_WORLD_FACT_9ZQ')
      expect(captured_prompt).not_to include('STRAY_LOC_9ZQ')
    end
  end
end
