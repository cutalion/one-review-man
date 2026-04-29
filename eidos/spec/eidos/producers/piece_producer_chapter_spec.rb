# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'eidos/producers/piece_producer'
require 'eidos/form_registry'
require 'eidos/audit_log'
require 'eidos/story_bible'

# Feature 018a — US1: chapter under the unified piece-producer contract.
# Verifies `specs/018-unify-piece-producer/contracts/chapter-piece-parity.md`.
RSpec.describe Eidos::Producers::PieceProducer, 'chapter form' do
  let(:tmp_dir) { Dir.mktmpdir('piece_producer_chapter') }
  let(:bible) { Eidos::StoryBible.new(project_root: tmp_dir) }
  let(:audit_log) { Eidos::AuditLog.new(world_path: tmp_dir) }
  let(:registry) { Eidos::FormRegistry.new }

  let(:structured_chapter) do
    {
      'title' => 'The First Chapter',
      'summary' => 'Arthur reviews his first PR.',
      'content' => 'Arthur sat down at his desk. ' * 50,
      'new_characters' => [
        { 'name' => 'Arthur', 'description' => 'A junior developer.' }
      ]
    }
  end

  let(:llm_service) do
    double('LLMService').tap do |s|
      allow(s).to receive(:generate_chapter_structured) { |*_| structured_chapter }
      allow(s).to receive(:generate_text) do |prompt:, **|
        "Body.\n\n---CANON-DELTA---\nnew_characters: []\nnew_locations: []\nnew_facts: []\nnew_events: []\nnew_relationships: []\nentity_updates: []\n"
      end
    end
  end

  let(:producer) do
    described_class.new(
      world_path: tmp_dir,
      llm_service: llm_service,
      form_registry: registry,
      bible: bible,
      audit_log: audit_log
    )
  end

  before do
    bible.setup
    scaffold_world_state(tmp_dir)
    FileUtils.mkdir_p(File.join(tmp_dir, 'content', 'chapters'))
  end
  after { FileUtils.rm_rf(tmp_dir) }

  def chapter_file
    Dir.glob(File.join(tmp_dir, 'content', 'chapters', '*.md')).first
  end

  def chapter_frontmatter
    raw = File.read(chapter_file)
    YAML.safe_load(raw.split(/^---\s*$/, 3)[1], permitted_classes: [Date, Symbol, Time])
  end

  it 'writes the universal frontmatter keys (id, form, generated_date, canon_version, canon_delta_ref)' do
    producer.produce(form: 'chapter', prompt: 'Open the story.')

    fm = chapter_frontmatter
    expect(fm['id']).to be_a(String)
    expect(fm['id']).to match(/\A[A-Z0-9]{20,30}\z/) # ULID-ish hash, NOT chapter number
    expect(fm['form']).to eq('chapter')
    expect(fm['generated_date']).not_to be_nil
    expect(fm['canon_version']).to be_a(Integer)
    expect(fm['canon_delta_ref']).to be_a(String)
    expect(fm['canon_delta_ref']).not_to be_empty
  end

  it 'writes the chapter-specific keys (title, summary, chapter_number)' do
    producer.produce(form: 'chapter', prompt: 'Open the story.')

    fm = chapter_frontmatter
    expect(fm['title']).to eq('The First Chapter')
    expect(fm['summary']).to eq('Arthur reviews his first PR.')
    expect(fm['chapter_number']).to eq(1)
  end

  it 'derives the on-disk filename from chapter_number, not id' do
    producer.produce(form: 'chapter', prompt: 'x')

    expect(chapter_file).to match(%r{content/chapters/\d{3}-chapter\.md\z})
    fm = chapter_frontmatter
    expect(fm['id']).not_to eq(fm['chapter_number'].to_s)
    expect(fm['id']).not_to match(/\A\d{3}\z/)
  end

  it 'writes a canon-delta file at data/canon_deltas/<id>.yml linked back to the piece' do
    producer.produce(form: 'chapter', prompt: 'x')

    fm = chapter_frontmatter
    delta_path = File.join(tmp_dir, 'data', 'canon_deltas', "#{fm['canon_delta_ref']}.yml")
    expect(File.exist?(delta_path)).to be true

    delta_data = YAML.safe_load_file(delta_path, permitted_classes: [Date, Time, Symbol])
    expect(delta_data['piece_id']).to eq(fm['id'])
  end

  it 'writes canon_version as an integer (post-018a)' do
    producer.produce(form: 'chapter', prompt: 'x')

    fm = chapter_frontmatter
    expect(fm['canon_version']).to be_a(Integer)
    expect(fm['canon_version']).to eq(1)
  end

  it 'auto-increments chapter_number across successive produces' do
    producer.produce(form: 'chapter', prompt: 'first')
    file1 = chapter_file
    producer.produce(form: 'chapter', prompt: 'second')

    files = Dir.glob(File.join(tmp_dir, 'content', 'chapters', '*.md')).sort
    expect(files.size).to eq(2)
    fm2 = YAML.safe_load(File.read(files.last).split(/^---\s*$/, 3)[1],
                         permitted_classes: [Date, Symbol, Time])
    expect(fm2['chapter_number']).to eq(2)
    expect(file1).to match(%r{001-chapter\.md\z})
    expect(files.last).to match(%r{002-chapter\.md\z})
  end

  describe 'parity with other forms' do
    it 'produces a chapter and a vignette with overlapping universal frontmatter keys' do
      producer.produce(form: 'chapter', prompt: 'x')
      producer.produce(form: 'vignette', prompt: 'y')

      chap_fm = chapter_frontmatter
      vig_file = Dir.glob(File.join(tmp_dir, 'content', 'pieces', 'vignette', '*.md')).first
      vig_fm = YAML.safe_load(File.read(vig_file).split(/^---\s*$/, 3)[1],
                              permitted_classes: [Date, Symbol, Time])

      universal_keys = %w[id form generated_date canon_version canon_delta_ref]
      universal_keys.each do |key|
        expect(chap_fm).to have_key(key), "chapter missing universal key: #{key}"
        expect(vig_fm).to have_key(key), "vignette missing universal key: #{key}"
      end

      # Vignette MUST NOT carry chapter-specific keys.
      %w[title summary chapter_number].each do |chapter_key|
        next if chapter_key == 'title' && vig_fm.key?('title') # vignette form may extract its own title

        expect(vig_fm).not_to have_key('chapter_number'),
                              "vignette unexpectedly has chapter_number"
      end
    end
  end

  describe 'malformed-JSON failure mode' do
    it 'opens a parse-drop AuditFinding and writes no file when the LLM returns non-JSON' do
      bad_llm = double('LLMService')
      allow(bad_llm).to receive(:generate_chapter_structured) do |*_|
        raise Eidos::LLMService::LLMError, 'malformed envelope: not valid JSON'
      end
      bad_producer = described_class.new(
        world_path: tmp_dir,
        llm_service: bad_llm,
        form_registry: registry,
        bible: bible,
        audit_log: audit_log
      )

      revision_before = Eidos::WorldState.new(world_path: tmp_dir).current_revision

      expect {
        bad_producer.produce(form: 'chapter', prompt: 'x')
      }.to raise_error(StandardError)

      # No piece file written.
      expect(Dir.glob(File.join(tmp_dir, 'content', 'chapters', '*.md'))).to be_empty
      # No canon delta file written.
      expect(Dir.glob(File.join(tmp_dir, 'data', 'canon_deltas', '*.yml'))).to be_empty
      # Revision counter unchanged.
      expect(Eidos::WorldState.new(world_path: tmp_dir).current_revision).to eq(revision_before)
      # One parse-drop / malformed-delta finding opened.
      findings = audit_log.all
      expect(findings.size).to be >= 1
      expect(findings.map(&:kind)).to include('parse-drop').or include('malformed-delta')
    end
  end
end
