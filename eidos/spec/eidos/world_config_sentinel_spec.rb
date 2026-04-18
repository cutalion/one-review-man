# frozen_string_literal: true

require 'spec_helper'
require 'eidos/world_config'

# T018 (feature 015 US4): when world_config.yml carries the literal sentinel
# value "unspecified" for a metadata field, WorldConfig readers must return
# that exact string — not raise, not substitute a placeholder like "Fiction",
# not treat it as missing. The sentinel is the US4 contract: we tell the user
# nothing about their world's genre/style/setting/theme, rather than lying.
RSpec.describe Eidos::WorldConfig, 'US4 "unspecified" sentinel passthrough' do
  let(:config_data) do
    {
      'localized' => {
        'en' => {
          'story_title' => 'Sample',
          'author' => 'QA',
          'story_genre' => 'unspecified',
          'story_style' => 'unspecified',
          'story_setting' => 'unspecified',
          'themes' => { 'primary' => 'unspecified', 'secondary' => [] }
        }
      }
    }
  end
  let(:state_data) { {} }
  let(:config) { described_class.new(config_data, state_data) }

  describe 'reading "unspecified" metadata fields' do
    it 'returns the literal sentinel for story_genre' do
      expect(config.story_genre).to eq('unspecified')
      expect(config.genre).to eq('unspecified')
    end

    it 'returns the literal sentinel for story_style' do
      expect(config.story_style).to eq('unspecified')
      expect(config.humor_style).to eq('unspecified')
    end

    it 'returns the literal sentinel for story_setting' do
      expect(config.story_setting).to eq('unspecified')
      expect(config.setting).to eq('unspecified')
    end

    it 'returns the literal sentinel for primary_theme' do
      expect(config.primary_theme).to eq('unspecified')
    end

    it 'does not raise on any of the sentinel reads' do
      expect { config.story_genre }.not_to raise_error
      expect { config.story_style }.not_to raise_error
      expect { config.story_setting }.not_to raise_error
      expect { config.primary_theme }.not_to raise_error
    end
  end

  describe 'round-trip YAML' do
    it 'preserves "unspecified" exactly through YAML load/dump' do
      yaml = config_data.to_yaml
      reloaded = YAML.safe_load(yaml)
      expect(reloaded.dig('localized', 'en', 'story_genre')).to eq('unspecified')
      expect(reloaded.dig('localized', 'en', 'story_style')).to eq('unspecified')
      expect(reloaded.dig('localized', 'en', 'story_setting')).to eq('unspecified')
      expect(reloaded.dig('localized', 'en', 'themes', 'primary')).to eq('unspecified')
    end
  end

  describe 'reading when the key is truly absent' do
    # This pins the contract boundary: a field that was never set falls back
    # to the pre-existing defaults (Fiction / narrative / nil). The US4
    # change is that `"unspecified"` is returned as a real value, not treated
    # as "missing". Absent keys still get the legacy default — those worlds
    # are pre-015 and not in scope for the US4 sentinel.
    let(:config_data) { { 'localized' => { 'en' => {} } } }

    it 'returns legacy default for story_genre when key absent' do
      expect(config.story_genre).to eq('Fiction')
    end

    it 'returns legacy default for story_style when key absent' do
      expect(config.story_style).to eq('narrative')
    end

    it 'returns nil for story_setting when key absent (no legacy default)' do
      expect(config.story_setting).to be_nil
    end

    it 'returns nil for primary_theme when themes map absent' do
      expect(config.primary_theme).to be_nil
    end
  end
end
