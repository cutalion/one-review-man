# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'json'
require 'eidos/cli/canon'
require 'eidos/audit_log'
require 'eidos/audit_finding'

# T045 — US3 / feature 014-storyworld-pivot.
#
# Covers `eidos canon review`: clean-world case, text/json formats,
# `--status` and `--kind` filters.
RSpec.describe Eidos::CLI::Canon, 'canon review' do
  let(:tmp_dir) { Dir.mktmpdir('canon_review_spec') }

  before do
    FileUtils.mkdir_p(File.join(tmp_dir, 'data'))
    File.write(File.join(tmp_dir, 'data', 'world_config.yml'),
               { 'localized' => { 'en' => { 'title' => 'x' } } }.to_yaml)
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

  def seed_findings(audit_log)
    audit_log.append(Eidos::AuditFinding.open(
                       kind: 'conflict',
                       piece_id: '017',
                       canon_delta_id: '01ABCDEF123456789AAAAAAA',
                       canon_version_before: 'v42',
                       canon_version_after: 'v43',
                       explanation: 'Piece 017 collided with canon on brenda-20.'
                     ))
    audit_log.append(Eidos::AuditFinding.open(
                       kind: 'malformed-delta',
                       piece_id: '018',
                       canon_delta_id: '01ABCDEF123456789BBBBBBB',
                       canon_version_before: 'v43',
                       canon_version_after: 'v43',
                       explanation: 'Delta could not be parsed: missing sentinel.'
                     ))
  end

  it 'prints "0 findings" and exits 0 on a clean world' do
    out = capture_stdout do
      described_class.start(['review', '-w', tmp_dir])
    end

    expect(out).to include('0 findings')
  end

  it 'lists open findings in text format by default' do
    audit_log = Eidos::AuditLog.new(world_path: tmp_dir)
    seed_findings(audit_log)

    out = capture_stdout do
      described_class.start(['review', '-w', tmp_dir])
    end

    expect(out).to include('[conflict]')
    expect(out).to include('[malformed-delta]')
    expect(out).to include('Piece: 017')
    expect(out).to include('OPEN')
    expect(out).to include('canon revert')
    expect(out).to include('canon accept')
    expect(out).to include('canon patch')
  end

  it 'filters by --kind' do
    audit_log = Eidos::AuditLog.new(world_path: tmp_dir)
    seed_findings(audit_log)

    out = capture_stdout do
      described_class.start(['review', '-w', tmp_dir, '--kind', 'conflict'])
    end

    expect(out).to include('[conflict]')
    expect(out).not_to include('[malformed-delta]')
  end

  it 'filters by --piece' do
    audit_log = Eidos::AuditLog.new(world_path: tmp_dir)
    seed_findings(audit_log)

    out = capture_stdout do
      described_class.start(['review', '-w', tmp_dir, '--piece', '018'])
    end

    expect(out).to include('Piece: 018')
    expect(out).not_to include('Piece: 017')
  end

  it 'emits JSON array with --format json' do
    audit_log = Eidos::AuditLog.new(world_path: tmp_dir)
    seed_findings(audit_log)

    out = capture_stdout do
      described_class.start(['review', '-w', tmp_dir, '--format', 'json'])
    end

    data = JSON.parse(out)
    expect(data).to be_an(Array)
    expect(data.length).to eq(2)
    expect(data.first.keys).to include('id', 'kind', 'status', 'piece_id')
  end

  it 'honors --status closed' do
    audit_log = Eidos::AuditLog.new(world_path: tmp_dir)
    seed_findings(audit_log)
    # Close one
    first_id = audit_log.all.first.id
    audit_log.close(first_id, resolution: 'accept')

    out = capture_stdout do
      described_class.start(['review', '-w', tmp_dir, '--status', 'closed'])
    end

    expect(out).to include('CLOSED')
    expect(out).to include('via accept')
  end
end
