# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tempfile'
require 'book/cli'
require 'book_core/chapter_generator'

RSpec.describe 'book chapter generation' do
  let(:cli_path) { File.expand_path('../bin/book', __dir__) }
  let(:test_dir) { Dir.mktmpdir('book_cli_test') }

  after do
    FileUtils.rm_rf(test_dir) if Dir.exist?(test_dir)
  end

  describe 'integrated chapter generation' do
    it 'calls the ChapterGenerator with correct options' do
      # Create the necessary directories and files in the temporary directory
      FileUtils.mkdir_p(File.join(test_dir, '_chapters'))
      FileUtils.mkdir_p(File.join(test_dir, 'data'))
      FileUtils.mkdir_p(File.join(test_dir, 'scripts', 'prompts'))
      File.write(File.join(test_dir, 'data', 'book_metadata.yml'), "book:\n  current_chapter: 0\n")
      File.write(File.join(test_dir, 'data', 'characters.yml'), "characters:\n")
      File.write(File.join(test_dir, 'data', 'generation_log.yml'), "generations:\n")
      File.write(File.join(test_dir, 'scripts', 'prompts', 'chapter_prompts.txt'), "prompt template\n")
      File.write(File.join(test_dir, 'scripts', 'llm_config.yml'), "model: mock\n")

      # Mock the ChapterGenerator to avoid actual LLM calls
      expect(BookCore::ChapterGenerator).to receive(:new).with('gpt-4o', hash_including(project_root: kind_of(String))).and_call_original
      # Stub the generate_next_chapter method to prevent it from running
      expect_any_instance_of(BookCore::ChapterGenerator).to receive(:generate_next_chapter).with(auto_generate: true)

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        # Suppress console output from the CLI command so the spec suite stays
        # quiet when executed with the documentation formatter.
        original_stdout = $stdout
        original_stderr = $stderr
        begin
          $stdout = StringIO.new
          $stderr = StringIO.new
          Book::CLI::Runner.start(%w[generate chapter --model gpt-4o --auto])
        ensure
          $stdout = original_stdout
          $stderr = original_stderr
        end
      end
    end
  end
end
