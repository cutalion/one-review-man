# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tempfile'
require 'book/cli/version'

RSpec.describe 'book generate command' do
  let(:cli_path) { File.expand_path('../bin/book', __dir__) }
  let(:rubyopt_injector) { "-r#{File.expand_path('support/inject_mock_llm', __dir__)}" }
  
  around(:each) do |example|
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        example.run
      end
    end
  end

  def setup_book_structure
    FileUtils.mkdir_p('content/chapters')
    FileUtils.mkdir_p('data')
    File.write(File.join('data', 'book_config.yml'), "---\n")
    File.write(File.join('data', 'book_state.yml'), "book:\n  current_chapter: 0\n")
  end

  it 'responds to chapter generation' do
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

    it 'accepts --model option' do
      env = { 'RUBYOPT' => rubyopt_injector, 'MOCK_AI' => 'true' }
      stdout, _stderr, status = Open3.capture3(env, 'ruby', cli_path, 'generate', 'chapter', '1', '--model', 'gpt-4o', '--auto')
      expect(status).to be_success
      expect(stdout).to include('gpt-4o')
    end

    context 'when generating illustrations' do
      before do
        File.write('content/chapters/001-chapter.md', 'This is a chapter with anchor text.')
      end

      it 'embeds illustration with --anchor' do
        env = { 'RUBYOPT' => rubyopt_injector, 'MOCK_AI' => 'true' }
        stdout, stderr, status = Open3.capture3(env, 'ruby', cli_path, 'generate', 'illustration', '1', 'a test prompt', '--anchor', 'anchor text')

        expect(status).to be_success
        expect(stderr).to be_empty
        expect(stdout).to include('Illustration embedded in chapter 1')
      end

      it 'prints markdown tag without --anchor' do
        env = { 'RUBYOPT' => rubyopt_injector, 'MOCK_AI' => 'true' }
        stdout, stderr, status = Open3.capture3(env, 'ruby', cli_path, 'generate', 'illustration', '1', 'a test prompt')

        expect(status).to be_success
        expect(stderr).to be_empty
        expect(stdout).to include('![[illustration:')
      end
    end
  end
end
