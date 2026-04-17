# frozen_string_literal: true

require 'json'

module Eidos
  # Value object returned by SeedExtractor#extract.
  SeedResult = Struct.new(:characters, :locations, :facts, :warnings)

  # Asks the LLM for a small set of premise-derived seed entries for the
  # Story Bible. Never raises — all failures collapse into an empty
  # SeedResult + a single warning. Caps: ≤3 characters, ≤2 locations,
  # ≤3 facts. Tags every character/location with origin: "seed".
  #
  # See contracts/sdk-surface.md (feature 012-fix-ux-unify-bible).
  class SeedExtractor
    MAX_CHARACTERS = 3
    MAX_LOCATIONS  = 2
    MAX_FACTS      = 3

    ORIGIN_TAGS = {
      'origin' => 'seed',
      'origin_note' => 'derived from premise'
    }.freeze

    def initialize(llm_service:, story_bible:)
      @llm_service = llm_service
      @story_bible = story_bible
    end

    def extract(premise:)
      raw = @llm_service.generate_text(prompt: build_prompt(premise))
      parsed = parse_json(raw)
      return empty_result('LLM returned no parseable JSON') unless parsed.is_a?(Hash)

      SeedResult.new(
        characters: normalize_entities(parsed['characters'], MAX_CHARACTERS),
        locations: normalize_entities(parsed['locations'], MAX_LOCATIONS),
        facts: normalize_facts(parsed['facts']),
        warnings: []
      )
    rescue StandardError => e
      empty_result(e.message)
    end

    private

    def build_prompt(premise)
      <<~PROMPT
        You are seeding a Story Bible from a one-paragraph world premise.

        Premise:
        #{premise}

        Return STRICT JSON with this shape and no prose:
        {
          "characters": [{ "id": "...", "name": "...", "description": "..." }],
          "locations":  [{ "id": "...", "name": "...", "description": "..." }],
          "facts":      ["short factual statement", ...]
        }

        Constraints:
        - At most #{MAX_CHARACTERS} characters.
        - At most #{MAX_LOCATIONS} locations.
        - At most #{MAX_FACTS} facts.
        - Each `id` is snake_case, derived from the name.
        - Keep descriptions concise (one sentence).
      PROMPT
    end

    # Parse the LLM's text output. Accepts either a bare JSON object or
    # an object embedded in a fenced code block / surrounding prose.
    def parse_json(raw)
      return nil if raw.nil? || raw.to_s.strip.empty?

      text = raw.to_s
      JSON.parse(text)
    rescue JSON::ParserError
      extract_embedded_json(text)
    end

    def extract_embedded_json(text)
      first = text.index('{')
      last  = text.rindex('}')
      return nil unless first && last && last > first

      JSON.parse(text[first..last])
    rescue JSON::ParserError
      nil
    end

    def normalize_entities(list, cap)
      return [] unless list.is_a?(Array)

      list.first(cap).filter_map do |entry|
        next unless entry.is_a?(Hash)

        entry.merge(ORIGIN_TAGS)
      end
    end

    def normalize_facts(list)
      return [] unless list.is_a?(Array)

      list.first(MAX_FACTS).filter_map do |fact|
        str = fact.is_a?(Hash) ? (fact['description'] || fact['rule'] || fact['name']) : fact
        str.to_s.strip.empty? ? nil : str.to_s.strip
      end
    end

    def empty_result(message)
      SeedResult.new(characters: [], locations: [], facts: [], warnings: [message.to_s])
    end
  end
end
