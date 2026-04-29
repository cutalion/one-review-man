# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'eidos/canon_delta'
require 'eidos/audit_log'
require 'eidos/story_bible'

# T039 / T040 / T041 — US3 / feature 014-storyworld-pivot.
#
# CanonDelta#apply! is transactional, optimistic on conflicts, and safe
# on parse errors.
RSpec.describe Eidos::CanonDelta, '#apply!' do
  let(:tmp_dir) { Dir.mktmpdir('canon_delta_apply') }
  let(:bible) { Eidos::StoryBible.new(project_root: tmp_dir) }
  let(:audit_log) { Eidos::AuditLog.new(world_path: tmp_dir) }

  before do
    bible.setup
    scaffold_world_state(tmp_dir)
  end
  after  { FileUtils.rm_rf(tmp_dir) }

  def parse(text)
    Eidos::CanonDelta.parse(text)
  end

  def well_formed_with(char_hash: nil, location_hash: nil, update_hash: nil)
    sections = {
      'new_characters' => char_hash ? [char_hash] : [],
      'new_locations' => location_hash ? [location_hash] : [],
      'new_facts' => [],
      'new_events' => [],
      'new_relationships' => [],
      'entity_updates' => update_hash ? [update_hash] : []
    }
    "Body.\n\n---CANON-DELTA---\n#{sections.to_yaml.sub(/^---\s*\n/, '')}"
  end

  describe 'clean delta' do
    it 'inserts new_characters into the bible' do
      delta = parse(well_formed_with(char_hash: { 'id' => 'arthur', 'name' => 'Arthur' }))
      delta.apply!(bible: bible, audit_log: audit_log,
                   canon_version_before: 'v0', canon_version_after: 'v1',
                   piece_id: '001')

      expect(bible.get_character('arthur')).not_to be_nil
      expect(bible.get_character('arthur')['name']).to eq('Arthur')
      expect(audit_log.all).to be_empty
      expect(delta.applied_at).not_to be_nil
    end

    it 'inserts new_locations into the bible' do
      delta = parse(well_formed_with(location_hash: { 'id' => 'cubicle', 'name' => 'The Cubicle' }))
      delta.apply!(bible: bible, audit_log: audit_log,
                   canon_version_before: 'v0', canon_version_after: 'v1',
                   piece_id: '001')
      expect(bible.get_location('cubicle')['name']).to eq('The Cubicle')
    end
  end

  describe 'transactional behavior' do
    it 'is all-or-none: one failure rolls back earlier inserts' do
      bad_delta = parse(well_formed_with(
        char_hash: { 'id' => 'arthur', 'name' => 'Arthur' }
      ))
      # Inject a failure by sabotaging the bible mid-apply.
      allow(bible).to receive(:save_location).and_raise(RuntimeError, 'boom')
      bad_delta_with_loc = parse(well_formed_with(
        char_hash: { 'id' => 'arthur', 'name' => 'Arthur' },
        location_hash: { 'id' => 'cubicle', 'name' => 'Cubicle' }
      ))

      expect {
        bad_delta_with_loc.apply!(bible: bible, audit_log: audit_log,
                                  canon_version_before: 'v0', canon_version_after: 'v1',
                                  piece_id: '001')
      }.to raise_error(RuntimeError, /boom/)

      expect(bible.get_character('arthur')).to be_nil
      expect(bad_delta.applied_at).to be_nil
    end
  end

  describe 'conflict detection (optimistic)' do
    it 'opens a :conflict finding when entity_update old_value mismatches but still applies' do
      bible.save_character('brenda-20', { 'name' => 'Brenda', 'role' => 'AI recruiter' })

      delta = parse(well_formed_with(
        update_hash: {
          'entity_kind' => 'character',
          'entity_id' => 'brenda-20',
          'attribute' => 'role',
          'old_value' => 'WRONG VALUE',
          'new_value' => 'HR lambda'
        }
      ))

      delta.apply!(bible: bible, audit_log: audit_log,
                   canon_version_before: 'v0', canon_version_after: 'v1',
                   piece_id: '017')

      expect(bible.get_character('brenda-20')['role']).to eq('HR lambda')
      conflicts = audit_log.open.select { |f| f.kind == 'conflict' }
      expect(conflicts.length).to eq(1)
      expect(conflicts.first.piece_id).to eq('017')
    end

    it 'opens a :conflict finding when inserting a character that already exists with different attrs' do
      bible.save_character('brenda-20', { 'name' => 'Brenda', 'role' => 'AI recruiter' })

      delta = parse(well_formed_with(
        char_hash: { 'id' => 'brenda-20', 'name' => 'Brenda', 'role' => 'HR lambda' }
      ))

      delta.apply!(bible: bible, audit_log: audit_log,
                   canon_version_before: 'v0', canon_version_after: 'v1',
                   piece_id: '018')

      expect(bible.get_character('brenda-20')['role']).to eq('HR lambda')
      expect(audit_log.open.any? { |f| f.kind == 'conflict' }).to be(true)
    end
  end

  describe 'malformed-delta handling' do
    it 'opens a :malformed-delta finding and does not change canon when parse_error is set' do
      delta = parse("Body only, no sentinel.")
      expect(delta.parse_error).not_to be_nil

      delta.apply!(bible: bible, audit_log: audit_log,
                   canon_version_before: 'v0', canon_version_after: 'v0',
                   piece_id: '019')

      findings = audit_log.open
      expect(findings.length).to eq(1)
      expect(findings.first.kind).to eq('malformed-delta')
      expect(findings.first.canon_version_before).to eq(findings.first.canon_version_after)
      expect(bible.characters).to be_empty
    end
  end

  describe 'persistence' do
    it 'writes the delta to data/canon_deltas/<id>.yml after successful apply' do
      delta = parse(well_formed_with(char_hash: { 'id' => 'arthur', 'name' => 'Arthur' }))
      delta.apply!(bible: bible, audit_log: audit_log,
                   canon_version_before: 'v0', canon_version_after: 'v1',
                   piece_id: '020')

      path = File.join(tmp_dir, 'data', 'canon_deltas', "#{delta.id}.yml")
      expect(File.exist?(path)).to be(true)

      raw = YAML.safe_load_file(path, permitted_classes: [Date, Time])
      expect(raw['piece_id']).to eq('020')
      expect(raw['applied_at']).not_to be_nil
      expect(raw['new_characters'].first['id']).to eq('arthur')
    end
  end
end
