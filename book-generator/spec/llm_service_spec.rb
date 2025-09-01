# frozen_string_literal: true

require 'spec_helper'
require 'book_core/llm_service'
require 'tempfile'
require 'yaml'

RSpec.describe BookCore::LLMService do
  let(:temp_settings_file) { Tempfile.new(['settings', '.yml']) }

  after do
    temp_settings_file.unlink
  end

  describe '#initialize' do
    context 'when settings.yml exists with llm configuration' do
      let(:llm_config) do
        {
          'llm' => {
            'provider' => 'openai',
            'model' => 'gpt-4',
            'temperature' => 0.5,
            'timeout' => 300,
            'default_options' => {
              'max_tokens' => 10_000
            },
            'task_options' => {
              'generation' => {
                'max_tokens' => 6000
              },
              'translation' => {
                'max_tokens' => 8000
              }
            }
          }
        }
      end

      before do
        temp_settings_file.write(llm_config.to_yaml)
        temp_settings_file.rewind
      end

      it 'loads configuration from the llm section' do
        service = described_class.new(temp_settings_file.path)

        # Test that the config was loaded correctly
        expect(service.send(:get_model_for_task, 'generation')).to eq('gpt-4')
        expect(service.send(:get_task_options, 'generation')[:max_tokens]).to eq(6000)
        expect(service.send(:get_task_options, 'translation')[:max_tokens]).to eq(8000)
      end

      it 'respects model override parameter' do
        service = described_class.new(temp_settings_file.path, 'gpt-4o-mini')
        expect(service.send(:get_model_for_task, 'generation')).to eq('gpt-4o-mini')
      end
    end

    context 'when settings.yml exists but has no llm section' do
      let(:non_llm_config) do
        {
          'other_config' => {
            'some_setting' => 'value'
          }
        }
      end

      before do
        temp_settings_file.write(non_llm_config.to_yaml)
        temp_settings_file.rewind
      end

      it 'falls back to default configuration' do
        service = described_class.new(temp_settings_file.path)

        # Should use default model
        expect(service.send(:get_model_for_task, 'generation')).to eq('gpt-4o-mini')
        # Should use default token limits
        expect(service.send(:get_task_options, 'generation')[:max_tokens]).to eq(8000)
        expect(service.send(:get_task_options, 'translation')[:max_tokens]).to eq(12_000)
      end
    end

    context 'when settings.yml does not exist' do
      let(:nonexistent_path) { '/tmp/nonexistent_settings.yml' }

      it 'falls back to default configuration' do
        service = described_class.new(nonexistent_path)

        # Should use default model
        expect(service.send(:get_model_for_task, 'generation')).to eq('gpt-4o-mini')
        # Should use default token limits
        expect(service.send(:get_task_options, 'generation')[:max_tokens]).to eq(8000)
        expect(service.send(:get_task_options, 'translation')[:max_tokens]).to eq(12_000)
      end
    end
  end

  describe 'task-specific configuration' do
    let(:llm_config) do
      {
        'llm' => {
          'models' => {
            'generation' => 'gpt-4',
            'translation' => 'gpt-4o-mini'
          },
          'task_options' => {
            'generation' => {
              'max_tokens' => 5000,
              'temperature' => 0.8
            },
            'translation' => {
              'max_tokens' => 15_000,
              'temperature' => 0.2
            }
          }
        }
      }
    end

    before do
      temp_settings_file.write(llm_config.to_yaml)
      temp_settings_file.rewind
    end

    it 'uses task-specific models when configured' do
      service = described_class.new(temp_settings_file.path)

      expect(service.send(:get_model_for_task, 'generation')).to eq('gpt-4')
      expect(service.send(:get_model_for_task, 'translation')).to eq('gpt-4o-mini')
    end

    it 'uses task-specific options when configured' do
      service = described_class.new(temp_settings_file.path)

      gen_options = service.send(:get_task_options, 'generation')
      expect(gen_options[:max_tokens]).to eq(5000)
      expect(gen_options[:temperature]).to eq(0.8)

      trans_options = service.send(:get_task_options, 'translation')
      expect(trans_options[:max_tokens]).to eq(15_000)
      expect(trans_options[:temperature]).to eq(0.2)
    end
  end

  describe 'mock mode' do
    it 'returns mock responses when MOCK_AI is enabled' do
      allow(BookCore::EnvUtils).to receive(:mock_ai_enabled?).and_return(true)

      service = described_class.new(temp_settings_file.path)
      result = service.generate_text(prompt: 'Test prompt', context: { chapter_number: 5 })

      expect(result).to eq('Mock chapter content for Chapter 5')
    end
  end
end
