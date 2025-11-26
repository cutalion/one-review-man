# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tempfile'
require 'book/cli/version'

RSpec.describe 'book generate command' do
  let(:cli_path) { File.expand_path('../bin/book', __dir__) }
  let(:rubyopt_injector) { "-r#{File.expand_path('support/inject_mock_llm', __dir__)}" }
  
  # Run each test in a fresh temporary directory
  around(:each) do |example|
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        example.run
      end
    end
  end

  def setup_book_structure
    FileUtils.mkdir_p('_chapters')
    FileUtils.mkdir_p('data')
    File.write(File.join('data', 'book_metadata.yml'), "book:\n  current_chapter: 0\n")
  end

  it 'responds to chapter generation' do
    # Test in empty directory (should fail because not a book directory)
    _, stderr, status = Open3.capture3('ruby', cli_path, 'generate', 'chapter', '1')
    expect(status).not_to be_success
    expect(stderr).to include('book directory')
  end

  it 'responds to prompt stub' do
    stdout, stderr, status = Open3.capture3('ruby', cli_path, 'generate', 'prompt', '2')
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(stdout).to include('prompt stub for chapter')
  end

  context 'in a valid book directory' do
    before { setup_book_structure }

    it 'supports --auto flag' do
      env = { 'RUBYOPT' => rubyopt_injector, 'MOCK_AI' => 'true' }
      _, stderr, status = Open3.capture3(env, 'ruby', cli_path, 'generate', 'chapter', '--auto')
      expect(status).to be_success
      expect(stderr).to be_empty
    end

    it 'accepts --content-model option' do
      env = { 'RUBYOPT' => rubyopt_injector, 'MOCK_AI' => 'true' }
      stdout, stderr, status = Open3.capture3(env, 'ruby', cli_path, 'generate', 'chapter', '1', '--content-model', 'gpt-4o', '--auto')
      expect(status).to be_success
      expect(stdout).to include('gpt-4o')
    end
  end
end
