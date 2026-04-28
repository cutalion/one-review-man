# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'stringio'
require 'eidos/cli/produce'

# T014 / US1 / feature 014-storyworld-pivot.
#
# Drives the Thor `Produce` router directly (not via subprocess) and
# confirms that both the legacy `produce chapter` path and the new
# `produce piece --form vignette --length 400 --prompt ...` path succeed
# under MOCK_AI=true. Spawning subprocesses is covered by the existing
# integration spec — this spec focuses on the Thor wiring.
RSpec.describe 'Eidos::CLI::Produce (014-storyworld-pivot)' do
  let(:tmp_dir) { Dir.mktmpdir('produce_cli_spec') }

  before { setup_world(tmp_dir) }
  after  { FileUtils.rm_rf(tmp_dir) }

  def setup_world(root)
    FileUtils.mkdir_p(File.join(root, 'data', 'story_bible'))
    FileUtils.mkdir_p(File.join(root, 'content', 'chapters'))

    File.write(File.join(root, 'data', 'world_config.yml'), <<~YAML)
      generation:
        chapter_length_target: "500-1000 words"
        main_characters: []
      localized:
        en:
          story_title: "Test World"
          author: "Test"
          story_genre: "comedy"
          story_style: "narrative"
    YAML
    File.write(File.join(root, 'data', 'world_state.yml'),
               "world:\n  current_chapter: 0\n  target_chapters: 10\n")
    File.write(File.join(root, 'data', 'settings.yml'),
               "llm:\n  provider: mock\n  model: mock\n")
    File.write(File.join(root, 'data', 'story_bible', 'facts.yml'), "facts: {}\n")
    File.write(File.join(root, 'data', 'story_bible', 'relationships.yml'), "relationships: []\n")
    File.write(File.join(root, 'data', 'story_bible', 'plot_threads.yml'), "plot_threads: []\n")
  end

  def capture_io
    real_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = real_stdout
  end

  describe 'produce chapter' do
    it 'generates a chapter file under content/chapters/ with MOCK_AI=true', :aggregate_failures do
      ENV['MOCK_AI'] = 'true'
      out = capture_io do
        Eidos::CLI::Produce.start(['chapter', '--auto', '-w', tmp_dir])
      end

      files = Dir.glob(File.join(tmp_dir, 'content', 'chapters', '*.md'))
      expect(files).not_to be_empty
      expect(File.basename(files.first)).to match(/\A\d{3}-chapter\.md\z/)
      expect(out).to include('Generating Chapter')
    end
  end

  describe 'produce piece --form vignette' do
    it 'generates a vignette under content/pieces/vignette/ with MOCK_AI=true', :aggregate_failures do
      ENV['MOCK_AI'] = 'true'
      capture_io do
        Eidos::CLI::Produce.start([
          'piece', '--form', 'vignette',
          '--length', '400',
          '--prompt', 'A quiet morning of job rejections.',
          '-w', tmp_dir
        ])
      end

      files = Dir.glob(File.join(tmp_dir, 'content', 'pieces', 'vignette', '*.md'))
      expect(files).not_to be_empty

      raw = File.read(files.first)
      fm = YAML.safe_load(raw.split(/^---\s*$/, 3)[1], permitted_classes: [Date, Symbol])
      expect(fm['form']).to eq('vignette')
      expect(fm['category']).to eq('text')
      expect(fm['canon_status']).to eq('applied')
    end
  end

  # T027 — short-form dispatch (US2).
  describe 'produce <form-name> short dispatch' do
    it 'dispatches `produce haiku` to `produce piece --form haiku` when haiku is registered' do
      ENV['MOCK_AI'] = 'true'
      capture_io do
        Eidos::CLI::Produce.start([
          'haiku', '--prompt', 'autumn rejection email', '-w', tmp_dir
        ])
      end

      files = Dir.glob(File.join(tmp_dir, 'content', 'pieces', 'haiku', '*.md'))
      expect(files).not_to be_empty
    end

    it 'does NOT dispatch short-form when the name is a reserved subcommand (chapter)' do
      ENV['MOCK_AI'] = 'true'
      # `produce chapter` must still route to the chapter subcommand, not to
      # a generic piece dispatch — preserves SC-002 byte-identical chapters.
      out = capture_io do
        Eidos::CLI::Produce.start(['chapter', '--auto', '-w', tmp_dir])
      end

      # Chapter subcommand path emits the "Generating Chapter" banner;
      # piece dispatch would emit "Generated haiku piece: …" style output.
      expect(out).to include('Generating Chapter')
      expect(Dir.glob(File.join(tmp_dir, 'content', 'chapters', '*.md'))).not_to be_empty
    end
  end

  # T028 — unknown form error (US2).
  describe 'produce <unknown-form>' do
    it 'exits 1 and lists available forms on stderr' do
      real_stderr = $stderr
      $stderr = StringIO.new
      begin
        expect do
          capture_io do
            Eidos::CLI::Produce.start([
              'piece', '--form', 'nonesuch',
              '--prompt', 'irrelevant', '-w', tmp_dir
            ])
          end
        end.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }

        stderr_text = $stderr.string
        expect(stderr_text).to match(/not registered/i).or match(/Available forms/i)
        expect(stderr_text).to include('haiku')
        expect(stderr_text).to include('chapter')
      ensure
        $stderr = real_stderr
      end
    end
  end
end
