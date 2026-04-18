# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'eidos/canon_delta'
require 'eidos/audit_log'
require 'eidos/story_bible'

# T042 — US3 / feature 014-storyworld-pivot.
#
# CanonDelta#revert! writes a reverse revision, flips the owning piece's
# canon_status, leaves the piece file on disk, closes the originating
# finding with resolution: revert, and opens :orphaned-reference findings
# for any later pieces that referenced the rolled-back entities.
RSpec.describe Eidos::CanonDelta, '#revert!' do
  let(:tmp_dir) { Dir.mktmpdir('canon_delta_revert') }
  let(:bible) { Eidos::StoryBible.new(project_root: tmp_dir) }
  let(:audit_log) { Eidos::AuditLog.new(world_path: tmp_dir) }

  before { bible.setup }
  after  { FileUtils.rm_rf(tmp_dir) }

  def build_delta(char_hash: nil, update_hash: nil)
    sections = {
      'new_characters' => char_hash ? [char_hash] : [],
      'new_locations' => [],
      'new_facts' => [],
      'new_events' => [],
      'new_relationships' => [],
      'entity_updates' => update_hash ? [update_hash] : []
    }
    Eidos::CanonDelta.parse("Body.\n\n---CANON-DELTA---\n#{sections.to_yaml.sub(/^---\s*\n/, '')}")
  end

  it 'reverses new_characters insertions (deletes them)' do
    delta = build_delta(char_hash: { 'id' => 'kev-bot', 'name' => 'Kev-Bot' })
    delta.apply!(bible: bible, audit_log: audit_log,
                 canon_version_before: 'v0', canon_version_after: 'v1',
                 piece_id: '030')
    expect(bible.get_character('kev-bot')).not_to be_nil

    finding = audit_log.append(Eidos::AuditFinding.open(
      kind: 'conflict', piece_id: '030', canon_delta_id: delta.id,
      canon_version_before: 'v0', canon_version_after: 'v1',
      explanation: 'user-initiated revert'
    ))

    delta.revert!(bible: bible, audit_log: audit_log, finding: finding)

    expect(bible.get_character('kev-bot')).to be_nil
    expect(delta.reverted_at).not_to be_nil
    reloaded = audit_log.find(finding.id)
    expect(reloaded.status).to eq('closed')
    expect(reloaded.resolution).to eq('revert')
  end

  it 'restores old_value for entity_updates' do
    bible.save_character('brenda-20', { 'name' => 'Brenda', 'role' => 'AI recruiter' })
    delta = build_delta(update_hash: {
                          'entity_kind' => 'character',
                          'entity_id' => 'brenda-20',
                          'attribute' => 'role',
                          'old_value' => 'AI recruiter',
                          'new_value' => 'HR lambda'
                        })
    delta.apply!(bible: bible, audit_log: audit_log,
                 canon_version_before: 'v0', canon_version_after: 'v1',
                 piece_id: '031')
    expect(bible.get_character('brenda-20')['role']).to eq('HR lambda')

    finding = audit_log.append(Eidos::AuditFinding.open(
      kind: 'conflict', piece_id: '031', canon_delta_id: delta.id,
      canon_version_before: 'v0', canon_version_after: 'v1',
      explanation: 'restore old value'
    ))

    delta.revert!(bible: bible, audit_log: audit_log, finding: finding)
    expect(bible.get_character('brenda-20')['role']).to eq('AI recruiter')
  end

  it 'opens :orphaned-reference findings when later deltas referenced rolled-back entities' do
    first = build_delta(char_hash: { 'id' => 'kev-bot', 'name' => 'Kev-Bot' })
    first.apply!(bible: bible, audit_log: audit_log,
                 canon_version_before: 'v0', canon_version_after: 'v1',
                 piece_id: '040')

    later = build_delta(update_hash: {
                          'entity_kind' => 'character',
                          'entity_id' => 'kev-bot',
                          'attribute' => 'role',
                          'old_value' => nil,
                          'new_value' => 'lead'
                        })
    later.apply!(bible: bible, audit_log: audit_log,
                 canon_version_before: 'v1', canon_version_after: 'v2',
                 piece_id: '041')

    finding = audit_log.append(Eidos::AuditFinding.open(
      kind: 'conflict', piece_id: '040', canon_delta_id: first.id,
      canon_version_before: 'v0', canon_version_after: 'v1',
      explanation: 'revert first'
    ))

    first.revert!(bible: bible, audit_log: audit_log, finding: finding)

    orphans = audit_log.open.select { |f| f.kind == 'orphaned-reference' }
    expect(orphans.length).to eq(1)
    expect(orphans.first.piece_id).to eq('041')
  end
end
