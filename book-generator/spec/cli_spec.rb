# frozen_string_literal: true

require 'spec_helper'
require 'book/cli/version'
require 'yaml'
require 'tmpdir'

RSpec.describe 'book CLI' do
  let(:cli_path) { File.expand_path('../bin/book', __dir__) }

  it 'prints version with --version' do
    stdout, stderr, status = Open3.capture3('ruby', cli_path, '--version')
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(stdout.strip).to eq(Book::CLI::VERSION)
  end

  it 'shows help for init command' do
    stdout, stderr, status = Open3.capture3('ruby', cli_path, 'help', 'init')
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(stdout).to include('Initialize a new book project')
    expect(stdout).to include('--book-dir')
    expect(stdout).to include('--quick')
  end

  it 'recognizes init as a direct command' do
    # Test that init command is recognized by checking the help mentions it
    stdout, _, status = Open3.capture3('ruby', cli_path, 'help', 'init')
    expect(status).to be_success
    expect(stdout).to include('Initialize a new book project')
  end

  context 'when initializing a new book project' do
    let(:test_dir) { Dir.mktmpdir('book_init_test') }

    after do
      FileUtils.rm_rf(test_dir)
    end

    it 'creates settings.yml with default LLM configuration' do
      # Run init with piped inputs to avoid interactive prompts
      stdin_data = "Test Book\nTest Author\nA test book\nen\nen\n"
      stdout, stderr, status = Open3.capture3('ruby', cli_path, 'init', '--book-dir', test_dir, '--quick', stdin_data: stdin_data)

      expect(status).to be_success
      expect(stderr).to be_empty
      expect(stdout).to include('Initialised book at:')

      # Check that settings.yml was created
      settings_path = File.join(test_dir, 'data', 'settings.yml')
      expect(File.exist?(settings_path)).to be true

      # Check settings content
      settings = YAML.load_file(settings_path)
      expect(settings['llm']).to be_a(Hash)
      expect(settings['llm']['provider']).to eq('openai')
      expect(settings['llm']['model']).to eq('gpt-4o-mini')
      expect(settings['llm']['temperature']).to eq(0.7)
      expect(settings['llm']['timeout']).to eq(240)
      expect(settings['llm']['default_options']['max_tokens']).to eq(12_000)
      expect(settings['llm']['task_options']['generation']['max_tokens']).to eq(8000)
      expect(settings['llm']['task_options']['translation']['max_tokens']).to eq(12_000)
    end

    it 'creates all required data files' do
      stdin_data = "Test Book\nTest Author\nA test book\nen\nen\n"
      _, _, status = Open3.capture3('ruby', cli_path, 'init', '--book-dir', test_dir, '--quick', stdin_data: stdin_data)

      expect(status).to be_success

      # Check all expected files exist
      expected_files = [
        'data/book_metadata.yml',
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

      # Check directory structure
      expect(Dir.exist?(File.join(test_dir, 'content', 'chapters'))).to be true
      expect(Dir.exist?(File.join(test_dir, 'content', 'characters'))).to be true
    end
  end
end
