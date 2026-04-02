# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tempfile'
require 'eidos/cli/translate'

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
      File.write(File.join(test_dir, 'data', 'world_metadata.yml'), "book:\n  current_chapter: 0\n")
      File.write(File.join(test_dir, 'data', 'characters.yml'), "characters:\n")
      File.write(File.join(test_dir, 'data', 'generation_log.yml'), "generations:\n")
      File.write(File.join(test_dir, 'data', 'settings.yml'), "llm:\n  model: mock\n")
      File.write(File.join(test_dir, '_chapters', '001-chapter.md'), "---\ntitle: Chapter 1\n---\nContent\n")
      File.write(File.join(test_dir, '_characters', 'test_character.md'), "---\nname: Test Character\n---\nContent\n")
    end

    it 'calls the Translator for chapters' do
      expect(Eidos::Translator).to receive(:new).and_call_original
      expect_any_instance_of(Eidos::Translator).to receive(:translate_chapter_with_ai).with(1, 'ru')

      Dir.chdir(test_dir) do
        { 'RUBYOPT' => rubyopt_injector }
        Eidos::CLI::Translate.start(%w[chapter 1 ru --content-model gpt-4o])
      end
    end

    it 'calls the Translator for characters' do
      expect(Eidos::Translator).to receive(:new).and_call_original
      expect_any_instance_of(Eidos::Translator).to receive(:translate_character_with_ai).with('test_character', 'ru')

      Dir.chdir(test_dir) do
        { 'RUBYOPT' => rubyopt_injector }
        Eidos::CLI::Translate.start(%w[character test_character ru --content-model gpt-4o])
      end
    end

    it 'reports error when translating a non-existent chapter' do
      translator = Eidos::Translator.new(
        project_root: test_dir,
        config: Eidos::Configuration.load(test_dir, {})
      )

      # Chapter 99 does not exist
      expect { translator.translate_chapter_with_ai(99, 'ru') }.not_to raise_error
      result = translator.translate_chapter_with_ai(99, 'ru')
      expect(result).to eq(false)
    end

    it 'calls the Translator for all content' do
      expect(Eidos::Translator).to receive(:new).and_call_original
      expect_any_instance_of(Eidos::Translator).to receive(:translate_all_content?).with('ru')

      Dir.chdir(test_dir) do
        { 'RUBYOPT' => rubyopt_injector }
        Eidos::CLI::Translate.start(%w[all ru --content-model gpt-4o])
      end
    end
  end
end
