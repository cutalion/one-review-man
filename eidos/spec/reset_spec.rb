# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tempfile'
require 'eidos/cli/world'

RSpec.describe 'book reset' do
  let(:cli_path) { File.expand_path('../bin/book', __dir__) }
  let(:test_dir) { Dir.mktmpdir('book_cli_test') }

  after do
    FileUtils.rm_rf(test_dir)
  end

  describe 'integrated reset' do
    before do
      # Create the necessary directories and files in the temporary directory
      FileUtils.mkdir_p(File.join(test_dir, '_chapters'))
      FileUtils.mkdir_p(File.join(test_dir, 'data'))
      FileUtils.mkdir_p(File.join(test_dir, '_characters'))
      File.write(File.join(test_dir, 'data', 'world_metadata.yml'), "book:\n  current_chapter: 1\n")
      File.write(File.join(test_dir, 'data', 'characters.yml'), "characters:\n  test_character:\n    name: Test Character\n")
      File.write(File.join(test_dir, '_chapters', '001-chapter.md'), "---\ntitle: Chapter 1\n---\nContent\n")
      File.write(File.join(test_dir, '_characters', 'test_character.md'), "---\nname: Test Character\n---\nContent\n")
    end

    it 'calls the Resetter for all' do
      # Mock the Resetter to avoid actual file system changes
      expect(Eidos::Reset).to receive(:new).and_call_original
      # Stub the reset_all method to prevent it from running
      expect_any_instance_of(Eidos::Reset).to receive(:reset_all).with(force: true)

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        Eidos::CLI::World.start(%w[reset all --force])
      end
    end

    it 'calls the Resetter for characters' do
      # Mock the Resetter to avoid actual file system changes
      expect(Eidos::Reset).to receive(:new).and_call_original
      # Stub the reset_characters method to prevent it from running
      expect_any_instance_of(Eidos::Reset).to receive(:reset_characters).with(force: true)

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        Eidos::CLI::World.start(%w[reset characters --force])
      end
    end

    it 'calls the Resetter for chapters' do
      # Mock the Resetter to avoid actual file system changes
      expect(Eidos::Reset).to receive(:new).and_call_original
      # Stub the reset_chapters method to prevent it from running
      expect_any_instance_of(Eidos::Reset).to receive(:reset_chapters).with(force: true)

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        Eidos::CLI::World.start(%w[reset chapters --force])
      end
    end

    it 'calls the Resetter for data' do
      # Mock the Resetter to avoid actual file system changes
      expect(Eidos::Reset).to receive(:new).and_call_original
      # Stub the reset_data_files method to prevent it from running
      expect_any_instance_of(Eidos::Reset).to receive(:reset_data_files)

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        Eidos::CLI::World.start(%w[reset data])
      end
    end

    it 'calls the Resetter for site' do
      # Mock the Resetter to avoid actual file system changes
      expect(Eidos::Reset).to receive(:new).and_call_original
      # Stub the reset_generated_site method to prevent it from running
      expect_any_instance_of(Eidos::Reset).to receive(:reset_generated_site)

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        Eidos::CLI::World.start(%w[reset site])
      end
    end

    it 'calls the Resetter for status' do
      # Mock the Resetter to avoid actual file system changes
      expect(Eidos::Reset).to receive(:new).and_call_original
      # Stub the status method to prevent it from running
      expect_any_instance_of(Eidos::Reset).to receive(:status)

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        Eidos::CLI::World.start(%w[reset status])
      end
    end
  end

  # T012 / US1 / feature 012-fix-ux-unify-bible
  describe '#reset_chapters target directory' do
    let(:reset) { Eidos::Reset.new }

    it 'deletes *.md files under content/chapters/ when forced' do
      FileUtils.mkdir_p(File.join(test_dir, 'content', 'chapters'))
      File.write(File.join(test_dir, 'content', 'chapters', '001-chapter.md'), 'content')
      File.write(File.join(test_dir, 'content', 'chapters', '002-chapter.md'), 'content')

      Dir.chdir(test_dir) do
        original = $stdout
        $stdout = StringIO.new
        begin
          reset.reset_chapters(force: true)
        ensure
          $stdout = original
        end
      end

      expect(Dir.glob(File.join(test_dir, 'content', 'chapters', '*.md'))).to be_empty
    end
  end
end
