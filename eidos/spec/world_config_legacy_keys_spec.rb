# frozen_string_literal: true

# Back-compat contract for the BOOK→STORY placeholder migration.
# Contract: specs/013-spec-coverage-backfill/contracts/story-placeholder-compat.md

require 'spec_helper'
require 'eidos/world_config'
require 'fileutils'
require 'tmpdir'
require 'yaml'

RSpec.describe Eidos::WorldConfig, 'BOOK→STORY back-compat read path' do
  around(:each) do |example|
    Dir.mktmpdir('orm-013-legacy-keys-') do |tmpdir|
      @dir = tmpdir
      FileUtils.mkdir_p(File.join(tmpdir, 'data'))
      Eidos::WorldConfig.send(:class_variable_set, :@@emitted_deprecation_notices, {})
      example.run
    end
  end

  def write_config(localized_en)
    path = File.join(@dir, 'data', 'world_config.yml')
    File.write(path, { 'localized' => { 'en' => localized_en } }.to_yaml)
    File.write(File.join(@dir, 'data', 'world_state.yml'), {}.to_yaml)
    Eidos::WorldConfig.load_from_project(@dir)
  end

  it 'reads a bare `title:` as story_title with one deprecation notice' do
    config = write_config('title' => 'Legacy Bare Title')

    expect { expect(config.story_title).to eq('Legacy Bare Title') }
      .to output(/DEPRECATED.*legacy `title` key/).to_stderr
  end

  it 'reads a `book_title:` as story_title with one deprecation notice' do
    config = write_config('book_title' => 'Legacy Book Title')

    expect { expect(config.story_title).to eq('Legacy Book Title') }
      .to output(/DEPRECATED.*legacy `book_title` key/).to_stderr
  end

  it 'prefers story_title when both book_title and story_title are present' do
    config = write_config('book_title' => 'Old', 'story_title' => 'New')

    expect { expect(config.story_title).to eq('New') }.not_to output.to_stderr
  end

  it 'emits the deprecation notice at most once per (config, locale, field) per process' do
    config = write_config('title' => 'Legacy Bare Title')

    expect { 3.times { config.story_title } }
      .to output(/DEPRECATED.*legacy `title` key/).to_stderr

    output = capture_stderr { 2.times { config.story_title } }
    expect(output).to eq('')
  end

  it 'does not emit any notice for a freshly-scaffolded world' do
    # Simulate a future writer that emits only story_* keys.
    config = write_config(
      'story_title'   => 'Clean Title',
      'story_genre'   => 'comedy',
      'story_setting' => 'office',
      'story_style'   => 'absurdist'
    )

    expect do
      config.story_title
      config.story_genre
      config.story_setting
      config.story_style
    end.not_to output.to_stderr
  end

  def capture_stderr
    original = $stderr
    io = StringIO.new
    $stderr = io
    yield
    io.string
  ensure
    $stderr = original
  end
end
