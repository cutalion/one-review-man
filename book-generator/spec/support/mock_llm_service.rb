# frozen_string_literal: true

# lib/test_support/mock_llm_service.rb
#
# Deterministic replacement for LLMService used in tests and validation scripts.
# It sources canned chapter responses from `test/support/mock_responses.yml` so that
# the test-suite and validation runs remain stable without network calls.

require 'yaml'

class MockLLMService
  RESPONSES_FILE = File.expand_path('../../../test/support/mock_responses.yml', __dir__)

  def initialize(*args)
    responses_file = args.first || RESPONSES_FILE
    @responses = File.exist?(responses_file) ? YAML.load_file(responses_file) : {}
  end

  # Simple text generation API (compatible subset)
  # @param prompt [String]
  # @param context [Hash]
  def generate_text(prompt:, context: {})
    chapter_num = extract_chapter_number(prompt) || context[:chapter_number] || '1'
    @responses["chapter_#{chapter_num}"] || 'Mock chapter content for testing'
  end

  # Structured chapter generation used by ChapterGenerator
  def generate_chapter_structured(_prompt, *_)
    {
      'title' => 'Mock Title',
      'summary' => 'Mock Summary',
      'content' => @responses['chapter_1'] || '# Heading\nMock content.',
      'new_characters' => []
    }
  end

  # Basic stubs for other API calls used in specs
  def improve_content(content, *_)
    "#{content}\n(Improved)"
  end

  def translate_chapter_structured(title, summary, content, *_)
    { 'title' => title, 'summary' => summary, 'content' => content }
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

  private

  def extract_chapter_number(prompt)
    prompt.to_s.match(/chapter\s*(\d+)/i)&.captures&.first
  end
end
