# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tempfile'
require 'eidos/cli/version'

RSpec.describe 'produce command' do
  let(:cli_path) { File.expand_path('../bin/produce', __dir__) }
  let(:rubyopt_injector) { "-r#{File.expand_path('support/inject_mock_llm', __dir__)}" }

  # Run each test in a fresh temporary directory
  around(:each) do |example|
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        example.run
      end
    end
  end

  def setup_world_structure
    FileUtils.mkdir_p('_chapters')
    FileUtils.mkdir_p('data')
    FileUtils.mkdir_p(File.join('data', 'canon_deltas'))
    FileUtils.mkdir_p(File.join('content', 'chapters'))
    # Post-018a: scaffolds carry world_config.yml + world_state.yml with
    # canon.revision = 0; legacy world_metadata.yml is no longer the
    # primary marker (see feature 012).
    File.write(File.join('data', 'world_config.yml'),
               { 'world' => { 'current_chapter' => 0 },
                 'localized' => { 'en' => { 'story_title' => 'Test',
                                            'story_genre' => 'comedy',
                                            'story_style' => 'narrative',
                                            'story_setting' => 'office' } } }.to_yaml)
    File.write(File.join('data', 'world_state.yml'),
               { 'world' => { 'current_chapter' => 0 },
                 'canon' => { 'revision' => 0 } }.to_yaml)
    File.write(File.join('data', 'world_metadata.yml'), "book:\n  current_chapter: 0\n")
  end

  it 'responds to chapter generation' do
    # Test in empty directory (should fail because not a world directory)
    _, stderr, status = Open3.capture3('ruby', cli_path, 'chapter', '1')
    expect(status).not_to be_success
    expect(stderr).to include('world directory')
  end

  it 'responds to prompt stub' do
    stdout, stderr, status = Open3.capture3('ruby', cli_path, 'prompt', '2')
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(stdout).to include('prompt stub for chapter')
  end

  context 'in a valid world directory' do
    before { setup_world_structure }

    it 'supports --auto flag' do
      env = { 'RUBYOPT' => rubyopt_injector, 'MOCK_AI' => 'true' }
      _, stderr, status = Open3.capture3(env, 'ruby', cli_path, 'chapter', '--auto')
      expect(status).to be_success
      expect(stderr).to be_empty
    end

    it 'accepts --content-model option' do
      env = { 'RUBYOPT' => rubyopt_injector, 'MOCK_AI' => 'true' }
      stdout, _stderr, status = Open3.capture3(env, 'ruby', cli_path, 'chapter', '1', '--content-model', 'gpt-4o', '--auto')
      # Post-018a: the chapter handler accepts --content-model as an LLM
      # config override; success is signalled by writing a chapter file +
      # the "Generated Chapter N: <title>" banner. The model name is no
      # longer echoed (the legacy ChapterGenerator's "using model X" log
      # is gone with the class).
      expect(status).to be_success
      expect(stdout).to match(/Generated Chapter \d+/)
    end
  end
end
