# frozen_string_literal: true

require 'eidos/models/comic_panel'

RSpec.describe Eidos::ComicPanel do
  describe '#initialize' do
    it 'creates a panel with required attributes' do
      panel = described_class.new(
        sequence: 1,
        scene_description: 'A tired programmer at his desk'
      )

      expect(panel.sequence).to eq(1)
      expect(panel.scene_description).to eq('A tired programmer at his desk')
      expect(panel.characters).to eq([])
      expect(panel.image_path).to be_nil
      expect(panel.text_elements).to eq([])
    end

    it 'accepts text_elements' do
      text_elements = [
        { 'type' => 'speech_bubble', 'speaker' => 'kenji_yamamoto', 'text' => 'Another perfect review...' }
      ]
      panel = described_class.new(
        sequence: 1,
        scene_description: 'A scene',
        text_elements: text_elements
      )

      expect(panel.text_elements).to eq(text_elements)
    end

    it 'accepts optional characters and image_path' do
      panel = described_class.new(
        sequence: 2,
        scene_description: 'Two programmers arguing',
        characters: ['kenji_yamamoto', 'emily_chen'],
        image_path: 'panel_001_02.png'
      )

      expect(panel.characters).to eq(['kenji_yamamoto', 'emily_chen'])
      expect(panel.image_path).to eq('panel_001_02.png')
    end
  end

  describe '#image_path=' do
    it 'allows setting image_path after creation' do
      panel = described_class.new(sequence: 1, scene_description: 'test')
      panel.image_path = 'panel_001_01.png'

      expect(panel.image_path).to eq('panel_001_01.png')
    end
  end

  describe '#to_h' do
    it 'returns a hash representation' do
      panel = described_class.new(
        sequence: 1,
        scene_description: 'A scene',
        characters: ['kenji_yamamoto'],
        image_path: 'panel_001_01.png'
      )

      expect(panel.to_h).to eq(
        'sequence' => 1,
        'scene_description' => 'A scene',
        'characters' => ['kenji_yamamoto'],
        'image_path' => 'panel_001_01.png',
        'text_elements' => []
      )
    end

    it 'includes nil image_path when not set' do
      panel = described_class.new(sequence: 1, scene_description: 'test')

      expect(panel.to_h['image_path']).to be_nil
    end

    it 'includes text_elements in hash' do
      text_elements = [{ 'type' => 'sound_effect', 'text' => 'TAP TAP TAP' }]
      panel = described_class.new(
        sequence: 1,
        scene_description: 'test',
        text_elements: text_elements
      )

      expect(panel.to_h['text_elements']).to eq(text_elements)
    end
  end
end
