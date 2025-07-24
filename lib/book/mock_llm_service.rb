# frozen_string_literal: true

require 'yaml'

class MockLLMService
  def initialize(config: nil, model_override: nil)
    # No-op
  end

  def generate_chapter_structured(prompt, options = {})
    {
      'title' => 'Mock Chapter Title',
      'content' => 'This is the mock chapter content.',
      'summary' => 'This is the mock chapter summary.',
      'new_characters' => [],
      'programming_themes' => ['mock'],
      'comedy_elements' => ['mock'],
      'word_count' => 10,
      'difficulty_level' => 'easy',
      'one_punch_man_references' => []
    }
  end

  def generate_character(prompt, options = {})
    {
      'name' => 'Mock Character',
      'description' => 'A mock character for testing.',
      'personality_traits' => ['mock'],
      'programming_skills' => 'mock',
      'catchphrase' => 'mock',
      'backstory' => 'mock',
      'quirks' => 'mock'
    }
  end
end
