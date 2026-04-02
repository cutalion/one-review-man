# frozen_string_literal: true

require 'json'
require 'eidos/env_utils'
require 'eidos/models/comic_panel'

module Eidos
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

        ## STRICT RULES FOR DIALOG AND TEXT

        RULE 1: "scene_description" must contain ONLY visual direction. It must NOT contain any dialog, quoted speech, "speech bubble" references, or "text reading" phrases. Describe what characters look like and do — NOT what they say.

        RULE 2: ALL character dialog from the narrative MUST go in "text_elements" as speech_bubble entries. If a character speaks in the scene, their words MUST appear in text_elements. Use the character ID (not display name) in the "speaker" field.

        RULE 3: Keep each speech bubble text short — 1-2 brief sentences maximum. Select the most impactful dialog from the narrative.

        RULE 4: If a panel has no dialog or text, set text_elements to an empty array [].

        ## CORRECT EXAMPLE (dialog in text_elements, NOT in scene_description):

        ```json
        {
          "sequence": 1,
          "scene_description": "Medium shot of a programmer slouching in his chair, eyes half-lidded with boredom, one hand resting on the keyboard. Cool blue monitor light illuminates his face. Empty coffee cups litter the desk. Low angle emphasizing his isolation in the dim office.",
          "characters": ["kenji_yamamoto"],
          "text_elements": [
            { "type": "speech_bubble", "speaker": "kenji_yamamoto", "text": "Another perfect review... how boring." }
          ]
        }
        ```

        ## WRONG EXAMPLE (DO NOT DO THIS — dialog embedded in scene_description):

        ```json
        {
          "sequence": 1,
          "scene_description": "A programmer slouches at his desk, a small speech bubble indicating: 'Another perfect review... how boring.' He looks tired.",
          "characters": ["kenji_yamamoto"],
          "text_elements": []
        }
        ```
        This is WRONG because the dialog is in scene_description instead of text_elements.

        ## OUTPUT FORMAT

        For each panel, provide:
        1. "scene_description": Visual direction ONLY — character appearance, pose, expression, body language, camera angle, lighting, mood, composition. Do NOT put any dialog here.
        2. "characters": Array of character IDs appearing in the scene.
        3. "text_elements": Array of ALL text for the image. Types: "speech_bubble" (with "speaker" character ID and "text"), "sound_effect" ("text" only), "sign", "screen", "caption".

        Respond with a valid JSON array:
        [
          {
            "sequence": 1,
            "scene_description": "Visual direction only...",
            "characters": ["character_id"],
            "text_elements": [
              { "type": "speech_bubble", "speaker": "character_id", "text": "Short dialog here" }
            ]
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
          characters: panel['characters'] || [],
          text_elements: panel['text_elements']
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
