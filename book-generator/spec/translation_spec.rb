# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tempfile'
require 'book/cli'
require 'book/translator'

RSpec.describe 'book translation' do
  let(:cli_path) { File.expand_path('../bin/book', __dir__) }
  let(:rubyopt_injector) { "-r#{File.expand_path('support/inject_mock_llm', __dir__)}" }
  let(:test_dir) { Dir.mktmpdir('book_cli_test') }

  after do
    FileUtils.rm_rf(test_dir)
  end

  describe 'integrated translation' do
    before do
      # Create the necessary directories and files in the temporary directory
      FileUtils.mkdir_p(File.join(test_dir, '_chapters'))
      FileUtils.mkdir_p(File.join(test_dir, 'data'))
      FileUtils.mkdir_p(File.join(test_dir, '_characters'))
      File.write(File.join(test_dir, 'data', 'book_metadata.yml'), "book:\n  current_chapter: 0\n")
      File.write(File.join(test_dir, 'data', 'characters.yml'), "characters:\n")
      File.write(File.join(test_dir, 'data', 'generation_log.yml'), "generations:\n")
      File.write(File.join(test_dir, 'data', 'settings.yml'), "llm:\n  model: mock\n")
      File.write(File.join(test_dir, '_chapters', '001-chapter.md'), "---\ntitle: Chapter 1\n---\nContent\n")
      File.write(File.join(test_dir, '_characters', 'test_character.md'), "---\nname: Test Character\n---\nContent\n")
    end

    it 'calls the Translator for chapters' do
      expect(Book::Translator).to receive(:new).and_call_original
      expect_any_instance_of(Book::Translator).to receive(:translate_chapter_with_ai).with(1, 'ru')

      Dir.chdir(test_dir) do
        { 'RUBYOPT' => rubyopt_injector }
        Book::CLI::Runner.start(%w[translate chapter 1 ru --model gpt-4o])
      end
    end

    it 'calls the Translator for characters' do
      expect(Book::Translator).to receive(:new).and_call_original
      expect_any_instance_of(Book::Translator).to receive(:translate_character_with_ai).with('test_character', 'ru')

      Dir.chdir(test_dir) do
        { 'RUBYOPT' => rubyopt_injector }
        Book::CLI::Runner.start(%w[translate character test_character ru --model gpt-4o])
      end
    end

    it 'calls the Translator for all content' do
      expect(Book::Translator).to receive(:new).and_call_original
      expect_any_instance_of(Book::Translator).to receive(:translate_all_content?).with('ru')

      Dir.chdir(test_dir) do
        { 'RUBYOPT' => rubyopt_injector }
        Book::CLI::Runner.start(%w[translate all ru --model gpt-4o])
      end
    end
  end
end
