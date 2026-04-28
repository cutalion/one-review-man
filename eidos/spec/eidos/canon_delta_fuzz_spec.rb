# frozen_string_literal: true

# Fuzz-style coverage for CanonDelta.parse against realistic malformed
# LLM output. Each case below is taken from `spec/support/mock_responses.yml`
# (the fixtures introduced in feature 015 T005) so that integration specs
# and unit specs exercise the same pathological strings.
#
# Invariants under test (feature 015 US1 / FR-024):
#   - The parse never raises.
#   - `parse_error` is a Hash (new shape), never nil when the input was
#     degraded in any way the LLM might plausibly produce.
#   - No bare stderr `warn` is the only signal of the degradation — the
#     harness would flip the enclosing spec red if MockLLMService routed
#     the call, but here we assert positively that `parse_error.summary`
#     or `parse_error.drops` is populated.
#
# Feature: specs/015-scaffold-hardening (US1, T029)

require 'spec_helper'
require 'yaml'
require 'eidos/canon_delta'

RSpec.describe Eidos::CanonDelta, 'malformed LLM output fuzz cases' do
  let(:fixtures) do
    YAML.load_file(File.expand_path('../support/mock_responses.yml', __dir__))
  end

  # Case (a): LLM emitted bare-string entries where a mapping was expected.
  # Real example: "Arthur is a programmer" shipped instead of
  # {name: Arthur, description: A programmer}. Three of four demo deltas
  # in the 014 job-hunt run lost entities this way (postmortem §3.1).
  it 'case (a) bare-string entries: records a drop per offending entry, summary populated' do
    delta = described_class.parse(fixtures.fetch('canon_delta_bare_string'))

    aggregate_failures do
      expect(delta.parse_error).to be_a(Hash)
      expect(delta.parse_error['summary']).to be_a(String).and(satisfy { |s| !s.empty? })

      drops = delta.parse_error['drops']
      expect(drops).to be_an(Array)
      # The fixture has one bare-string in new_characters and one in new_facts.
      expect(drops.map { |d| d['section'] }).to contain_exactly('new_characters', 'new_facts')
      drops.each do |d|
        expect(d['value']).to be_a(String)
        expect(d['reason']).to match(/expected mapping/i)
      end
    end
  end

  # Case (b): truncated YAML tail. The LLM stopped mid-mapping (common in
  # token-limited responses). Must surface as a document-level
  # `parse_error.summary`, not a silent empty delta.
  it 'case (b) truncated YAML tail: parse_error.summary populated, no raise' do
    delta = described_class.parse(fixtures.fetch('canon_delta_truncated_yaml'))

    aggregate_failures do
      expect(delta.parse_error).to be_a(Hash)
      expect(delta.parse_error['summary']).to match(/yaml parse error|parse error/i)
      # Document-level failures have empty drops per data-model §1.
      expect(delta.parse_error['drops']).to eq([])
    end
  end

  # Case (c): structurally incomplete entry — no id, no name. Derived-id
  # cannot recover it. Must drop, not silently apply a nameless record.
  # (Contract from data-model.md: reason "missing both id and name".)
  it 'case (c) entry with neither id nor name: recorded in drops' do
    text = <<~TEXT
      Body.

      ---CANON-DELTA---
      new_characters:
        - role: senior-architect
      new_locations: []
      new_facts: []
      new_events: []
      new_relationships: []
      entity_updates: []
    TEXT

    delta = described_class.parse(text)

    aggregate_failures do
      expect(delta.parse_error).to be_a(Hash)
      drops = delta.parse_error['drops']
      expect(drops.length).to eq(1)
      expect(drops.first['section']).to eq('new_characters')
      expect(drops.first['reason']).to match(/missing.*id.*name|missing both/i)
      expect(delta.new_characters).to eq([])
    end
  end
end
