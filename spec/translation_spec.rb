# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tempfile'
require_relative '../lib/book/cli'
require_relative '../lib/book/translator'

RSpec.describe 'book translation' do
  let(:cli_path) { File.expand_path('../bin/book', __dir__) }
  let(:test_dir) { Dir.mktmpdir('book_cli_test') }

  after do
    FileUtils.rm_rf(test_dir) if Dir.exist?(test_dir)
  end

  describe 'integrated translation' do
    before do
      # Create the necessary directories and files in the temporary directory
      FileUtils.mkdir_p(File.join(test_dir, '_chapters'))
      FileUtils.mkdir_p(File.join(test_dir, '_data'))
      FileUtils.mkdir_p(File.join(test_dir, '_characters'))
      FileUtils.mkdir_p(File.join(test_dir, 'scripts', 'prompts'))
      File.write(File.join(test_dir, '_data', 'book_metadata.yml'), "book:\n  current_chapter: 0\n")
      File.write(File.join(test_dir, '_data', 'characters.yml'), "characters:\n")
      File.write(File.join(test_dir, '_data', 'generation_log.yml'), "generations:\n")
      File.write(File.join(test_dir, 'scripts', 'prompts', 'chapter_prompts.txt'), "prompt template\n")
      File.write(File.join(test_dir, 'scripts', 'llm_config.yml'), "model: mock\n")
      File.write(File.join(test_dir, '_chapters', '001-chapter.md'), "---\ntitle: Chapter 1\n---\nContent\n")
      File.write(File.join(test_dir, '_characters', 'test_character.md'), "---\nname: Test Character\n---\nContent\n")
    end

    it 'calls the Translator for chapters' do
      # Mock the Translator to avoid actual LLM calls
      expect(Book::Translator).to receive(:new).with('gpt-4o').and_call_original
      # Stub the translate_chapter_with_ai method to prevent it from running
      expect_any_instance_of(Book::Translator).to receive(:translate_chapter_with_ai).with(1, 'ru')

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        Book::CLI::Runner.start(%w[translate chapter 1 ru --model gpt-4o])
      end
    end

    it 'calls the Translator for characters' do
      # Mock the Translator to avoid actual LLM calls
      expect(Book::Translator).to receive(:new).with('gpt-4o').and_call_original
      # Stub the translate_character_with_ai method to prevent it from running
      expect_any_instance_of(Book::Translator).to receive(:translate_character_with_ai).with('test_character', 'ru')

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        Book::CLI::Runner.start(%w[translate character test_character ru --model gpt-4o])
      end
    end

    it 'calls the Translator for all content' do
      # Mock the Translator to avoid actual LLM calls
      expect(Book::Translator).to receive(:new).with('gpt-4o').and_call_original
      # Stub the translate_all_content method to prevent it from running
      expect_any_instance_of(Book::Translator).to receive(:translate_all_content).with('ru')

      # Run the CLI command from within the temporary directory
      Dir.chdir(test_dir) do
        Book::CLI::Runner.start(%w[translate all ru --model gpt-4o])
      end
    end
  end
end
