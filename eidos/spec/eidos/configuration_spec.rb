# frozen_string_literal: true

require 'spec_helper'
require 'eidos/configuration'
require 'fileutils'
require 'yaml'

RSpec.describe Eidos::Configuration do
  let(:project_root) { File.expand_path('../../tmp/config_test', __dir__) }
  let(:defaults_path) { Eidos::Configuration::DEFAULTS_PATH }
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
      expect(config['content']['model']).to eq('google/gemini-3-flash-preview')
      expect(config['summarization']['max_tokens']).to eq(2000)
    end

    it 'merges project settings over defaults' do
      settings = {
        'content' => {
          'model' => 'gpt-4-turbo'
        },
        'summarization' => {
          'max_tokens' => 500
        }
      }
      File.write(settings_path, settings.to_yaml)

      config = described_class.load(project_root)
      expect(config['content']['model']).to eq('gpt-4-turbo')
      expect(config['summarization']['max_tokens']).to eq(500)
      # Should still have defaults for other fields
      expect(config['llm']['temperature']).to eq(0.7)
    end

    it 'applies CLI overrides using dot notation' do
      cli_options = {
        'content.model' => 'cli-model',
        'summarization.max_tokens' => 100
      }
      
      config = described_class.load(project_root, cli_options)
      expect(config['content']['model']).to eq('cli-model')
      expect(config['summarization']['max_tokens']).to eq(100)
    end

    it 'maps summarization.model to summarization.model' do
      cli_options = { 'summarization.model' => 'sum-model' }
      config = described_class.load(project_root, cli_options)
      expect(config['summarization']['model']).to eq('sum-model')
    end

    it 'prioritizes CLI overrides over project settings' do
      settings = { 'llm' => { 'model' => 'project-model' } }
      File.write(settings_path, settings.to_yaml)

      cli_options = { 'llm.model' => 'cli-model' }

      config = described_class.load(project_root, cli_options)
      expect(config['llm']['model']).to eq('cli-model')
    end

    # T038 (feature 015 US1): a malformed project settings.yml used to
    # `warn "Failed to load project settings"` and silently fall through
    # to defaults — a textbook silent fallback that hid a broken LLM
    # config from the user. Now it raises ConfigurationError with the
    # file path, so the CLI surfaces the problem.
    it 'raises ConfigurationError when project settings.yml is malformed' do
      File.write(settings_path, "llm:\n  model: gpt-4\n  : bad yaml\n")

      expect { described_class.load(project_root) }
        .to raise_error(Eidos::Configuration::ConfigurationError, /settings\.yml/)
    end
  end
end
