# frozen_string_literal: true

# IP-neutrality spec: a fresh non-ORM world produces chapter prompts
# that contain zero ORM vocabulary. Verifies SC-008 + FR-018.
#
# Strategy: scaffold a cooking-mystery world in a tmpdir, drive
# `produce chapter --auto -w <dir>` in a subprocess with
# EIDOS_SPEC_PROMPT_LOG set, read back every prompt routed through
# the harness, assert none match ORM-specific strings.
#
# Feature: specs/013-spec-coverage-backfill (US5, T039)

require 'spec_helper'
require 'fileutils'
require 'open3'
require 'yaml'

RSpec.describe 'IP-neutrality: non-ORM world produces clean prompts' do
  let(:cli_path) { File.expand_path('../../bin/produce', __dir__) }

  # Known ORM vocabulary that must NOT appear in prompts for a
  # non-ORM world. Character ids mirror
  # worlds/one-review-man/data/story_bible/characters/*.yml.
  ORM_VOCABULARY = [
    'One Review Man',
    'Ванревьюмэн',
    'programming comedy',
    'One-Punch Man',
    'Quantum Android',
    'agile_overlord', 'carlos_rivera', 'emily_chen', 'fiona_lee',
    'hiroshi_tanaka', 'jin_park', 'kai_nakamura', 'kenji_yamamoto',
    'lorenzo-takeda', 'lucas_hart'
  ].freeze

  around(:each) do |example|
    Dir.mktmpdir('orm-013-ip-neutrality-') do |tmpdir|
      @world_dir = tmpdir
      @prompt_log = File.join(tmpdir, 'prompt-log.txt')
      scaffold_cooking_mystery_world(tmpdir)
      example.run
    end
  end

  it 'generates a chapter prompt with zero ORM vocabulary' do
    env = { 'MOCK_AI' => 'true', 'EIDOS_SPEC_PROMPT_LOG' => @prompt_log }
    _, stderr, status = Open3.capture3(env, 'ruby', cli_path, 'chapter', '--auto', '-w', @world_dir)

    expect(status).to be_success, "produce chapter failed:\nSTDERR:\n#{stderr}"
    expect(File.exist?(@prompt_log)).to be(true), 'prompt log was not written by the subprocess mock'

    log = File.read(@prompt_log)
    expect(log).not_to be_empty, 'no prompts captured in log'

    aggregate_failures 'no ORM vocabulary in any captured prompt' do
      ORM_VOCABULARY.each do |term|
        expect(log).not_to include(term),
                          "ORM term #{term.inspect} leaked into a prompt for a non-ORM world"
      end
    end
  end

  def scaffold_cooking_mystery_world(root)
    FileUtils.mkdir_p(File.join(root, 'data'))
    FileUtils.mkdir_p(File.join(root, 'content', 'chapters'))
    FileUtils.mkdir_p(File.join(root, 'data', 'story_bible', 'characters'))

    File.write(
      File.join(root, 'data', 'world_config.yml'),
      {
        'generation' => { 'chapter_length_target' => '1500-3000 words' },
        'localized' => {
          'en' => {
            'story_title' => 'The Vanishing Chef',
            'subtitle' => 'A culinary whodunit',
            'author' => 'Integration Tester',
            'story_genre' => 'mystery',
            'story_style' => 'suspenseful',
            'story_setting' => 'boutique restaurant kitchen',
            'story_description' => 'A cozy culinary mystery set in a rainy coastal town.',
            'themes' => { 'primary' => 'discovery', 'secondary' => %w[loss obsession] }
          }
        },
        'languages' => ['en'],
        'default_language' => 'en'
      }.to_yaml
    )

    File.write(
      File.join(root, 'data', 'world_state.yml'),
      { 'world' => { 'current_chapter' => 0 }, 'status' => {},
        'canon' => { 'revision' => 0 } }.to_yaml
    )
    FileUtils.mkdir_p(File.join(root, 'data', 'canon_deltas'))

    File.write(
      File.join(root, 'data', 'story_bible', 'characters', 'chef_marin.yml'),
      {
        'id' => 'chef_marin',
        'name' => 'Chef Marin',
        'description' => 'Head chef of the boutique restaurant; fiercely protective of her recipes.',
        'personality_traits' => ['meticulous', 'private']
      }.to_yaml
    )
  end
end
