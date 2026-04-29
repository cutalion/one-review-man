# frozen_string_literal: true

# Regression canary for the "{CHAPTER_NUMBER} leak" incident:
# an earlier change left CHAPTER_NUMBER out of the chapter-placeholder
# hash, which triggered "Unused placeholders" warnings during prompt
# construction and occasionally leaked `{CHAPTER_NUMBER}` tokens into
# written chapter files.
#
# Feature: specs/013-spec-coverage-backfill (US3, T020)
#
# Reinforces US1's runtime harness at the CLI layer — the harness
# inside the subprocess would already raise on an unfilled token, but
# this spec pins the CLI entry point end-to-end so a regression that
# slips past unit specs still trips a canary.

require 'spec_helper'
require 'fileutils'
require 'open3'
require 'yaml'

RSpec.describe 'produce chapter regression: CHAPTER_NUMBER placeholder' do
  let(:cli_path) { File.expand_path('../../bin/produce', __dir__) }

  around(:each) do |example|
    Dir.mktmpdir('orm-013-chapter-number-') do |tmpdir|
      @world_dir = tmpdir
      setup_fixture_world(tmpdir)
      example.run
    end
  end

  it 'does not emit "Unused placeholders" warnings and writes no raw {CHAPTER_NUMBER} tokens' do
    env = { 'MOCK_AI' => 'true' }
    stdout, stderr, status = Open3.capture3(env, 'ruby', cli_path, 'chapter', '--auto', '-w', @world_dir)

    aggregate_failures do
      expect(status).to be_success, "produce chapter failed:\nSTDOUT:\n#{stdout}\nSTDERR:\n#{stderr}"
      expect(stderr).not_to include('Unused placeholders'), "stderr leaked:\n#{stderr}"

      chapters_dir = File.join(@world_dir, 'content', 'chapters')
      generated = Dir.glob(File.join(chapters_dir, '*.md'))
      expect(generated).not_to be_empty, "no chapter file was written under #{chapters_dir}"

      generated.each do |path|
        content = File.read(path)
        expect(content).not_to include('{CHAPTER_NUMBER}'),  "single-brace leak in #{path}"
        expect(content).not_to include('{{CHAPTER_NUMBER}}'), "double-brace leak in #{path}"
      end
    end
  end

  def setup_fixture_world(root)
    FileUtils.mkdir_p(File.join(root, 'data'))
    FileUtils.mkdir_p(File.join(root, 'content', 'chapters'))
    FileUtils.mkdir_p(File.join(root, 'data', 'story_bible', 'characters'))

    # Minimal split config — enough for WorldConfig to resolve title/genre/etc.
    File.write(
      File.join(root, 'data', 'world_config.yml'),
      {
        'generation' => {
          'chapter_length_target' => '1500-3000 words',
          'complexity_level' => 'medium',
          'character_consistency' => true
        },
        'localized' => {
          'en' => {
            'story_title' => 'Fixture World',
            'subtitle' => 'Integration fixture',
            'author' => 'Spec',
            'story_genre' => 'comedy',
            'story_style' => 'absurdist',
            'story_setting' => 'contemporary setting',
            'themes' => { 'primary' => 'adventure', 'secondary' => [] }
          }
        },
        'title' => 'Fixture World',
        'author' => 'Spec',
        'description' => 'Integration fixture',
        'languages' => ['en'],
        'default_language' => 'en'
      }.to_yaml
    )

    File.write(
      File.join(root, 'data', 'world_state.yml'),
      {
        'world' => { 'current_chapter' => 0 },
        'status' => { 'last_generated' => '', 'generation_count' => 0 },
        'canon' => { 'revision' => 0 }
      }.to_yaml
    )
    FileUtils.mkdir_p(File.join(root, 'data', 'canon_deltas'))

    # A newly-created character so the chapter prompt's {CHARACTER_CONTEXT}
    # section receives a non-empty roster (matches US3 independent-test premise).
    File.write(
      File.join(root, 'data', 'story_bible', 'characters', 'test_hero.yml'),
      {
        'id' => 'test_hero',
        'name' => 'Test Hero',
        'description' => 'A placeholder protagonist created by the fixture.',
        'personality_traits' => ['brave'],
        'programming_skills' => 'Ruby'
      }.to_yaml
    )
  end
end
