# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'stringio'
require 'eidos/chapter_generator'
require 'eidos/configuration'
require 'eidos/world_config'

# T011 / US1 / feature 014-storyworld-pivot.
#
# Locks the existing chapter frontmatter contract so the Phase 3 refactor
# (ChapterGenerator → PieceProducer delegation) cannot drift the wire
# format. SC-002: produce chapter output must be byte-compatible with
# pre-feature output — same directory, same filename pattern, same
# frontmatter key order.
RSpec.describe 'ChapterGenerator back-compat (014-storyworld-pivot)' do
  let(:tmp_dir) { Dir.mktmpdir('chapter_back_compat_spec') }

  after { FileUtils.rm_rf(tmp_dir) }

  def setup_world
    FileUtils.mkdir_p(File.join(tmp_dir, 'content', 'chapters'))
    FileUtils.mkdir_p(File.join(tmp_dir, 'data', 'story_bible'))

    File.write(File.join(tmp_dir, 'data', 'world_config.yml'), <<~YAML)
      generation:
        chapter_length_target: "500-1000 words"
        main_characters: []
      localized:
        en:
          title: "Test Book"
          author: "Test"
          genre: "Comedy"
          humor_style: "narrative"
    YAML
    File.write(File.join(tmp_dir, 'data', 'world_state.yml'),
               "book:\n  current_chapter: 0\n  target_chapters: 10\n")
    File.write(File.join(tmp_dir, 'data', 'settings.yml'),
               "llm:\n  model: mock\n")
    File.write(File.join(tmp_dir, 'data', 'story_bible', 'facts.yml'), "facts: {}\n")
    File.write(File.join(tmp_dir, 'data', 'story_bible', 'relationships.yml'), "relationships: []\n")
    File.write(File.join(tmp_dir, 'data', 'story_bible', 'plot_threads.yml'), "plot_threads: []\n")
  end

  def build_generator
    config = Eidos::WorldConfig.load_from_project(tmp_dir)
    configuration = Eidos::Configuration.load(tmp_dir, {})
    Eidos::ChapterGenerator.new(
      configuration: configuration,
      project_root: tmp_dir,
      book_config: config
    )
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def chapter_file
    Dir.glob(File.join(tmp_dir, 'content', 'chapters', '*.md')).first
  end

  def split_frontmatter
    raw = File.read(chapter_file)
    parts = raw.split(/^---\s*$/, 3)
    [parts[1], parts[2], raw]
  end

  def run_generator
    setup_world
    generator = build_generator
    llm = generator.instance_variable_get(:@llm_service)
    allow(llm).to receive(:generate_chapter_structured).and_return(
      'title' => 'The Rejection Letter',
      'summary' => 'Jax receives another form rejection.',
      'content' => ('word ' * 120).strip,
      'new_characters' => []
    )
    capture_stdout { generator.generate_next_chapter(auto_generate: true) }
  end

  it 'writes chapters to content/chapters/ with NNN-chapter.md filename' do
    run_generator

    expect(chapter_file).not_to be_nil
    expect(File.basename(chapter_file)).to eq('001-chapter.md')
    expect(File.dirname(chapter_file)).to eq(File.join(tmp_dir, 'content', 'chapters'))
  end

  it 'preserves the pre-feature frontmatter key order (SC-002)' do
    run_generator

    raw_frontmatter, _body, _full = split_frontmatter
    parsed = YAML.safe_load(raw_frontmatter, permitted_classes: [Date])

    expect(parsed.keys).to eq(%w[
      layout
      title
      chapter_number
      characters
      summary
      word_count
      permalink
      generated_date
      status
      lang
      new_characters
      canon_version
    ])
  end

  it 'preserves the pre-feature frontmatter values' do
    run_generator

    raw_frontmatter, _body, _full = split_frontmatter
    parsed = YAML.safe_load(raw_frontmatter, permitted_classes: [Date])

    expect(parsed['layout']).to eq('chapter')
    expect(parsed['title']).to eq('The Rejection Letter')
    expect(parsed['chapter_number']).to eq(1)
    expect(parsed['permalink']).to eq('/chapters/001-chapter/')
    expect(parsed['status']).to eq('generated')
    expect(parsed['lang']).to eq('en')
    expect(parsed['characters']).to eq([])
    expect(parsed['new_characters']).to eq([])
  end

  it 'separates frontmatter from body with the existing "---\n\n" sentinel' do
    run_generator

    _raw_frontmatter, body, full = split_frontmatter
    expect(full).to match(/\n---\n\n/)
    expect(body.strip).to eq(('word ' * 120).strip)
  end
end
