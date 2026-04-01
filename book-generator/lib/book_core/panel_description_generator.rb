# frozen_string_literal: true

require 'json'
require 'book_core/env_utils'
require 'book_core/models/comic_panel'

module BookCore
  class PanelDescriptionGenerator
    def initialize(llm_service)
      @llm_service = llm_service
    end

    def generate(content:, characters:, panel_count: 4, art_style: 'manga')
      if EnvUtils.mock_ai_enabled?
        return generate_mock_panels(panel_count, characters)
      end

      prompt = build_prompt(content, characters, panel_count, art_style)
      response = @llm_service.generate_text(prompt: prompt)
      parse_response(response, characters)
    end

    private

    def build_prompt(content, characters, panel_count, art_style)
      character_descriptions = characters.values.map(&:to_prompt).join("\n- ")

      <<~PROMPT
        You are a comic book artist planning #{art_style}-style comic panels.

        Given the following narrative content, select the #{panel_count} most visually compelling scenes and write a detailed image generation prompt for each.

        CHARACTERS (use these exact descriptions for visual consistency):
        - #{character_descriptions}

        NARRATIVE CONTENT:
        #{content}

        For each panel, provide:
        1. A detailed visual scene description suitable for an AI image generator
        2. Which characters appear in the scene (use their IDs)

        IMPORTANT: Respond with valid JSON array matching this schema:
        [
          {
            "sequence": 1,
            "scene_description": "Detailed visual description...",
            "characters": ["character_id"]
          }
        ]

        Generate exactly #{panel_count} panels. Respond with the JSON array only, no other text.
      PROMPT
    end

    def parse_response(response, characters)
      json_text = extract_json(response)
      panels_data = JSON.parse(json_text)

      panels_data.map do |panel|
        ComicPanel.new(
          sequence: panel['sequence'],
          scene_description: panel['scene_description'],
          characters: panel['characters'] || []
        )
      end
    rescue JSON::ParserError => e
      raise LLMService::APIError, "Failed to parse panel descriptions: #{e.message}"
    end

    def extract_json(text)
      # Try direct parse first
      JSON.parse(text)
      text
    rescue JSON::ParserError
      # Try extracting from code fences
      if (match = text.match(/```(?:json)?\s*(\[[\s\S]*\])\s*```/))
        return match[1]
      end
      # Try finding array in text
      if (match = text.match(/(\[[\s\S]*\])/))
        return match[1]
      end
      text
    end

    def generate_mock_panels(panel_count, characters)
      char_ids = characters.keys
      panel_count.times.map do |i|
        ComicPanel.new(
          sequence: i + 1,
          scene_description: "Mock scene #{i + 1}: A visually compelling moment from the narrative",
          characters: char_ids.empty? ? [] : [char_ids[i % char_ids.length]]
        )
      end
    end
  end
end
