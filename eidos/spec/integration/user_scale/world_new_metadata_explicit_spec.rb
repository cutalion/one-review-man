# frozen_string_literal: true

# T020 (feature 015 US4): explicit `--genre/--style/--setting/--theme` flags
# land in world_config.yml verbatim — no overlay, no heuristic rewrite, no
# case normalization. And when all four fields are set, `world status` does
# NOT emit the "Unspecified fields" action-item line.
#
# Covers SC-002 (second half) in specs/015-scaffold-hardening/spec.md.

require 'spec_helper'
require 'yaml'
require 'support/integration_world_builder'

RSpec.describe 'world new --quick: explicit metadata flags persist verbatim' do
  include Eidos::Spec::IntegrationWorldBuilder

  it 'stores --genre/--style/--setting/--theme verbatim and status stays silent' do
    build_world(
      premise: 'Arthur quits his job at the worst possible moment.',
      extra_flags: {
        '--genre' => 'comedy',
        '--style' => 'deadpan',
        '--setting' => 'open-plan office',
        '--theme' => 'disillusionment'
      }
    ) do |result|
      expect(result).to be_success, "world new failed:\n#{result.stderr}"

      config = YAML.safe_load_file(File.join(result.world_path, 'data', 'world_config.yml'))
      localized_en = config.dig('localized', 'en')

      aggregate_failures 'explicit flag values written verbatim' do
        expect(localized_en['story_genre']).to eq('comedy')
        expect(localized_en['story_style']).to eq('deadpan')
        expect(localized_en['story_setting']).to eq('open-plan office')
        expect(localized_en.dig('themes', 'primary')).to eq('disillusionment')
      end

      status = Eidos::Spec::IntegrationWorldBuilder.run_eidos(
        'world', 'status', '-w', result.world_path
      )
      expect(status).to be_success, "world status failed:\n#{status.stderr}"
      expect(status.stdout).not_to include('Unspecified fields')
    end
  end

  it 'accepts multi-word values (spaces, hyphens, punctuation) unchanged' do
    build_world(
      premise: 'Any premise.',
      extra_flags: {
        '--setting' => 'post-apocalyptic Toronto subway tunnels',
        '--theme' => "loneliness & obsolescence"
      }
    ) do |result|
      expect(result).to be_success, "world new failed:\n#{result.stderr}"

      config = YAML.safe_load_file(File.join(result.world_path, 'data', 'world_config.yml'))
      localized_en = config.dig('localized', 'en')

      expect(localized_en['story_setting']).to eq('post-apocalyptic Toronto subway tunnels')
      expect(localized_en.dig('themes', 'primary')).to eq('loneliness & obsolescence')
    end
  end
end
