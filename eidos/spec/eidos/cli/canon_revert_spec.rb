# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'eidos/cli/canon'
require 'eidos/audit_log'
require 'eidos/audit_finding'
require 'eidos/canon_delta'
require 'eidos/story_bible'

# T046 — US3 / feature 014-storyworld-pivot.
#
# Covers `eidos canon revert --finding ID`: non-destructive (piece file
# stays on disk), closes the finding, flips the piece frontmatter to
# canon_status: reverted.
RSpec.describe Eidos::CLI::Canon, 'canon revert' do
  let(:tmp_dir) { Dir.mktmpdir('canon_revert_spec') }
  let(:bible) { Eidos::StoryBible.new(project_root: tmp_dir) }
  let(:audit_log) { Eidos::AuditLog.new(world_path: tmp_dir) }

  before do
    FileUtils.mkdir_p(File.join(tmp_dir, 'data'))
    File.write(File.join(tmp_dir, 'data', 'world_config.yml'),
               { 'localized' => { 'en' => { 'title' => 'x' } } }.to_yaml)
    bible.setup

    FileUtils.mkdir_p(File.join(tmp_dir, 'content', 'pieces', 'vignette'))
    File.write(File.join(tmp_dir, 'content', 'pieces', 'vignette', 'VIG001.md'), <<~PIECE)
      ---
      id: VIG001
      form: vignette
      category: text
      generated_date: 2026-04-12
      canon_version: v2
      canon_status: applied
      length_measured: 400
      canon_delta_ref: THEDELTAID
      ---

      Body.
    PIECE
  end

  after { FileUtils.rm_rf(tmp_dir) }

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def apply_sample_delta
    raw = <<~TEXT
      The body.

      ---CANON-DELTA---
      new_characters:
        - id: brenda-20
          name: Brenda-20
          description: New AI character.
      new_locations: []
      new_facts: []
      new_events: []
      new_relationships: []
      entity_updates: []
    TEXT

    delta = Eidos::CanonDelta.parse(raw)
    delta.instance_variable_set(:@id, 'THEDELTAID')
    delta.apply!(
      bible: bible,
      audit_log: audit_log,
      canon_version_before: 'v1',
      canon_version_after: 'v2',
      piece_id: 'VIG001'
    )
    delta
  end

  it 'closes the finding, flips canon_status, leaves the file on disk' do
    apply_sample_delta
    # Open a synthetic finding attached to THEDELTAID piece VIG001
    finding = audit_log.append(Eidos::AuditFinding.open(
                                 kind: 'conflict',
                                 piece_id: 'VIG001',
                                 canon_delta_id: 'THEDELTAID',
                                 canon_version_before: 'v1',
                                 canon_version_after: 'v2',
                                 explanation: 'Collision.'
                               ))

    out = capture_stdout do
      described_class.start(['revert', '-w', tmp_dir, '--finding', finding.id])
    end

    expect(out).to match(/[Rr]everted/)
    expect(audit_log.find(finding.id).closed?).to be(true)
    expect(audit_log.find(finding.id).resolution).to eq('revert')

    piece_path = File.join(tmp_dir, 'content', 'pieces', 'vignette', 'VIG001.md')
    expect(File.exist?(piece_path)).to be(true)
    fm = YAML.safe_load(File.read(piece_path).split('---')[1], permitted_classes: [Date, Time])
    expect(fm['canon_status']).to eq('reverted')

    # Character was deleted
    expect(bible.get_character('brenda-20')).to be_nil
  end

  it 'exits 1 when the finding does not exist' do
    stderr = $stderr
    $stderr = StringIO.new
    expect do
      capture_stdout { described_class.start(['revert', '-w', tmp_dir, '--finding', 'NOPE']) }
    end.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
  ensure
    $stderr = stderr
  end

  it 'dry-run does not close the finding' do
    apply_sample_delta
    finding = audit_log.append(Eidos::AuditFinding.open(
                                 kind: 'conflict',
                                 piece_id: 'VIG001',
                                 canon_delta_id: 'THEDELTAID',
                                 canon_version_before: 'v1',
                                 canon_version_after: 'v2',
                                 explanation: 'Collision.'
                               ))

    out = capture_stdout do
      described_class.start(['revert', '-w', tmp_dir, '--finding', finding.id, '--dry-run'])
    end

    expect(out).to match(/dry/i)
    expect(audit_log.find(finding.id).open?).to be(true)
    # Character NOT deleted
    expect(bible.get_character('brenda-20')).not_to be_nil
  end
end
