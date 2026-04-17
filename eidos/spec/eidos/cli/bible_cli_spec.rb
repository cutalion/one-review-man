# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'fileutils'
require 'eidos/cli/bible'
require 'eidos/story_bible'

RSpec.describe Eidos::CLI::Bible do
  # Covers T033 / US3 / feature 012-fix-ux-unify-bible: a character with
  # origin: "seed" renders with a "(seed)" marker in `bible list characters`.

  let(:tmp_dir) { Dir.mktmpdir('bible_cli_spec') }

  after { FileUtils.rm_rf(tmp_dir) }

  before do
    FileUtils.mkdir_p(File.join(tmp_dir, 'data'))
    File.write(File.join(tmp_dir, 'data', 'world_config.yml'), { 'localized' => { 'en' => { 'title' => 'x' } } }.to_yaml)

    bible = Eidos::StoryBible.new(project_root: tmp_dir)
    bible.setup
    bible.save_character('jax_patel', {
                           'id' => 'jax_patel',
                           'name' => 'Jax Patel',
                           'description' => 'A laid-off backend engineer.',
                           'origin' => 'seed',
                           'origin_note' => 'derived from premise'
                         })
    bible.save_character('kenji_yamamoto', {
                           'id' => 'kenji_yamamoto',
                           'name' => 'Kenji Yamamoto',
                           'description' => 'A seasoned architect.'
                         })
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  it 'appends a (seed) marker to seeded characters in `bible list characters`' do
    output = capture_stdout do
      described_class.start(['list', 'characters', '--world-dir', tmp_dir])
    end

    expect(output).to match(/Jax Patel.*\(seed\)/)
    expect(output).to match(/Kenji Yamamoto/)
    expect(output).not_to match(/Kenji Yamamoto.*\(seed\)/)
  end
end
