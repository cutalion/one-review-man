# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tempfile'
require_relative '../lib/book/cli'
require_relative '../lib/book/reset'
require_relative '../lib/book/jekyll_helper'

RSpec.describe 'book reset' do
  let(:cli_path) { File.expand_path('../bin/book', __dir__) }
  let(:test_dir) { Dir.mktmpdir('book_cli_test') }

  after do
    FileUtils.rm_rf(test_dir) if Dir.exist?(test_dir)
  end

  describe 'integrated reset' do
    before do
      # Create the necessary directories and files in the temporary directory
      FileUtils.mkdir_p(File.join(test_dir, '_chapters'))
      FileUtils.mkdir_p(File.join(test_dir, '_data'))
      FileUtils.mkdir_p(File.join(test_dir, '_characters'))
      File.write(File.join(test_dir, '_data', 'book_metadata.yml'), "book:\n  current_chapter: 1\n")
      File.write(File.join(test_dir, '_data', 'characters.yml'), "characters:\n  test_character:\n    name: Test Character\n")
      File.write(File.join(test_dir, '_chapters', '001-chapter.md'), "---\ntitle: Chapter 1\n---\nContent\n")
      File.write(File.join(test_dir, '_characters', 'test_character.md'), "---\nname: Test Character\n---\nContent\n")
    end

    it 'calls the Resetter for all' do
      # Mock the Resetter to avoid actual file system changes
      expect_any_instance_of(Book::Reset).to receive(:reset_characters).with(force: true)
      expect_any_instance_of(Book::Reset).to receive(:reset_chapters).with(force: true)
      expect_any_instance_of(Book::Reset).to receive(:reset_data_files)
      expect(Book::JekyllHelper).to receive(:clean_generated_site)

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        Book::CLI::Runner.start(%w[reset all --force])
      end
    end

    it 'calls the Resetter for characters' do
      # Mock the Resetter to avoid actual file system changes
      expect(Book::Reset).to receive(:new).and_call_original
      # Stub the reset_characters method to prevent it from running
      expect_any_instance_of(Book::Reset).to receive(:reset_characters).with(force: true)

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        Book::CLI::Runner.start(%w[reset characters --force])
      end
    end

    it 'calls the Resetter for chapters' do
      # Mock the Resetter to avoid actual file system changes
      expect(Book::Reset).to receive(:new).and_call_original
      # Stub the reset_chapters method to prevent it from running
      expect_any_instance_of(Book::Reset).to receive(:reset_chapters).with(force: true)

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        Book::CLI::Runner.start(%w[reset chapters --force])
      end
    end

    it 'calls the Resetter for data' do
      # Mock the Resetter to avoid actual file system changes
      expect(Book::Reset).to receive(:new).and_call_original
      # Stub the reset_data_files method to prevent it from running
      expect_any_instance_of(Book::Reset).to receive(:reset_data_files)

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        Book::CLI::Runner.start(%w[reset data])
      end
    end

    it 'calls the JekyllHelper for site' do
      # Mock the JekyllHelper to avoid actual file system changes
      expect(Book::JekyllHelper).to receive(:clean_generated_site)

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        # We need to find a way to test this without calling the runner
        # For now, let's just call the method directly on the class
        cli = Book::CLI::Reset.new
        cli.invoke(:site)
      end
    end

    it 'calls the Resetter for status' do
      # Mock the Resetter to avoid actual file system changes
      expect(Book::Reset).to receive(:new).and_call_original
      # Stub the status method to prevent it from running
      expect_any_instance_of(Book::Reset).to receive(:status)

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        Book::CLI::Runner.start(%w[reset status])
      end
    end
  end
end
