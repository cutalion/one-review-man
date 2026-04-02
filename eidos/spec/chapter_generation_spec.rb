# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tempfile'
require 'eidos/cli/produce'
require 'eidos/chapter_generator'
require 'eidos/snapshot_store'
require 'eidos/configuration'

RSpec.describe 'book chapter generation' do
  let(:cli_path) { File.expand_path('../bin/book', __dir__) }
  let(:test_dir) { Dir.mktmpdir('book_cli_test') }

  after do
    FileUtils.rm_rf(test_dir)
  end

  describe 'edge cases' do
    it 'generates a chapter when Story Bible is empty' do
      # Set up minimal project with empty Story Bible
      FileUtils.mkdir_p(File.join(test_dir, 'content', 'chapters'))
      FileUtils.mkdir_p(File.join(test_dir, 'data', 'story_bible', 'characters'))
      FileUtils.mkdir_p(File.join(test_dir, 'data', 'story_bible', 'locations'))
      File.write(File.join(test_dir, 'data', 'world_config.yml'), <<~YAML)
        generation:
          chapter_length_target: "500-1000 words"
          main_characters: []
          content_rules:
            parody_source: "One-Punch Man"
        localized:
          en:
            title: "Test Book"
            author: "Test"
            genre: "Comedy"
      YAML
      File.write(File.join(test_dir, 'data', 'world_state.yml'), "book:\n  current_chapter: 0\n  target_chapters: 10\n")
      File.write(File.join(test_dir, 'data', 'settings.yml'), "llm:\n  model: mock\n")
      File.write(File.join(test_dir, 'data', 'story_bible', 'facts.yml'), "facts: {}\n")
      File.write(File.join(test_dir, 'data', 'story_bible', 'relationships.yml'), "relationships: []\n")
      File.write(File.join(test_dir, 'data', 'story_bible', 'plot_threads.yml'), "plot_threads: []\n")

      config = Eidos::WorldConfig.load_from_project(test_dir)
      configuration = Eidos::Configuration.load(test_dir, {})
      generator = Eidos::ChapterGenerator.new(
        configuration: configuration,
        project_root: test_dir,
        book_config: config
      )

      # Should not raise even with empty Story Bible
      expect { generator.generate_next_chapter(auto_generate: true) }.not_to raise_error
      expect(Dir.glob(File.join(test_dir, 'content', 'chapters', '*.md')).length).to be >= 1
    end

    it 'determines next chapter number correctly when chapters already exist' do
      FileUtils.mkdir_p(File.join(test_dir, 'content', 'chapters'))
      FileUtils.mkdir_p(File.join(test_dir, 'data'))
      # Create existing chapters
      File.write(File.join(test_dir, 'content', 'chapters', '001-chapter.md'), "---\ntitle: Ch1\n---\n")
      File.write(File.join(test_dir, 'content', 'chapters', '002-chapter.md'), "---\ntitle: Ch2\n---\n")
      File.write(File.join(test_dir, 'data', 'world_config.yml'), <<~YAML)
        generation:
          chapter_length_target: "500 words"
          main_characters: []
        localized:
          en:
            title: "Test Book"
            author: "Test"
            genre: "Comedy"
      YAML
      File.write(File.join(test_dir, 'data', 'world_state.yml'), "book:\n  current_chapter: 2\n  target_chapters: 10\n")
      File.write(File.join(test_dir, 'data', 'settings.yml'), "llm:\n  model: mock\n")

      config = Eidos::WorldConfig.load_from_project(test_dir)
      configuration = Eidos::Configuration.load(test_dir, {})
      generator = Eidos::ChapterGenerator.new(
        configuration: configuration,
        project_root: test_dir,
        book_config: config
      )

      # Access private method via send
      next_num = generator.send(:determine_next_chapter_number)
      expect(next_num).to eq(3)
    end
  end

  describe 'canon version recording' do
    let(:project_with_bible) do
      dir = test_dir
      FileUtils.mkdir_p(File.join(dir, 'content', 'chapters'))
      FileUtils.mkdir_p(File.join(dir, 'data', 'story_bible', 'characters'))
      FileUtils.mkdir_p(File.join(dir, 'data', 'story_bible', 'locations'))
      File.write(File.join(dir, 'data', 'world_config.yml'), <<~YAML)
        generation:
          chapter_length_target: "500-1000 words"
          main_characters: []
          content_rules:
            parody_source: "One-Punch Man"
        localized:
          en:
            title: "Test Book"
            author: "Test"
            genre: "Comedy"
      YAML
      File.write(File.join(dir, 'data', 'world_state.yml'), "book:\n  current_chapter: 0\n  target_chapters: 10\n")
      File.write(File.join(dir, 'data', 'settings.yml'), "llm:\n  model: mock\n")
      File.write(File.join(dir, 'data', 'story_bible', 'facts.yml'), "facts: {}\n")
      File.write(File.join(dir, 'data', 'story_bible', 'relationships.yml'), "relationships: []\n")
      File.write(File.join(dir, 'data', 'story_bible', 'plot_threads.yml'), "plot_threads: []\n")
      dir
    end

    it 'includes canon_version as "unversioned" when no snapshots exist' do
      dir = project_with_bible
      config = Eidos::WorldConfig.load_from_project(dir)
      configuration = Eidos::Configuration.load(dir, {})
      generator = Eidos::ChapterGenerator.new(
        configuration: configuration,
        project_root: dir,
        book_config: config
      )

      generator.generate_next_chapter(auto_generate: true)

      chapter_file = Dir.glob(File.join(dir, 'content', 'chapters', '*.md')).first
      content = File.read(chapter_file)
      # Parse front matter
      parts = content.split("---\n", 3)
      front_matter = YAML.safe_load(parts[1])
      expect(front_matter['canon_version']).to eq('unversioned')
    end

    it 'includes canon_version with snapshot reference when snapshot exists' do
      dir = project_with_bible
      bible_path = File.join(dir, 'data', 'story_bible')
      store = Eidos::SnapshotStore.new(story_bible_path: bible_path)
      store.create(name: 'initial')

      config = Eidos::WorldConfig.load_from_project(dir)
      configuration = Eidos::Configuration.load(dir, {})
      generator = Eidos::ChapterGenerator.new(
        configuration: configuration,
        project_root: dir,
        book_config: config
      )

      generator.generate_next_chapter(auto_generate: true)

      chapter_file = Dir.glob(File.join(dir, 'content', 'chapters', '*.md')).first
      content = File.read(chapter_file)
      parts = content.split("---\n", 3)
      front_matter = YAML.safe_load(parts[1])
      expect(front_matter['canon_version']).to be_a(Hash)
      expect(front_matter['canon_version']['snapshot']).to eq('initial')
      expect(front_matter['canon_version']['version']).to eq(1)
    end

    it 'uses explicit snapshot when snapshot: kwarg is provided' do
      dir = project_with_bible
      bible_path = File.join(dir, 'data', 'story_bible')
      store = Eidos::SnapshotStore.new(story_bible_path: bible_path)
      store.create(name: 'first')
      store.create(name: 'second')

      config = Eidos::WorldConfig.load_from_project(dir)
      configuration = Eidos::Configuration.load(dir, {})
      generator = Eidos::ChapterGenerator.new(
        snapshot: 'first',
        configuration: configuration,
        project_root: dir,
        book_config: config
      )

      generator.generate_next_chapter(auto_generate: true)

      chapter_file = Dir.glob(File.join(dir, 'content', 'chapters', '*.md')).first
      content = File.read(chapter_file)
      parts = content.split("---\n", 3)
      front_matter = YAML.safe_load(parts[1])
      expect(front_matter['canon_version']['snapshot']).to eq('first')
      expect(front_matter['canon_version']['version']).to eq(1)
    end
  end

  describe 'integrated chapter generation' do
    it 'calls the ChapterGenerator with correct options' do
      # Create the necessary directories and files in the temporary directory
      FileUtils.mkdir_p(File.join(test_dir, '_chapters'))
      FileUtils.mkdir_p(File.join(test_dir, 'data'))
      File.write(File.join(test_dir, 'data', 'world_metadata.yml'), "book:\n  current_chapter: 0\n")
      File.write(File.join(test_dir, 'data', 'characters.yml'), "characters:\n")
      File.write(File.join(test_dir, 'data', 'generation_log.yml'), "generations:\n")
      File.write(File.join(test_dir, 'data', 'settings.yml'), "llm:\n  model: mock\n")

      # Mock the ChapterGenerator to avoid actual LLM calls
      expect(Eidos::ChapterGenerator).to receive(:new).with(hash_including(configuration: kind_of(Hash), project_root: kind_of(String))).and_call_original
      # Stub the generate_next_chapter method to prevent it from running
      expect_any_instance_of(Eidos::ChapterGenerator).to receive(:generate_next_chapter).with(auto_generate: true)

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        # Suppress console output from the CLI command so the spec suite stays
        # quiet when executed with the documentation formatter.
        original_stdout = $stdout
        original_stderr = $stderr
        begin
          $stdout = StringIO.new
          $stderr = StringIO.new
          Eidos::CLI::Produce.start(%w[chapter --content-model gpt-4o --auto])
        ensure
          $stdout = original_stdout
          $stderr = original_stderr
        end
      end
    end
  end
end
