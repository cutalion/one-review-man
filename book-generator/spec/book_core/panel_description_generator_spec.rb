# frozen_string_literal: true

require 'book_core/panel_description_generator'
require 'book_core/character_appearance'

RSpec.describe BookCore::PanelDescriptionGenerator do
  let(:llm_service) { double('LLMService') }
  let(:generator) { described_class.new(llm_service) }
  let(:characters) do
    {
      'kenji_yamamoto' => BookCore::CharacterAppearance.new(
        'id' => 'kenji_yamamoto',
        'name' => 'Kenji Yamamoto',
        'physical_appearance' => {
          'age' => 28,
          'skin_tone' => 'Light',
          'hair' => 'Messy black',
          'eyes' => 'Tired, dark circles',
          'outfit' => 'Worn-out grey hoodie and jeans',
          'distinguishing_features' => 'Always looks sleepy, slouches'
        }
      )
    }
  end
  let(:content) { "Chapter 1: Kenji sat at his desk, bored by another perfect code review." }

  describe '#generate' do
    context 'with MOCK_AI=true' do
      before { allow(BookCore::EnvUtils).to receive(:mock_ai_enabled?).and_return(true) }

      it 'returns the requested number of mock panels' do
        panels = generator.generate(content: content, characters: characters, panel_count: 4)

        expect(panels.length).to eq(4)
        panels.each_with_index do |panel, i|
          expect(panel.sequence).to eq(i + 1)
          expect(panel.scene_description).to include('Mock scene')
          expect(panel.image_path).to be_nil
        end
      end

      it 'assigns characters round-robin to mock panels' do
        panels = generator.generate(content: content, characters: characters, panel_count: 2)

        expect(panels.first.characters).to include('kenji_yamamoto')
      end

      it 'does not call llm_service' do
        expect(llm_service).not_to receive(:generate_text)
        generator.generate(content: content, characters: characters)
      end

      it 'handles empty characters hash' do
        panels = generator.generate(content: content, characters: {}, panel_count: 2)

        expect(panels.length).to eq(2)
        expect(panels.first.characters).to eq([])
      end
    end

    context 'mock panels include text_elements' do
      before { allow(BookCore::EnvUtils).to receive(:mock_ai_enabled?).and_return(true) }

      it 'returns panels with text_elements' do
        panels = generator.generate(content: content, characters: characters, panel_count: 4)

        # Panel 1 has speech bubble, panel 2 is empty, panel 3 has sound effect, panel 4 has speech bubble
        expect(panels[0].text_elements).not_to be_empty
        expect(panels[0].text_elements.first['type']).to eq('speech_bubble')
        expect(panels[1].text_elements).to eq([])
        expect(panels[2].text_elements.first['type']).to eq('sound_effect')
        expect(panels[3].text_elements).not_to be_empty
      end
    end

    context 'with real LLM' do
      before { allow(BookCore::EnvUtils).to receive(:mock_ai_enabled?).and_return(false) }

      it 'parses JSON response into ComicPanels' do
        json_response = <<~JSON
          [
            {"sequence": 1, "scene_description": "A programmer at his desk", "characters": ["kenji_yamamoto"]},
            {"sequence": 2, "scene_description": "Code flowing on screen", "characters": ["kenji_yamamoto"]}
          ]
        JSON

        allow(llm_service).to receive(:generate_text).and_return(json_response)

        panels = generator.generate(content: content, characters: characters, panel_count: 2)

        expect(panels.length).to eq(2)
        expect(panels.first.sequence).to eq(1)
        expect(panels.first.scene_description).to eq('A programmer at his desk')
        expect(panels.first.characters).to eq(['kenji_yamamoto'])
      end

      it 'handles JSON wrapped in code fences' do
        response = "```json\n[{\"sequence\": 1, \"scene_description\": \"Test\", \"characters\": []}]\n```"

        allow(llm_service).to receive(:generate_text).and_return(response)

        panels = generator.generate(content: content, characters: characters, panel_count: 1)

        expect(panels.length).to eq(1)
        expect(panels.first.scene_description).to eq('Test')
      end

      it 'includes text control instructions in prompt' do
        allow(llm_service).to receive(:generate_text) do |args|
          prompt = args[:prompt]
          expect(prompt).to include('text_elements')
          expect(prompt).to include('speech_bubble')
          expect(prompt).to include('exact')
          '[{"sequence": 1, "scene_description": "test", "characters": [], "text_elements": []}]'
        end

        generator.generate(content: content, characters: characters, panel_count: 1)
      end

      it 'instructs LLM to indicate no-text panels' do
        allow(llm_service).to receive(:generate_text) do |args|
          prompt = args[:prompt]
          expect(prompt).to match(/no text|empty.*text_elements/i)
          '[{"sequence": 1, "scene_description": "test", "characters": [], "text_elements": []}]'
        end

        generator.generate(content: content, characters: characters, panel_count: 1)
      end

      it 'parses text_elements from LLM response' do
        json_response = <<~JSON
          [
            {
              "sequence": 1,
              "scene_description": "A programmer at his desk",
              "characters": ["kenji_yamamoto"],
              "text_elements": [
                { "type": "speech_bubble", "speaker": "kenji_yamamoto", "text": "Hello world" }
              ]
            }
          ]
        JSON

        allow(llm_service).to receive(:generate_text).and_return(json_response)

        panels = generator.generate(content: content, characters: characters, panel_count: 1)

        expect(panels.first.text_elements.length).to eq(1)
        expect(panels.first.text_elements.first['type']).to eq('speech_bubble')
        expect(panels.first.text_elements.first['text']).to eq('Hello world')
      end

      it 'includes visual storytelling instructions in prompt' do
        allow(llm_service).to receive(:generate_text) do |args|
          prompt = args[:prompt]
          expect(prompt).to include('Camera angle')
          expect(prompt).to include('Lighting')
          expect(prompt).to include('expression')
          expect(prompt).to include('body language')
          expect(prompt).to include('Composition')
          '[{"sequence": 1, "scene_description": "test", "characters": [], "text_elements": []}]'
        end

        generator.generate(content: content, characters: characters, panel_count: 1)
      end

      it 'includes character descriptions and art style in prompt' do
        allow(llm_service).to receive(:generate_text) do |args|
          prompt = args[:prompt]
          expect(prompt).to include('manga')
          expect(prompt).to include('Kenji Yamamoto')
          expect(prompt).to include('Messy black')
          '[{"sequence": 1, "scene_description": "test", "characters": []}]'
        end

        generator.generate(content: content, characters: characters, panel_count: 1, art_style: 'manga')
      end
    end
  end
end
