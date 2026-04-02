# frozen_string_literal: true

require 'spec_helper'
require 'eidos/cli/version'
require 'yaml'
require 'tmpdir'

RSpec.describe 'world CLI' do
  let(:cli_path) { File.expand_path('../bin/world', __dir__) }

  it 'prints version with --version' do
    stdout, stderr, status = Open3.capture3('ruby', cli_path, 'version')
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(stdout.strip).to eq(Eidos::CLI::VERSION)
  end

  it 'shows help for new command' do
    stdout, stderr, status = Open3.capture3('ruby', cli_path, 'help', 'new')
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(stdout).to include('Initialize a new world project')
    expect(stdout).to include('--world-dir')
    expect(stdout).to include('--quick')
  end

  it 'recognizes new as a command' do
    stdout, _, status = Open3.capture3('ruby', cli_path, 'help', 'new')
    expect(status).to be_success
    expect(stdout).to include('Initialize a new world project')
  end

  context 'when initializing a new world' do
    let(:test_dir) { Dir.mktmpdir('world_init_test') }

    after do
      FileUtils.rm_rf(test_dir)
    end

    it 'creates settings.yml with default LLM configuration' do
      stdin_data = "Test Book\nTest Author\nA test book\nen\nen\n"
      stdout, stderr, status = Open3.capture3('ruby', cli_path, 'new', '--world-dir', test_dir, '--quick', stdin_data: stdin_data)

      expect(status).to be_success
      expect(stderr).to be_empty
      expect(stdout).to include('Initialised world at:')

      settings_path = File.join(test_dir, 'data', 'settings.yml')
      expect(File.exist?(settings_path)).to be true

      settings = YAML.load_file(settings_path)
      expect(settings['llm']).to be_a(Hash)
      expect(settings['llm']['provider']).to eq('openai')
      expect(settings['content']['model']).to eq('gpt-4o-mini')
      expect(settings['summarization']['model']).to eq('gpt-5-nano')
      expect(settings['llm']['temperature']).to eq(0.7)
      expect(settings['llm']['timeout']).to eq(240)
      expect(settings['llm']['default_options']['max_tokens']).to eq(12_000)
      expect(settings['llm']['task_options']['generation']['max_tokens']).to eq(8000)
      expect(settings['llm']['task_options']['translation']['max_tokens']).to eq(12_000)

      expect(settings['llm']['retry']['max_attempts']).to eq(3)
      expect(settings['llm']['strict_model']).to eq(true)
    end

    it 'creates all required data files' do
      stdin_data = "Test Book\nTest Author\nA test book\nen\nen\n"
      _, _, status = Open3.capture3('ruby', cli_path, 'new', '--world-dir', test_dir, '--quick', stdin_data: stdin_data)

      expect(status).to be_success

      expected_files = [
        'data/world_config.yml',
        'data/world_state.yml',
        'data/characters.yml',
        'data/generation_log.yml',
        'data/world.yml',
        'data/strings.yml',
        'data/settings.yml'
      ]

      expected_files.each do |file_path|
        full_path = File.join(test_dir, file_path)
        expect(File.exist?(full_path)).to be(true), "Expected #{file_path} to exist"
      end

      expect(Dir.exist?(File.join(test_dir, 'content', 'chapters'))).to be true
      expect(Dir.exist?(File.join(test_dir, 'content', 'characters'))).to be true
    end
  end
end
