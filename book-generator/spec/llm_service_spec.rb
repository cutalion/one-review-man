# frozen_string_literal: true

require 'spec_helper'
require 'book_core/llm_service'

RSpec.describe BookCore::LLMService do
  let(:base_config) do
    {
      'llm' => {
        'provider' => 'openai',
        'model' => 'gpt-4o-mini',
        'temperature' => 0.7,
        'timeout' => 240,
        'default_options' => { 'max_tokens' => 1000 },
        'task_options' => {
          'generation' => { 'max_tokens' => 2000 },
          'summarization' => { 'max_tokens' => 500 }
        },
        'models' => {
          'summarization' => 'gpt-5-nano'
        }
      }
    }
  end

  let(:service) { described_class.new(base_config) }

  describe '#initialize' do
    it 'initializes with valid config' do
      expect { described_class.new(base_config) }.not_to raise_error
    end

    it 'handles empty config gracefully' do
      service = described_class.new({})
      expect(service.get_model_for_task('generation')).to be_nil
    end
  end

  describe '#get_model_for_task' do
    it 'uses task-specific model from config' do
      expect(service.get_model_for_task('summarization')).to eq('gpt-5-nano')
    end

    it 'falls back to default model if no task specific model' do
      expect(service.get_model_for_task('generation')).to eq('gpt-4o-mini')
    end

    it 'returns nil if no model configured' do
      service = described_class.new({})
      expect(service.get_model_for_task('generation')).to be_nil
    end
  end

  describe '#get_task_options' do
    it 'merges task specific options with defaults' do
      options = service.send(:get_task_options, 'generation')
      expect(options[:max_tokens]).to eq(2000)
    end

    it 'uses default options when no task specific options' do
      options = service.send(:get_task_options, 'unknown_task')
      expect(options[:max_tokens]).to eq(1000)
    end
  end

  describe 'mock mode' do
    it 'returns mock responses when MOCK_AI is enabled' do
      allow(BookCore::EnvUtils).to receive(:mock_ai_enabled?).and_return(true)

      result = service.generate_text(prompt: 'Test prompt', context: { chapter_number: 5 })
      expect(result).to eq('Mock chapter content for Chapter 5')
    end
  end

  describe '#generate_character' do
    it 'returns a character profile with physical appearance' do
      allow(BookCore::EnvUtils).to receive(:mock_ai_enabled?).and_return(true)
      
      result = service.generate_character('Test Character')

      expect(result).to have_key('physical_appearance')
      expect(result['physical_appearance']).to be_a(Hash)
    end
  end
end
