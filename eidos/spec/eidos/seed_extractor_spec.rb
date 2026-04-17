# frozen_string_literal: true

require 'spec_helper'
require 'eidos/seed_extractor'
require 'eidos/story_bible'

RSpec.describe Eidos::SeedExtractor do
  # Covers T031 / US3 / feature 012-fix-ux-unify-bible.

  let(:llm) { instance_double('Eidos::LLMService') }
  let(:story_bible) { instance_double('Eidos::StoryBible') }
  let(:extractor) { described_class.new(llm_service: llm, story_bible: story_bible) }

  describe '#extract (success path)' do
    let(:payload) do
      <<~JSON
        {
          "characters": [
            { "id": "jax_patel", "name": "Jax Patel", "description": "A laid-off backend engineer." },
            { "id": "mentor", "name": "The Mentor", "description": "Sage figure." },
            { "id": "rival", "name": "Rival", "description": "Antagonist." },
            { "id": "overflow", "name": "Overflow", "description": "Should be dropped — cap is 3." }
          ],
          "locations": [
            { "id": "home_office", "name": "Home Office", "description": "Cramped spare bedroom." },
            { "id": "coffee_shop", "name": "Cafe", "description": "Third place." },
            { "id": "overflow_loc", "name": "Overflow", "description": "Should be dropped — cap is 2." }
          ],
          "facts": [
            "The tech job market is in a downturn.",
            "Most applications go unanswered.",
            "Companies ghost candidates silently.",
            "Should be dropped — cap is 3."
          ]
        }
      JSON
    end

    before { allow(llm).to receive(:generate_text).and_return(payload) }

    it 'returns a SeedResult with capped arrays' do
      result = extractor.extract(premise: 'A laid-off engineer in a down market.')

      expect(result).to be_a(Eidos::SeedResult)
      expect(result.characters.length).to eq(3)
      expect(result.locations.length).to eq(2)
      expect(result.facts.length).to eq(3)
      expect(result.warnings).to be_empty
    end

    it 'tags every returned character and location with origin metadata' do
      result = extractor.extract(premise: 'Anything.')

      result.characters.each do |c|
        expect(c['origin']).to eq('seed')
        expect(c['origin_note']).to eq('derived from premise')
      end
      result.locations.each do |l|
        expect(l['origin']).to eq('seed')
        expect(l['origin_note']).to eq('derived from premise')
      end
    end
  end

  describe '#extract (malformed JSON)' do
    before { allow(llm).to receive(:generate_text).and_return('this is not JSON{{{') }

    it 'returns an empty SeedResult with one warning and does not raise' do
      result = nil
      expect { result = extractor.extract(premise: 'x') }.not_to raise_error

      expect(result.characters).to be_empty
      expect(result.locations).to be_empty
      expect(result.facts).to be_empty
      expect(result.warnings.length).to eq(1)
    end
  end

  describe '#extract (LLM raises)' do
    before { allow(llm).to receive(:generate_text).and_raise(StandardError, 'timeout') }

    it 'swallows the error and records a warning' do
      result = nil
      expect { result = extractor.extract(premise: 'x') }.not_to raise_error

      expect(result.characters).to be_empty
      expect(result.warnings.length).to eq(1)
      expect(result.warnings.first).to match(/timeout/i)
    end
  end
end
