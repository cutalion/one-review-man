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
