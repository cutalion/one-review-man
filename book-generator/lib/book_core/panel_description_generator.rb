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
        1. A detailed visual scene description suitable for an AI image generator. Include ALL of these visual storytelling elements:
           - Character appearance and pose/action
           - Facial expression and body language
           - Camera angle or framing (e.g., close-up, wide shot, low angle)
           - Lighting and mood direction (e.g., dramatic shadows, warm golden hour)
           - Composition notes (e.g., character centered, rule of thirds, negative space)
        2. Which characters appear in the scene (use their IDs)
        3. ALL text that should appear in the image as "text_elements". For each piece of visible text (speech bubbles, signs, screens, sound effects, captions), specify the exact wording. Types: "speech_bubble" (with speaker character ID), "sign", "screen", "sound_effect", "caption". If a panel has NO text at all, use an empty text_elements array [].

        IMPORTANT: Respond with valid JSON array matching this schema:
        [
          {
            "sequence": 1,
            "scene_description": "Detailed visual description with camera angle, lighting, expressions, body language, composition...",
            "characters": ["character_id"],
            "text_elements": [
              { "type": "speech_bubble", "speaker": "character_id", "text": "Exact words here" },
              { "type": "sound_effect", "text": "BOOM" }
            ]
          }
        ]

        CRITICAL: Every piece of text that should appear in the final image MUST be listed in text_elements with the exact wording. Do not describe text generically (e.g., "a speech bubble") — always specify the exact words. If a panel should have no text, set text_elements to an empty array [].

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
          characters: panel['characters'] || [],
          text_elements: panel['text_elements'] || []
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
      mock_text_elements = [
        [{ 'type' => 'speech_bubble', 'speaker' => char_ids.first, 'text' => 'Another perfect review... how boring.' }],
        [],
        [{ 'type' => 'sound_effect', 'text' => 'TAP TAP TAP' }],
        [{ 'type' => 'speech_bubble', 'speaker' => char_ids.first, 'text' => 'Is there no code I cannot review?' }]
      ]

      panel_count.times.map do |i|
        ComicPanel.new(
          sequence: i + 1,
          scene_description: "Mock scene #{i + 1}: A visually compelling moment from the narrative. " \
                             "Medium shot, dramatic lighting, character showing determination.",
          characters: char_ids.empty? ? [] : [char_ids[i % char_ids.length]],
          text_elements: mock_text_elements[i % mock_text_elements.length]
        )
      end
    end
  end
end
