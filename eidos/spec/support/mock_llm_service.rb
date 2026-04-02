# frozen_string_literal: true

# lib/test_support/mock_llm_service.rb
#
# Deterministic replacement for LLMService used in tests and validation scripts.
# It sources canned chapter responses from `test/support/mock_responses.yml` so that
# the test-suite and validation runs remain stable without network calls.

require 'yaml'

class MockLLMService
  RESPONSES_FILE = File.expand_path('mock_responses.yml', __dir__)

  def initialize(config_or_path = nil, *args)
    if config_or_path.is_a?(Hash)
      @config = config_or_path['llm'] || {}
      @settings = config_or_path
      responses_file = RESPONSES_FILE
    else
      @config = {}
      @settings = {}
      responses_file = config_or_path || RESPONSES_FILE
    end
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

  def get_model_for_task(task_type)
    if @settings && @settings['content'] && @settings['content']['model']
      @settings['content']['model']
    else
      @config['model'] || 'mock-model'
    end
  end

  def resolve_image_options(provider: nil, model: nil, style: nil, size: nil, orientation: nil)
    illustration_config = (@settings && @settings['illustration']) || {}
    
    # Use explicit args, then illustration config, then hardcoded fallbacks
    provider ||= illustration_config['provider'] || 'openai'
    model ||= illustration_config['model'] || 'dall-e-3'
    style ||= illustration_config['style'] || 'vivid'
    
    # Resolve size from orientation if size is not explicit
    unless size
      orientation ||= illustration_config['orientation']
      size = resolve_default_size(orientation) || '1024x1024'
    end

    {
      provider: provider,
      model: model,
      style: style,
      size: size,
      orientation: orientation
    }
  end

  def resolve_default_size(orientation)
    case orientation.to_s.downcase
    when 'portrait'
      '1024x1792'
    when 'landscape'
      '1792x1024'
    else
      '1024x1024' # square
    end
  end

  def generate_image(prompt, size: nil, quality: 'standard', style: nil, model: nil, provider: nil)
    'https://placehold.co/1024x1024/png?text=Mock+Image'
  end

  private

  def extract_chapter_number(prompt)
    prompt.to_s.match(/chapter\s*(\d+)/i)&.captures&.first
  end
end
