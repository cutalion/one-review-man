# frozen_string_literal: true

# T053-T055 (feature 015 US6): `eidos world status` must describe a world
# in terms of the pieces on disk — not the old chapter-centric progress
# line and "Run: produce chapter" suggestion.
#
# Covers FR-017, FR-018 in specs/015-scaffold-hardening/spec.md and the
# output shape in contracts/cli-flags.md §"eidos world status".

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'eidos/cli/world'

RSpec.describe Eidos::CLI::World, 'US6 piece-first status' do
  let(:tmp_dir) { Dir.mktmpdir('world_status_piece_first_') }

  after { FileUtils.rm_rf(tmp_dir) if Dir.exist?(tmp_dir) }

  def seed_world(world_path, config_overrides: {})
    FileUtils.mkdir_p(File.join(world_path, 'data'))
    FileUtils.mkdir_p(File.join(world_path, 'content'))

    config = {
      'title' => 'Test World',
      'author' => 'Test Author',
      'description' => 'x',
      'subtitle' => 'x',
      'genre' => 'comedy',
      'humor_style' => 'deadpan',
      'setting' => 'office',
      'default_language' => 'en',
      'languages' => ['en'],
      'themes' => { 'primary' => 'disillusionment' }
    }.merge(config_overrides)

    File.write(File.join(world_path, 'data', 'world_config.yml'), config.to_yaml)
    File.write(File.join(world_path, 'data', 'world_state.yml'),
               { 'world' => { 'current_chapter' => 0 } }.to_yaml)
  end

  def write_piece(world_path, form, filename, body = "# Piece\n\nContent.\n")
    dir = File.join(world_path, 'content', 'pieces', form)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, filename), body)
  end

  def write_chapter(world_path, filename, body = "# Chapter\n\nContent.\n")
    dir = File.join(world_path, 'content', 'chapters')
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, filename), body)
  end

  def capture_status_output(world_path)
    original = $stdout
    $stdout = StringIO.new
    described_class.start(['status', '--world-dir', world_path])
    $stdout.string
  ensure
    $stdout = original
  end

  # ---- T053 --------------------------------------------------------------

  describe 'counts pieces by form (T053)' do
    it 'reports vignette: 2 and haiku: 1 when those files exist under content/pieces/' do
      seed_world(tmp_dir)
      write_piece(tmp_dir, 'vignette', 'a.md')
      write_piece(tmp_dir, 'vignette', 'b.md')
      write_piece(tmp_dir, 'haiku',    'c.md')

      output = capture_status_output(tmp_dir)

      aggregate_failures 'piece-first counts' do
        expect(output).to match(/vignette:\s*2/)
        expect(output).to match(/haiku:\s*1/)
        expect(output).to match(/Total:\s*3/)
      end
    end
  end

  # ---- T054 --------------------------------------------------------------

  describe 'empty world next-step hint (T054)' do
    it 'suggests a generic produce piece hint and never "Run: produce chapter"' do
      seed_world(tmp_dir)

      output = capture_status_output(tmp_dir)

      aggregate_failures 'generic piece hint, no chapter-only hint' do
        expect(output).to include('produce piece')
        expect(output).not_to match(/Run:\s*produce chapter/)
        expect(output).not_to match(/Ready for chapter generation/)
      end
    end
  end

  # ---- T055 --------------------------------------------------------------

  describe 'legacy chapter-only world (T055)' do
    it 'shows chapter: 1 in the counts table when content/chapters/ has one file' do
      seed_world(tmp_dir)
      write_chapter(tmp_dir, '001-chapter.md')

      output = capture_status_output(tmp_dir)

      aggregate_failures 'chapters still a valid form' do
        expect(output).to match(/chapter:\s*1/)
        expect(output).to match(/Total:\s*1/)
      end
    end
  end
end
