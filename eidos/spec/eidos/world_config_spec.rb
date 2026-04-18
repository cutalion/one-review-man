# frozen_string_literal: true

require 'spec_helper'
require 'eidos/world_config'
require 'tempfile'

RSpec.describe Eidos::WorldConfig do
  let(:sample_config) do
    {
      'generation' => {
        'chapter_length_target' => '2000-4000 words',
        'main_characters' => [
          { 'display_name' => 'One Review Man', 'placeholder_key' => 'ONE_REVIEW_MAN_REAL_NAME' }
        ],
        'content_rules' => {
          'parody_source' => 'One-Punch Man',
          'humor_style' => 'absurdist_programming'
        },
        'translation_rules' => {
          'ru' => {
            'character_mappings' => {
              'One Review Man' => 'Ванревьюмен'
            }
          }
        }
      },
      'localized' => {
        'en' => {
          'title' => 'One Review Man',
          'author' => 'AI Collective',
          'genre' => 'Humor/Comedy',
          'humor_style' => 'absurdist',
          'setting' => 'Tech company',
          'description' => 'A programming comedy',
          'themes' => {
            'primary' => 'workplace comedy',
            'secondary' => ['mistaken identity']
          }
        },
        'ru' => {
          'title' => 'Ванревьюмэн',
          'author' => 'ИИ Коллектив',
          'genre' => 'Юмор/Комедия'
        }
      },
      'site_url' => 'https://example.com',
      'twitter_username' => 'testuser'
    }
  end

  let(:sample_state) do
    {
      'world' => {
        'target_chapters' => 50,
        'current_chapter' => 5
      }
    }
  end

  describe '#initialize' do
    it 'creates a config with empty data' do
      config = described_class.new({}, {})
      expect(config.raw_data).to eq({})
    end

    it 'creates a config with provided data' do
      config = described_class.new(sample_config, sample_state)
      expect(config.title).to eq('One Review Man')
      expect(config.current_chapter).to eq(5)
    end

    it 'validates structure on initialization' do
      expect { described_class.new('invalid', {}) }.to raise_error(Eidos::WorldConfig::ValidationError, 'Config data must be a Hash')
      expect { described_class.new({}, 'invalid') }.to raise_error(Eidos::WorldConfig::ValidationError, 'State data must be a Hash')
    end
  end

  describe '.load_split_config' do
    let(:temp_config) { Tempfile.new(['book_config', '.yml']) }
    let(:temp_state) { Tempfile.new(['book_state', '.yml']) }

    after do
      temp_config.close
      temp_config.unlink
      temp_state.close
      temp_state.unlink
    end

    it 'loads from valid YAML files' do
      temp_config.write(sample_config.to_yaml)
      temp_config.rewind
      temp_state.write(sample_state.to_yaml)
      temp_state.rewind

      config = described_class.load_split_config(temp_config.path, temp_state.path)
      expect(config.title).to eq('One Review Man')
      expect(config.current_chapter).to eq(5)
    end

    it 'handles missing files gracefully' do
      config = described_class.load_split_config('/non/existent/config.yml', '/non/existent/state.yml')
      expect(config.raw_data).to eq({})
    end
  end

  describe '.load_legacy_config' do
    let(:temp_file) { Tempfile.new(['book_metadata', '.yml']) }
    let(:legacy_data) { sample_config.merge(sample_state) }

    after do
      temp_file.close
      temp_file.unlink
    end

    it 'loads from a valid legacy YAML file' do
      temp_file.write(legacy_data.to_yaml)
      temp_file.rewind

      config = described_class.load_legacy_config(temp_file.path)
      expect(config.title).to eq('One Review Man')
      expect(config.current_chapter).to eq(5)
    end
  end

  describe '.load_from_project' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:config_path) { File.join(temp_dir, 'data', 'world_config.yml') }
    let(:state_path) { File.join(temp_dir, 'data', 'world_state.yml') }
    let(:legacy_path) { File.join(temp_dir, 'data', 'world_metadata.yml') }

    after { FileUtils.rm_rf(temp_dir) }

    it 'loads split config if present' do
      FileUtils.mkdir_p(File.dirname(config_path))
      File.write(config_path, sample_config.to_yaml)
      File.write(state_path, sample_state.to_yaml)

      config = described_class.load_from_project(temp_dir)
      expect(config.title).to eq('One Review Man')
      expect(config.current_chapter).to eq(5)
    end

    it 'loads legacy config if split config missing' do
      FileUtils.mkdir_p(File.dirname(legacy_path))
      File.write(legacy_path, sample_config.merge(sample_state).to_yaml)

      config = described_class.load_from_project(temp_dir)
      expect(config.title).to eq('One Review Man')
      expect(config.current_chapter).to eq(5)
    end
  end

  describe 'language-specific data access' do
    let(:config) { described_class.new(sample_config, sample_state) }

    describe '#en_metadata' do
      it 'returns English localized data' do
        expect(config.en_metadata['title']).to eq('One Review Man')
        expect(config.en_metadata['genre']).to eq('Humor/Comedy')
      end

      it 'returns empty hash when no English data' do
        config = described_class.new({}, {})
        expect(config.en_metadata).to eq({})
      end
    end

    describe '#ru_metadata' do
      it 'returns Russian localized data' do
        expect(config.ru_metadata['title']).to eq('Ванревьюмэн')
        expect(config.ru_metadata['author']).to eq('ИИ Коллектив')
      end
    end

    describe '#localized_data' do
      it 'returns data for specified language' do
        expect(config.localized_data('en')['title']).to eq('One Review Man')
        expect(config.localized_data('ru')['title']).to eq('Ванревьюмэн')
      end

      it 'returns empty hash for non-existent language' do
        expect(config.localized_data('fr')).to eq({})
      end
    end

    describe '#update_localized' do
      it 'updates localized data and marks dirty' do
        config.update_localized('en', 'title' => 'New Title')
        expect(config.title).to eq('New Title')
        expect(config).to be_dirty
      end

      it 'creates language section if it does not exist' do
        config.update_localized('fr', 'title' => 'Titre Français')
        expect(config.localized_data('fr')['title']).to eq('Titre Français')
      end

      it 'returns self for chaining' do
        result = config.update_localized('en', 'title' => 'New Title')
        expect(result).to be(config)
      end
    end
  end

  describe 'generation configuration' do
    let(:config) { described_class.new(sample_config, sample_state) }

    describe '#content_rules' do
      it 'returns content rules hash' do
        rules = config.content_rules
        expect(rules['parody_source']).to eq('One-Punch Man')
        expect(rules['humor_style']).to eq('absurdist_programming')
      end

      it 'returns empty hash when no content rules' do
        config = described_class.new({}, {})
        expect(config.content_rules).to eq({})
      end
    end

    describe '#main_characters' do
      it 'returns main characters array' do
        characters = config.main_characters
        expect(characters).to be_an(Array)
        expect(characters.first['display_name']).to eq('One Review Man')
      end

      it 'returns empty array when no main characters' do
        config = described_class.new({}, {})
        expect(config.main_characters).to eq([])
      end
    end

    describe '#chapter_length_target' do
      it 'returns configured chapter length' do
        expect(config.chapter_length_target).to eq('2000-4000 words')
      end

      it 'returns default when not configured' do
        config = described_class.new({}, {})
        expect(config.chapter_length_target).to eq('1500-3000 words')
      end
    end

    describe '#translation_rules_for' do
      it 'returns translation rules for language' do
        rules = config.translation_rules_for('ru')
        expect(rules['character_mappings']['One Review Man']).to eq('Ванревьюмен')
      end

      it 'returns empty hash for non-existent language' do
        expect(config.translation_rules_for('fr')).to eq({})
      end
    end
  end

  describe 'book status management' do
    let(:config) { described_class.new(sample_config, sample_state) }

    describe '#current_chapter' do
      it 'returns current chapter number' do
        expect(config.current_chapter).to eq(5)
      end

      it 'returns 0 when not set' do
        config = described_class.new({}, {})
        expect(config.current_chapter).to eq(0)
      end
    end

    describe '#update_current_chapter' do
      it 'updates current chapter and marks dirty' do
        config.update_current_chapter(10)
        expect(config.current_chapter).to eq(10)
        expect(config).to be_dirty
      end

      it 'creates book section if it does not exist' do
        config = described_class.new({}, {})
        config.update_current_chapter(3)
        expect(config.current_chapter).to eq(3)
      end

      it 'returns self for chaining' do
        result = config.update_current_chapter(7)
        expect(result).to be(config)
      end
    end
  end

  describe 'convenient accessors' do
    let(:config) { described_class.new(sample_config, sample_state) }

    describe '#title' do
      it 'returns English title by default' do
        expect(config.title).to eq('One Review Man')
      end

      it 'returns title for specified language' do
        expect(config.title('ru')).to eq('Ванревьюмэн')
      end

      it 'falls back to top-level title' do
        config = described_class.new({ 'title' => 'Fallback Title' }, {})
        expect(config.title).to eq('Fallback Title')
      end

      it 'returns default when no title' do
        config = described_class.new({}, {})
        expect(config.title).to eq('Untitled')
      end
    end

    describe '#author' do
      it 'returns localized author' do
        expect(config.author).to eq('AI Collective')
        expect(config.author('ru')).to eq('ИИ Коллектив')
      end

      it 'returns default when no author' do
        config = described_class.new({}, {})
        expect(config.author).to eq('Unknown')
      end
    end

    describe '#genre' do
      it 'returns localized genre' do
        expect(config.genre).to eq('Humor/Comedy')
        expect(config.genre('ru')).to eq('Юмор/Комедия')
      end

      it 'returns default when no genre' do
        config = described_class.new({}, {})
        expect(config.genre).to eq('Fiction')
      end
    end

    describe '#themes' do
      it 'returns themes hash' do
        themes = config.themes
        expect(themes['primary']).to eq('workplace comedy')
        expect(themes['secondary']).to eq(['mistaken identity'])
      end

      it 'returns empty hash when no themes' do
        config = described_class.new({}, {})
        expect(config.themes).to eq({})
      end
    end

    describe '#primary_theme' do
      it 'returns primary theme' do
        expect(config.primary_theme).to eq('workplace comedy')
      end

      it 'returns nil when no primary theme' do
        config = described_class.new({}, {})
        expect(config.primary_theme).to be_nil
      end
    end
  end

  describe 'site configuration' do
    let(:config) { described_class.new(sample_config, sample_state) }

    it 'provides site configuration accessors' do
      expect(config.site_url).to eq('https://example.com')
      expect(config.twitter_username).to eq('testuser')
    end
  end

  describe 'persistence' do
    let(:temp_config) { Tempfile.new(['book_config', '.yml']) }
    let(:temp_state) { Tempfile.new(['book_state', '.yml']) }
    let(:config) { described_class.new(sample_config, sample_state, temp_config.path, temp_state.path) }

    after do
      temp_config.close
      temp_config.unlink
      temp_state.close
      temp_state.unlink
    end

    describe '#save!' do
      it 'saves data to files' do
        config.update_current_chapter(15)
        config.update_localized('en', 'title' => 'New Title')
        config.save!

        # Reload and verify
        reloaded = described_class.load_split_config(temp_config.path, temp_state.path)
        expect(reloaded.current_chapter).to eq(15)
        expect(reloaded.title).to eq('New Title')
        expect(config).not_to be_dirty
      end

      it 'creates directory if it does not exist' do
        temp_dir = Dir.mktmpdir
        config_path = File.join(temp_dir, 'nested', 'world_config.yml')
        state_path = File.join(temp_dir, 'nested', 'world_state.yml')
        config = described_class.new(sample_config, sample_state, config_path, state_path)

        config.update_current_chapter(1)
        config.save!

        expect(File.exist?(state_path)).to be true
        FileUtils.rm_rf(temp_dir)
      end
    end

    describe '#dirty?' do
      it 'tracks dirty state' do
        expect(config).not_to be_dirty
        config.update_current_chapter(20)
        expect(config).to be_dirty
        config.save!
        expect(config).not_to be_dirty
      end
    end
  end

  describe 'validation' do
    describe '#validate!' do
      it 'passes for valid structure' do
        config = described_class.new(sample_config, sample_state)
        expect { config.validate! }.not_to raise_error
      end

      it 'raises error for invalid localized structure' do
        data = { 'localized' => 'invalid' }
        expect { described_class.new(data, {}) }.to raise_error(Eidos::WorldConfig::ValidationError)
      end

      it 'raises error for invalid generation structure' do
        data = { 'generation' => 'invalid' }
        expect { described_class.new(data, {}) }.to raise_error(Eidos::WorldConfig::ValidationError)
      end
    end

    describe '#valid?' do
      it 'returns true for valid config' do
        config = described_class.new(sample_config, sample_state)
        expect(config).to be_valid
      end

      it 'returns false for invalid config' do
        config = described_class.new({}, {})
        # Force invalid structure
        config.instance_variable_set(:@config_data, { 'localized' => 'invalid' })
        expect(config).not_to be_valid
      end
    end
  end

  describe 'predicates' do
    let(:config) { described_class.new(sample_config, sample_state) }

    describe '#language?' do
      it 'returns true for languages with data' do
        expect(config.language?('en')).to be true
        expect(config.language?('ru')).to be true
      end

      it 'returns false for languages without data' do
        expect(config.language?('fr')).to be false
      end
    end

    describe '#multilingual?' do
      it 'returns true for configs with multiple languages' do
        expect(config).to be_multilingual
      end

      it 'returns false for single language configs' do
        config = described_class.new({ 'localized' => { 'en' => { 'title' => 'Test' } } }, {})
        expect(config).not_to be_multilingual
      end
    end

    describe '#localized_structure?' do
      it 'returns true when localized structure exists' do
        expect(config.localized_structure?).to be true
      end

      it 'returns false when no localized structure' do
        config = described_class.new({}, {})
        expect(config.localized_structure?).to be false
      end
    end
  end

  describe 'raw data access' do
    let(:config) { described_class.new(sample_config, sample_state) }

    describe '#raw_data' do
      it 'returns a copy of the internal data' do
        raw = config.raw_data
        expect(raw['world']['current_chapter']).to eq(5)

        # Verify it's a copy
        raw['world']['current_chapter'] = 999
        expect(config.current_chapter).to eq(5)
      end
    end

    describe '#get and #set' do
      it 'allows direct access to keys' do
        expect(config.get('site_url')).to eq('https://example.com')

        config.set('new_key', 'new_value')
        expect(config.get('new_key')).to eq('new_value')
        expect(config).to be_dirty
      end
    end
  end
end
