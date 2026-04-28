# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'eidos/audit_log'

# T043 — US3 / feature 014-storyworld-pivot.
#
# AuditLog append, close-in-place, and query semantics.
RSpec.describe Eidos::AuditLog do
  let(:tmp_dir) { Dir.mktmpdir('audit_log_spec') }
  let(:log) { described_class.new(world_path: tmp_dir) }

  after { FileUtils.rm_rf(tmp_dir) }

  def new_finding(kind: 'conflict', piece_id: '1', canon_delta_id: 'delta-x')
    Eidos::AuditFinding.open(
      kind: kind, piece_id: piece_id, canon_delta_id: canon_delta_id,
      canon_version_before: 'v1', canon_version_after: 'v2',
      explanation: "Test #{kind}"
    )
  end

  describe '#append' do
    it 'writes a finding to data/audit_log/findings.yml' do
      f = new_finding
      log.append(f)

      path = File.join(tmp_dir, 'data', 'audit_log', 'findings.yml')
      expect(File.exist?(path)).to be(true)
      raw = YAML.safe_load_file(path, permitted_classes: [Date, Time])
      expect(raw).to be_an(Array)
      expect(raw.length).to eq(1)
      expect(raw.first['id']).to eq(f.id)
    end

    it 'returns the persisted finding' do
      f = new_finding
      result = log.append(f)
      expect(result.id).to eq(f.id)
    end

    it 'appends multiple findings without clobbering' do
      log.append(new_finding(piece_id: '1'))
      log.append(new_finding(piece_id: '2'))
      log.append(new_finding(piece_id: '3'))
      expect(log.all.length).to eq(3)
    end
  end

  describe 'queries' do
    before do
      log.append(new_finding(kind: 'conflict', piece_id: '1'))
      log.append(new_finding(kind: 'malformed-delta', piece_id: '2'))
      log.append(new_finding(kind: 'conflict', piece_id: '3'))
    end

    it '#open returns only open findings' do
      ids = log.all.map(&:id)
      log.close(ids.first, resolution: 'revert')
      expect(log.open.length).to eq(2)
      expect(log.closed.length).to eq(1)
    end

    it '#by_piece filters by piece_id' do
      expect(log.by_piece('2').length).to eq(1)
      expect(log.by_piece('2').first.kind).to eq('malformed-delta')
    end

    it '#find returns a single finding by id or nil' do
      first = log.all.first
      expect(log.find(first.id).id).to eq(first.id)
      expect(log.find('nonexistent')).to be_nil
    end
  end

  describe '#close' do
    it 'rewrites the entry in place with resolved_at and resolution set' do
      f = log.append(new_finding)
      log.close(f.id, resolution: 'revert')

      reloaded = log.find(f.id)
      expect(reloaded.status).to eq('closed')
      expect(reloaded.resolution).to eq('revert')
      expect(reloaded.resolved_at).not_to be_nil
    end

    it 'is idempotent when closing an already-closed finding with the same resolution' do
      f = log.append(new_finding)
      log.close(f.id, resolution: 'revert')
      expect { log.close(f.id, resolution: 'revert') }.not_to raise_error
    end
  end

  describe 'empty state' do
    it '#all on a world with no findings returns empty array' do
      expect(log.all).to eq([])
    end

    it '#open on a world with no findings returns empty array' do
      expect(log.open).to eq([])
    end
  end
end
