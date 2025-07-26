# frozen_string_literal: true

require 'spec_helper'
require 'book_core/chapter_generator'
require 'book/translator'

# Minimal mock that implements the subset of the LLMService API used by the
# classes under test.  We intentionally keep the surface area tiny – additional
# methods can be added later as needed by other specs.
class MockLLMService
  def generate_chapter_structured(_prompt, *_)
    {
      'title' => 'Mock Title',
      'summary' => 'Mock Summary',
      'content' => 'Mock Content'
    }
  end

  def improve_content(content, _improvement_type, *_)
    "#{content}\n(Improved)"
  end

  def translate_chapter_structured(title, summary, content, _target_lang, *_)
    {
      'title' => title,
      'summary' => summary,
      'content' => content
    }
  end

  def translate_character_structured(name, description, *_)
    {
      'name' => name,
      'description' => description,
      'personality_traits' => [],
      'programming_skills' => '',
      'catchphrase' => '',
      'backstory' => '',
      'quirks' => ''
    }
  end
end

RSpec.describe 'Dependency injection for core classes' do
  let(:mock_llm) { MockLLMService.new }
  let(:minimal_book_data) { { 'book' => { 'current_chapter' => 0 } } }
  let(:minimal_characters) { { 'characters' => {} } }

  describe BookCore::ChapterGenerator do
    it 'uses the injected LLM service instance' do
      generator = described_class.new(nil,
                                      llm_service: mock_llm,
                                      book_data: minimal_book_data,
                                      characters: minimal_characters,
                                      generation_log: {},
                                      prompt_provider: Class.new { def load(_); 'stub'; end }.new)

      expect(generator.instance_variable_get(:@llm_service)).to be(mock_llm)
    end
  end

  describe Book::Translator do
    it 'uses the injected LLM service instance' do
      translator = described_class.new(nil, llm_service: mock_llm)
      expect(translator.instance_variable_get(:@llm_service)).to be(mock_llm)
    end
  end
end 
