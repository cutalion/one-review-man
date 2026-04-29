# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'eidos/canon_delta'
require 'eidos/audit_log'
require 'eidos/story_bible'
require 'eidos/world_state'

# Feature 018a — US2: canon-revision atomicity contract.
#
# Verifies that `CanonDelta#apply!` advances `canon.revision` by exactly 1
# on success, and leaves it untouched on failure (with bible rolled back).
# See `specs/018-unify-piece-producer/contracts/canon-revision-atomicity.md`.
RSpec.describe Eidos::CanonDelta, '#apply! atomicity' do
  let(:tmp_dir) { Dir.mktmpdir('canon_atom_spec') }
  let(:state_path) { File.join(tmp_dir, 'data', 'world_state.yml') }
  let(:bible) { Eidos::StoryBible.new(project_root: tmp_dir) }
  let(:audit_log) { Eidos::AuditLog.new(world_path: tmp_dir) }

  before do
    FileUtils.mkdir_p(File.join(tmp_dir, 'data', 'canon_deltas'))
    File.write(state_path, { 'canon' => { 'revision' => 7 } }.to_yaml)
    bible.setup
  end
  after { FileUtils.rm_rf(tmp_dir) }

  def parse_delta(char_id: 'arthur', char_name: 'Arthur')
    sections = {
      'new_characters' => [{ 'id' => char_id, 'name' => char_name }],
      'new_locations' => [],
      'new_facts' => [],
      'new_events' => [],
      'new_relationships' => [],
      'entity_updates' => []
    }
    raw = "Body.\n\n---CANON-DELTA---\n#{sections.to_yaml.sub(/^---\s*\n/, '')}"
    Eidos::CanonDelta.parse(raw)
  end

  def revision_on_disk
    YAML.safe_load_file(state_path).dig('canon', 'revision')
  end

  describe 'successful apply' do
    it 'advances canon.revision by exactly 1' do
      delta = parse_delta

      expect {
        delta.apply!(bible: bible, audit_log: audit_log,
                     canon_version_before: 7, canon_version_after: 8,
                     piece_id: 'p1', world_path: tmp_dir)
      }.to change { revision_on_disk }.from(7).to(8)

      expect(bible.get_character('arthur')).not_to be_nil
    end
  end

  describe 'apply raises mid-bible-mutation' do
    it 'leaves canon.revision unchanged and rolls back the bible' do
      allow(bible).to receive(:save_character).and_raise(RuntimeError, 'boom')
      delta = parse_delta

      expect {
        delta.apply!(bible: bible, audit_log: audit_log,
                     canon_version_before: 7, canon_version_after: 8,
                     piece_id: 'p1', world_path: tmp_dir)
      }.to raise_error(RuntimeError, /boom/)

      expect(revision_on_disk).to eq(7)
    end
  end

  describe 'apply raises in advance_revision! itself' do
    it 'leaves canon.revision unchanged and rolls back the bible' do
      delta = parse_delta
      ws = instance_double(Eidos::WorldState)
      allow(Eidos::WorldState).to receive(:new).and_return(ws)
      allow(ws).to receive(:advance_revision!).and_raise(Errno::EACCES.new('disk full'))

      expect {
        delta.apply!(bible: bible, audit_log: audit_log,
                     canon_version_before: 7, canon_version_after: 8,
                     piece_id: 'p1', world_path: tmp_dir,
                     world_state: ws)
      }.to raise_error(Errno::EACCES)

      expect(revision_on_disk).to eq(7)
      # Bible rolled back — character should NOT be present.
      expect(bible.get_character('arthur')).to be_nil
    end
  end

  describe 'world_state injection' do
    it 'accepts an injected world_state and uses it for advance' do
      ws_double = instance_double(Eidos::WorldState)
      allow(ws_double).to receive(:advance_revision!).and_return(99)
      delta = parse_delta

      delta.apply!(bible: bible, audit_log: audit_log,
                   canon_version_before: 7, canon_version_after: 99,
                   piece_id: 'p1', world_path: tmp_dir,
                   world_state: ws_double)

      expect(ws_double).to have_received(:advance_revision!).once
    end
  end

  describe 'integrated with PieceProducer (FR-010 — integer canon_version on piece)' do
    require 'eidos/producers/piece_producer'

    let(:llm_service) do
      Class.new do
        def generate_text(prompt:)
          "A short vignette body.\n\n---CANON-DELTA---\nnew_characters: []\nnew_locations: []\nnew_facts: []\nnew_events: []\nnew_relationships: []\nentity_updates: []\n"
        end
      end.new
    end

    it 'writes the new revision into the piece frontmatter as an integer' do
      # Need a minimal world structure for the producer to write into.
      FileUtils.mkdir_p(File.join(tmp_dir, 'content', 'pieces', 'vignette'))
      FileUtils.mkdir_p(File.join(tmp_dir, 'data'))
      File.write(File.join(tmp_dir, 'data', 'world_state.yml'),
                 { 'canon' => { 'revision' => 0 } }.to_yaml)
      File.write(File.join(tmp_dir, 'data', 'world_config.yml'),
                 { 'world' => { 'current_chapter' => 0 } }.to_yaml)

      producer = Eidos::Producers::PieceProducer.new(
        world_path: tmp_dir,
        llm_service: llm_service,
        bible: bible,
        audit_log: audit_log
      )
      piece = producer.produce(form: 'vignette', prompt: 'Test.', length: nil)

      file = Dir.glob(File.join(tmp_dir, 'content', 'pieces', 'vignette', '*.md')).first
      expect(file).not_to be_nil
      front = YAML.safe_load_file(file, permitted_classes: [Date, Time, Symbol])
      expect(front['canon_version']).to be_a(Integer)
      expect(front['canon_version']).to eq(1)
      expect(piece.id).to be_a(String)
    end
  end
end
