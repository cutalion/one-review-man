# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require 'book_core/prompt_provider'

RSpec.describe BookCore::PromptProvider do
  describe '#load' do
    it 'prefers book-level prompt over core prompt' do
      Dir.mktmpdir do |dir|
        book_prompts_dir = File.join(dir, 'prompts')
        FileUtils.mkdir_p(book_prompts_dir)
        File.write(File.join(book_prompts_dir, 'chapter_prompts.txt'), 'Book-level content')

        provider = described_class.new(book_root: dir)
        expect(provider.load('chapter_prompts.txt')).to eq('Book-level content')
      end
    end

    it 'falls back to core prompt when not found in book' do
      Dir.mktmpdir do |dir|
        provider = described_class.new(book_root: dir)
        prompt_name = 'consistency_improvement_prompt.txt'
        expected_content = File.read(File.join(BookCore::PromptProvider::CORE_PROMPTS_PATH, prompt_name))
        actual_content = provider.load(prompt_name)
        expect(actual_content).to eq(expected_content)
      end
    end

    it 'raises when prompt cannot be found in any location' do
      Dir.mktmpdir do |dir|
        provider = described_class.new(book_root: dir)
        expect { provider.load('nonexistent_prompt.txt') }.to raise_error(RuntimeError, /Prompt template not found/)
      end
    end
  end
end 
