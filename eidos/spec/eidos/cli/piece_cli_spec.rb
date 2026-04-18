# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'stringio'
require 'yaml'
require 'eidos/cli/piece_cli'

# T024 / US1 / feature 014-storyworld-pivot.
#
# Exercises `eidos piece list` and `eidos piece show` against a fixture
# world that contains one legacy chapter file and one new piece file.
RSpec.describe Eidos::CLI::PieceCli do
  let(:tmp_dir) { Dir.mktmpdir('piece_cli_spec') }

  before do
    FileUtils.mkdir_p(File.join(tmp_dir, 'data'))
    FileUtils.mkdir_p(File.join(tmp_dir, 'content', 'chapters'))
    FileUtils.mkdir_p(File.join(tmp_dir, 'content', 'pieces', 'vignette'))

    File.write(File.join(tmp_dir, 'data', 'world_config.yml'), <<~YAML)
      localized:
        en:
          story_title: "Test World"
          author: "Test"
    YAML

    File.write(
      File.join(tmp_dir, 'content', 'chapters', '001-chapter.md'),
      <<~CHAPTER
        ---
        layout: chapter
        title: Chapter 1
        chapter_number: 1
        characters: []
        summary: A test chapter.
        word_count: 120
        permalink: /chapters/001-chapter/
        generated_date: 2026-04-10
        status: generated
        lang: en
        new_characters: []
        canon_version: v1
        ---

        Chapter body text.
      CHAPTER
    )

    File.write(
      File.join(tmp_dir, 'content', 'pieces', 'vignette', 'VIGNETTE001.md'),
      <<~PIECE
        ---
        id: VIGNETTE001
        form: vignette
        category: text
        generated_date: 2026-04-12
        canon_version: v2
        canon_status: applied
        length_measured: 400
        ---

        Vignette body.
      PIECE
    )
  end

  after { FileUtils.rm_rf(tmp_dir) }

  def capture_stdout
    real = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = real
  end

  describe 'piece list' do
    it 'lists both chapter and vignette pieces' do
      out = capture_stdout do
        described_class.start(['list', '-w', tmp_dir])
      end

      expect(out).to include('Pieces (2)')
      expect(out).to include('chapter')
      expect(out).to include('vignette')
      expect(out).to include('VIGNETTE001')
    end

    it 'filters by form name' do
      out = capture_stdout do
        described_class.start(['list', '--form', 'vignette', '-w', tmp_dir])
      end

      expect(out).to include('Pieces (1)')
      expect(out).to include('vignette')
      expect(out).not_to include('chapter')
    end

    it 'prints a friendly message when there are no matches' do
      out = capture_stdout do
        described_class.start(['list', '--form', 'haiku', '-w', tmp_dir])
      end

      expect(out).to include('No pieces found')
    end
  end

  describe 'piece show' do
    it 'surfaces piece details for a vignette' do
      out = capture_stdout do
        described_class.start(['show', 'VIGNETTE001', '-w', tmp_dir])
      end

      expect(out).to include('VIGNETTE001')
      expect(out).to include('form=vignette')
      expect(out).to include('applied')
      expect(out).to include('v2')
    end

    it 'surfaces the chapter piece by its NNN id' do
      out = capture_stdout do
        described_class.start(['show', '1', '-w', tmp_dir])
      end

      expect(out).to include('form=chapter')
      expect(out).to include('v1')
    end

    it 'exits 1 with a friendly error for an unknown id' do
      real_stderr = $stderr
      $stderr = StringIO.new
      begin
        expect do
          capture_stdout { described_class.start(['show', 'NOPE', '-w', tmp_dir]) }
        end.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      ensure
        $stderr = real_stderr
      end
    end
  end
end
