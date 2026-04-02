# frozen_string_literal: true

require 'tmpdir'
require 'yaml'
require 'eidos/character_appearance'

RSpec.describe Eidos::CharacterAppearance do
  let(:character_data) do
    {
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
    }
  end

  describe '#initialize' do
    it 'extracts all appearance fields' do
      appearance = described_class.new(character_data)

      expect(appearance.id).to eq('kenji_yamamoto')
      expect(appearance.name).to eq('Kenji Yamamoto')
      expect(appearance.age).to eq(28)
      expect(appearance.skin_tone).to eq('Light')
      expect(appearance.hair).to eq('Messy black')
      expect(appearance.eyes).to eq('Tired, dark circles')
      expect(appearance.outfit).to eq('Worn-out grey hoodie and jeans')
      expect(appearance.distinguishing_features).to eq('Always looks sleepy, slouches')
    end

    it 'handles missing physical_appearance gracefully' do
      data = { 'id' => 'mystery', 'name' => 'Mystery Person' }
      appearance = described_class.new(data)

      expect(appearance.name).to eq('Mystery Person')
      expect(appearance.age).to be_nil
      expect(appearance.hair).to be_nil
    end
  end

  describe '#to_prompt' do
    it 'composes a visual description string' do
      appearance = described_class.new(character_data)
      prompt = appearance.to_prompt

      expect(prompt).to include('Kenji Yamamoto')
      expect(prompt).to include('28 years old')
      expect(prompt).to include('Light skin')
      expect(prompt).to include('Messy black hair')
      expect(prompt).to include('Tired, dark circles eyes')
      expect(prompt).to include('wearing Worn-out grey hoodie and jeans')
      expect(prompt).to include('Always looks sleepy, slouches')
    end

    it 'handles character with no appearance data' do
      data = { 'id' => 'ghost', 'name' => 'Ghost' }
      appearance = described_class.new(data)

      expect(appearance.to_prompt).to eq('Ghost')
    end

    it 'handles partial appearance data' do
      data = {
        'id' => 'partial',
        'name' => 'Partial Person',
        'physical_appearance' => { 'hair' => 'Red', 'eyes' => 'Green' }
      }
      appearance = described_class.new(data)
      prompt = appearance.to_prompt

      expect(prompt).to include('Red hair')
      expect(prompt).to include('Green eyes')
      expect(prompt).not_to include('years old')
    end
  end

  describe '.extract_all' do
    it 'reads all character YAML files from story bible' do
      Dir.mktmpdir do |dir|
        chars_dir = File.join(dir, 'characters')
        FileUtils.mkdir_p(chars_dir)

        File.write(File.join(chars_dir, 'kenji_yamamoto.yml'), YAML.dump(character_data))
        File.write(File.join(chars_dir, 'emily_chen.yml'), YAML.dump(
                                                             'id' => 'emily_chen',
                                                             'name' => 'Emily Chen',
                                                             'physical_appearance' => { 'hair' => 'Long black', 'eyes' => 'Sharp' }
                                                           ))

        result = described_class.extract_all(dir)

        expect(result.keys).to contain_exactly('kenji_yamamoto', 'emily_chen')
        expect(result['kenji_yamamoto'].name).to eq('Kenji Yamamoto')
        expect(result['emily_chen'].hair).to eq('Long black')
      end
    end

    it 'returns empty hash when characters directory does not exist' do
      Dir.mktmpdir do |dir|
        result = described_class.extract_all(dir)
        expect(result).to eq({})
      end
    end

    it 'skips invalid YAML files' do
      Dir.mktmpdir do |dir|
        chars_dir = File.join(dir, 'characters')
        FileUtils.mkdir_p(chars_dir)

        File.write(File.join(chars_dir, 'valid.yml'), YAML.dump(character_data))
        File.write(File.join(chars_dir, 'no_name.yml'), YAML.dump('id' => 'nameless'))

        result = described_class.extract_all(dir)
        expect(result.keys).to eq(['kenji_yamamoto'])
      end
    end
  end
end
