# frozen_string_literal: true

require 'spec_helper'
require 'eidos/audit_finding'

# T044 — US3 / feature 014-storyworld-pivot.
#
# AuditFinding YAML round-trip with every field populated.
RSpec.describe Eidos::AuditFinding do
  describe '.open factory' do
    it 'creates a finding with status=open, nil resolution/resolved_at' do
      f = described_class.open(
        kind: 'conflict',
        piece_id: '017',
        canon_delta_id: '01ABCDEF',
        canon_version_before: 'v42',
        canon_version_after: 'v43',
        explanation: 'test conflict'
      )
      expect(f.status).to eq('open')
      expect(f.resolution).to be_nil
      expect(f.resolved_at).to be_nil
      expect(f.id).not_to be_nil
      expect(f.created_at).not_to be_nil
    end
  end

  describe 'YAML round-trip' do
    it 'serializes all fields and restores them' do
      original = described_class.open(
        kind: 'conflict',
        piece_id: '017',
        canon_delta_id: '01HBQDELTA',
        canon_version_before: 'v42',
        canon_version_after: 'v43',
        explanation: 'Piece 017 introduced brenda-20 collision.',
        severity_hint: 'warn'
      )

      hash = original.to_hash
      reparsed = described_class.from_hash(hash)

      expect(reparsed.id).to eq(original.id)
      expect(reparsed.kind).to eq('conflict')
      expect(reparsed.status).to eq('open')
      expect(reparsed.piece_id).to eq('017')
      expect(reparsed.canon_delta_id).to eq('01HBQDELTA')
      expect(reparsed.canon_version_before).to eq('v42')
      expect(reparsed.canon_version_after).to eq('v43')
      expect(reparsed.explanation).to include('brenda-20')
      expect(reparsed.severity_hint).to eq('warn')
    end

    it 'round-trips a closed finding with resolution and resolved_at' do
      f = described_class.open(
        kind: 'conflict', piece_id: '1', canon_delta_id: 'd',
        canon_version_before: 'v1', canon_version_after: 'v2',
        explanation: 'x'
      )
      f.close!(resolution: 'revert', at: Time.utc(2026, 4, 18, 11, 4, 2))

      reparsed = described_class.from_hash(f.to_hash)
      expect(reparsed.status).to eq('closed')
      expect(reparsed.resolution).to eq('revert')
      expect(reparsed.resolved_at).to eq(Time.utc(2026, 4, 18, 11, 4, 2))
    end
  end

  describe 'validation on close' do
    it 'requires resolution when closed' do
      f = described_class.open(
        kind: 'conflict', piece_id: '1', canon_delta_id: 'd',
        canon_version_before: 'v1', canon_version_after: 'v2',
        explanation: 'x'
      )
      expect { f.close!(resolution: nil) }.to raise_error(ArgumentError)
    end
  end
end
