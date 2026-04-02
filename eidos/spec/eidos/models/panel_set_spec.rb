# frozen_string_literal: true

require 'tmpdir'
require 'eidos/models/panel_set'

RSpec.describe Eidos::PanelSet do
  let(:panels) do
    [
      Eidos::ComicPanel.new(sequence: 1, scene_description: 'Scene one', characters: ['kenji_yamamoto']),
      Eidos::ComicPanel.new(sequence: 2, scene_description: 'Scene two', characters: ['emily_chen'])
    ]
  end

  let(:panel_set) do
    described_class.new(
      source: { 'type' => 'chapter', 'number' => 1 },
      art_style: 'manga',
      image_format: 'square',
      canon_version: 'unversioned',
      panels: panels,
      generated_at: '2026-04-01T12:00:00Z'
    )
  end

  describe '#initialize' do
    it 'creates a panel set with all attributes' do
      expect(panel_set.source).to eq('type' => 'chapter', 'number' => 1)
      expect(panel_set.art_style).to eq('manga')
      expect(panel_set.image_format).to eq('square')
      expect(panel_set.canon_version).to eq('unversioned')
      expect(panel_set.panels.length).to eq(2)
      expect(panel_set.generated_at).to eq('2026-04-01T12:00:00Z')
    end

    it 'defaults generated_at to current time' do
      ps = described_class.new(
        source: { 'type' => 'chapter', 'number' => 1 },
        art_style: 'manga',
        image_format: 'square',
        canon_version: 'unversioned'
      )
      expect(ps.generated_at).not_to be_nil
    end
  end

  describe '#fully_generated?' do
    it 'returns false when panels have no image_path' do
      expect(panel_set.fully_generated?).to be false
    end

    it 'returns true when all panels have image_path' do
      panels.each_with_index { |p, i| p.image_path = "panel_001_0#{i + 1}.png" }
      expect(panel_set.fully_generated?).to be true
    end

    it 'returns false when some panels lack image_path' do
      panels.first.image_path = 'panel_001_01.png'
      expect(panel_set.fully_generated?).to be false
    end

    it 'returns false when panels array is empty' do
      empty_set = described_class.new(
        source: { 'type' => 'chapter', 'number' => 1 },
        art_style: 'manga',
        image_format: 'square',
        canon_version: 'unversioned',
        panels: []
      )
      expect(empty_set.fully_generated?).to be false
    end
  end

  describe '#sidecar_filename' do
    it 'generates filename from source number' do
      expect(panel_set.sidecar_filename).to eq('panels_001.yml')
    end
  end

  describe '#to_h' do
    it 'returns a YAML-serializable hash' do
      h = panel_set.to_h
      expect(h['source']).to eq('type' => 'chapter', 'number' => 1)
      expect(h['art_style']).to eq('manga')
      expect(h['panels'].length).to eq(2)
      expect(h['panels'].first['sequence']).to eq(1)
    end
  end

  describe '#save_sidecar and .load_sidecar' do
    it 'round-trips through YAML' do
      Dir.mktmpdir do |dir|
        path = panel_set.save_sidecar(dir)
        expect(File.basename(path)).to eq('panels_001.yml')
        expect(File.exist?(path)).to be true

        loaded = described_class.load_sidecar(path)
        expect(loaded.source).to eq('type' => 'chapter', 'number' => 1)
        expect(loaded.art_style).to eq('manga')
        expect(loaded.image_format).to eq('square')
        expect(loaded.panels.length).to eq(2)
        expect(loaded.panels.first.scene_description).to eq('Scene one')
        expect(loaded.panels.first.characters).to eq(['kenji_yamamoto'])
      end
    end

    it 'creates output directory if needed' do
      Dir.mktmpdir do |dir|
        nested = File.join(dir, 'sub', 'dir')
        panel_set.save_sidecar(nested)
        expect(Dir.exist?(nested)).to be true
      end
    end
  end
end
