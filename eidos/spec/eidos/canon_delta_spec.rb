# frozen_string_literal: true

require 'spec_helper'
require 'eidos/canon_delta'

# T037 / T038 — US3 / feature 014-storyworld-pivot.
#
# CanonDelta.parse happy path + failure paths. Well-formed tail block
# yields a delta with all six sections populated; missing sentinel,
# unparseable YAML, and non-mapping top-levels all return an empty
# delta with parse_error set (FR-022).
RSpec.describe Eidos::CanonDelta do
  describe '.parse (happy path)' do
    let(:well_formed) do
      <<~TEXT
        Piece body text goes here.

        ---CANON-DELTA---
        new_characters:
          - id: kev-bot
            name: Kev-Bot
            role: senior-architect
        new_locations:
          - id: virtual-waiting-room
            name: Virtual Waiting Room
        new_facts:
          - subject: synthetix-agnostics
            kind: pivot-history
            value: "Pivoted from blockchain to LLMs."
        new_events:
          - when: during-interview
            who: ["arthur-pringle"]
            what: "Vibe check"
        new_relationships:
          - subject_id: arthur-pringle
            kind: mentor-of
            object_id: kev-bot
        entity_updates:
          - entity_kind: character
            entity_id: brenda-20
            attribute: role
            old_value: "AI recruiter"
            new_value: "HR lambda"
      TEXT
    end

    it 'extracts all six sections as lists' do
      delta = described_class.parse(well_formed)

      expect(delta.parse_error).to be_nil
      expect(delta.new_characters.length).to eq(1)
      expect(delta.new_characters.first['id']).to eq('kev-bot')
      expect(delta.new_locations.length).to eq(1)
      expect(delta.new_facts.length).to eq(1)
      expect(delta.new_events.length).to eq(1)
      expect(delta.new_relationships.length).to eq(1)
      expect(delta.entity_updates.length).to eq(1)
    end

    it 'normalizes ids through ValidationUtils.slugify' do
      with_messy_ids = <<~TEXT
        Body.

        ---CANON-DELTA---
        new_characters:
          - id: "Kev Bot!"
            name: Kev-Bot
        new_locations: []
        new_facts: []
        new_events: []
        new_relationships: []
        entity_updates:
          - entity_kind: character
            entity_id: "Arthur Pringle"
            attribute: role
            old_value: applicant
            new_value: mentor
      TEXT

      delta = described_class.parse(with_messy_ids)
      expect(delta.new_characters.first['id']).to eq('kev-bot')
      expect(delta.entity_updates.first['entity_id']).to eq('arthur-pringle')
    end

    it 'treats missing sections as empty lists' do
      sparse = <<~TEXT
        Body.

        ---CANON-DELTA---
        new_characters:
          - id: arthur
            name: Arthur
      TEXT

      delta = described_class.parse(sparse)
      expect(delta.parse_error).to be_nil
      expect(delta.new_characters.length).to eq(1)
      expect(delta.new_locations).to eq([])
      expect(delta.new_facts).to eq([])
      expect(delta.new_events).to eq([])
      expect(delta.new_relationships).to eq([])
      expect(delta.entity_updates).to eq([])
    end

    it 'exposes the piece body separate from the delta' do
      delta = described_class.parse(well_formed)
      expect(delta.body).to include('Piece body text goes here.')
      expect(delta.body).not_to include('---CANON-DELTA---')
      expect(delta.body).not_to include('new_characters:')
    end
  end

  describe '.parse (failure paths)' do
    it 'returns empty delta with parse_error when sentinel is missing' do
      delta = described_class.parse("Just a body, no sentinel here.")
      expect(delta.parse_error['summary']).to match(/sentinel/i)
      expect(delta.parse_error['drops']).to eq([])
      expect(delta).to be_empty
    end

    it 'returns empty delta with parse_error on unparseable YAML after sentinel' do
      garbage = <<~TEXT
        Body.

        ---CANON-DELTA---
        new_characters: [
          unclosed bracket:
      TEXT
      delta = described_class.parse(garbage)
      expect(delta.parse_error).to be_a(Hash)
      expect(delta.parse_error['summary']).not_to be_empty
      expect(delta.parse_error['drops']).to eq([])
      expect(delta).to be_empty
    end

    it 'returns empty delta with parse_error when YAML is not a mapping' do
      text = <<~TEXT
        Body.

        ---CANON-DELTA---
        - just
        - a
        - list
      TEXT
      delta = described_class.parse(text)
      expect(delta.parse_error['summary']).to match(/mapping/i)
      expect(delta.parse_error['drops']).to eq([])
      expect(delta).to be_empty
    end

    # T027 (feature 015 US1): non-mapping entries used to `warn` to stderr
    # and silently drop (three of four deltas in the 014 job-hunt demo lost
    # their entities this way). Now each drop must materialize in
    # `parse_error.drops[]` so it's visible in `canon review`. The
    # well-formed siblings still apply — drops don't block application.
    it 'records non-mapping list entries in parse_error.drops' do
      text = <<~TEXT
        Body.

        ---CANON-DELTA---
        new_characters:
          - "oops a string"
          - id: arthur
            name: Arthur
        new_locations: []
        new_facts: []
        new_events: []
        new_relationships: []
        entity_updates: []
      TEXT
      delta = described_class.parse(text)

      aggregate_failures do
        expect(delta.parse_error).to be_a(Hash)
        expect(delta.parse_error['summary']).to be_a(String)
        expect(delta.parse_error['summary']).not_to be_empty
        expect(delta.parse_error['drops']).to be_an(Array)
        expect(delta.parse_error['drops'].length).to eq(1)

        drop = delta.parse_error['drops'].first
        expect(drop['section']).to eq('new_characters')
        expect(drop['value']).to eq('oops a string')
        expect(drop['reason']).to match(/expected mapping/i)

        # The well-formed entry sibling still lands (partial success).
        expect(delta.new_characters.length).to eq(1)
        expect(delta.new_characters.first['id']).to eq('arthur')
      end
    end

    # T027 (cont.): aggregate summary when drops span multiple sections.
    it 'aggregates drops from multiple sections into a single parse_error' do
      text = <<~TEXT
        Body.

        ---CANON-DELTA---
        new_characters:
          - "arthur is a programmer"
        new_locations: []
        new_facts:
          - "the office is grim"
        new_events: []
        new_relationships: []
        entity_updates: []
      TEXT
      delta = described_class.parse(text)

      expect(delta.parse_error['drops'].map { |d| d['section'] })
        .to contain_exactly('new_characters', 'new_facts')
    end

    # T028 (feature 015 US1): on-disk legacy deltas carry `parse_error` as
    # a bare String ("YAML parse error: ..."). The new reader normalizes
    # that to the new Hash shape with empty drops so downstream code only
    # handles one schema.
    describe '.from_hash backwards compatibility' do
      it 'normalizes a legacy String parse_error into the new Hash shape' do
        delta = described_class.from_hash(
          'id' => '01LEGACY',
          'body' => 'x',
          'parse_error' => 'YAML parse error: unclosed bracket'
        )

        aggregate_failures do
          expect(delta.parse_error).to be_a(Hash)
          expect(delta.parse_error['summary']).to eq('YAML parse error: unclosed bracket')
          expect(delta.parse_error['drops']).to eq([])
        end
      end

      it 'passes a Hash parse_error through unchanged' do
        delta = described_class.from_hash(
          'id' => '01NEW',
          'body' => 'x',
          'parse_error' => {
            'summary' => '1 drop',
            'drops' => [{ 'section' => 'new_facts', 'value' => 'x', 'reason' => 'expected mapping, got String' }]
          }
        )

        expect(delta.parse_error['drops'].first['reason']).to match(/expected mapping/)
      end
    end
  end

  describe '#empty?' do
    it 'is true when every section list is empty' do
      text = <<~TEXT
        Body.

        ---CANON-DELTA---
        new_characters: []
        new_locations: []
        new_facts: []
        new_events: []
        new_relationships: []
        entity_updates: []
      TEXT
      delta = described_class.parse(text)
      expect(delta).to be_empty
      expect(delta.parse_error).to be_nil
    end
  end
end
