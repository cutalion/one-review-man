# frozen_string_literal: true

# Regression canary for the `produce chapter --prompt "..."` flag:
# an earlier refactor dropped the `extra_guidance` threading, so the
# user's `--prompt` text never reached the LLM despite the flag being
# accepted.
#
# Feature: specs/013-spec-coverage-backfill (US3, T021)
#
# Strategy: drive the CLI in a subprocess with the mock LLM injected
# via RUBYOPT (set by spec_helper). The mock's subprocess-spy hook
# (EIDOS_SPEC_PROMPT_LOG) dumps every prompt string routed through
# the harness to a temp file; the spec reads it back and asserts the
# `--prompt` text appears verbatim in the captured chapter prompt.

require 'spec_helper'
require 'fileutils'
require 'open3'
require 'yaml'
require 'tempfile'

RSpec.describe 'produce chapter --prompt flag regression' do
  let(:cli_path) { File.expand_path('../../bin/produce', __dir__) }
  let(:guidance) { 'keep it under 3 sentences' }

  around(:each) do |example|
    Dir.mktmpdir('orm-013-prompt-flag-') do |tmpdir|
      @world_dir = tmpdir
      @prompt_log = File.join(tmpdir, 'prompt-log.txt')
      setup_fixture_world(tmpdir)
      example.run
    end
  end

  it 'threads --prompt text verbatim into the chapter-generation prompt' do
    env = { 'MOCK_AI' => 'true', 'EIDOS_SPEC_PROMPT_LOG' => @prompt_log }
    _, stderr, status = Open3.capture3(
      env, 'ruby', cli_path, 'chapter', '--auto', '-w', @world_dir, '--prompt', guidance
    )

    expect(status).to be_success, "produce chapter failed:\nSTDERR:\n#{stderr}"
    expect(File.exist?(@prompt_log)).to be(true), 'prompt log was not written by the subprocess mock'

    log = File.read(@prompt_log)
    chapter_prompt = extract_last_prompt(log, 'generate_chapter_structured')
    expect(chapter_prompt).not_to be_nil, "no generate_chapter_structured prompt in log:\n#{log}"
    expect(chapter_prompt).to include(guidance),
                              "expected --prompt text in captured prompt but got:\n#{chapter_prompt}"
  end

  def extract_last_prompt(log, method_name)
    matches = log.scan(/---PROMPT-BEGIN method=#{Regexp.escape(method_name)}---\n(.*?)\n---PROMPT-END---/m)
    matches.last&.first
  end

  def setup_fixture_world(root)
    FileUtils.mkdir_p(File.join(root, 'data'))
    FileUtils.mkdir_p(File.join(root, 'content', 'chapters'))
    FileUtils.mkdir_p(File.join(root, 'data', 'story_bible', 'characters'))

    File.write(
      File.join(root, 'data', 'world_config.yml'),
      {
        'generation' => { 'chapter_length_target' => '1500-3000 words' },
        'localized' => {
          'en' => {
            'story_title' => 'Fixture World', 'subtitle' => 'Integration fixture',
            'author' => 'Spec', 'story_genre' => 'comedy', 'story_style' => 'absurdist',
            'story_setting' => 'contemporary setting',
            'themes' => { 'primary' => 'adventure', 'secondary' => [] }
          }
        },
        'title' => 'Fixture World', 'author' => 'Spec',
        'description' => 'Integration fixture',
        'languages' => ['en'], 'default_language' => 'en'
      }.to_yaml
    )

    File.write(
      File.join(root, 'data', 'world_state.yml'),
      { 'world' => { 'current_chapter' => 0 }, 'status' => {} }.to_yaml
    )

    File.write(
      File.join(root, 'data', 'story_bible', 'characters', 'test_hero.yml'),
      { 'id' => 'test_hero', 'name' => 'Test Hero',
        'description' => 'Fixture protagonist.' }.to_yaml
    )
  end
end
