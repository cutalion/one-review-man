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
      expect(delta.parse_error).to match(/sentinel/i)
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
      expect(delta.parse_error).to be_a(String)
      expect(delta.parse_error).not_to be_empty
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
      expect(delta.parse_error).to match(/mapping/i)
      expect(delta).to be_empty
    end

    it 'drops non-mapping list entries with a debug warning' do
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
      expect(delta.parse_error).to be_nil
      expect(delta.new_characters.length).to eq(1)
      expect(delta.new_characters.first['id']).to eq('arthur')
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
