# frozen_string_literal: true

require 'spec_helper'
require 'book_core/configuration'
require 'fileutils'
require 'yaml'

RSpec.describe BookCore::Configuration do
  let(:project_root) { File.expand_path('../../tmp/config_test', __dir__) }
  let(:defaults_path) { BookCore::Configuration::DEFAULTS_PATH }
  let(:settings_path) { File.join(project_root, 'data', 'settings.yml') }

  before do
    FileUtils.rm_rf(project_root)
    FileUtils.mkdir_p(File.join(project_root, 'data'))
  end

  after do
    FileUtils.rm_rf(project_root)
  end

  describe '.load' do
    it 'loads defaults when no project settings exist' do
      config = described_class.load(project_root)
      expect(config['llm']['model']).to eq('gpt-4o-mini')
      expect(config['llm']['task_options']['summarization']['max_tokens']).to eq(2000)
    end

    it 'merges project settings over defaults' do
      settings = {
        'llm' => {
          'model' => 'gpt-4-turbo',
          'task_options' => {
            'summarization' => { 'max_tokens' => 500 }
          }
        }
      }
      File.write(settings_path, settings.to_yaml)

      config = described_class.load(project_root)
      expect(config['llm']['model']).to eq('gpt-4-turbo')
      expect(config['llm']['task_options']['summarization']['max_tokens']).to eq(500)
      # Should still have defaults for other fields
      expect(config['llm']['temperature']).to eq(0.7)
    end

    it 'applies CLI overrides using dot notation' do
      cli_options = {
        'llm.model' => 'cli-model',
        'llm.task_options.summarization.max_tokens' => 100
      }
      
      config = described_class.load(project_root, cli_options)
      expect(config['llm']['model']).to eq('cli-model')
      expect(config['llm']['task_options']['summarization']['max_tokens']).to eq(100)
    end

    it 'prioritizes CLI overrides over project settings' do
      settings = { 'llm' => { 'model' => 'project-model' } }
      File.write(settings_path, settings.to_yaml)
      
      cli_options = { 'llm.model' => 'cli-model' }
      
      config = described_class.load(project_root, cli_options)
      expect(config['llm']['model']).to eq('cli-model')
    end
  end
end
