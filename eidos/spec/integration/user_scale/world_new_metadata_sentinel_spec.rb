# frozen_string_literal: true

# T019 (feature 015 US4): without explicit metadata flags, a freshly
# scaffolded world writes the literal sentinel "unspecified" for genre,
# style, setting, and primary theme — and `world status` surfaces those
# unspecified fields as an action item.
#
# Covers SC-002 (first half) in specs/015-scaffold-hardening/spec.md.

require 'spec_helper'
require 'yaml'
require 'support/integration_world_builder'

RSpec.describe 'world new --quick: absent metadata flags write "unspecified"' do
  include Eidos::Spec::IntegrationWorldBuilder

  it 'writes all four metadata fields as "unspecified" and world status lists them' do
    build_world(premise: 'A premise with fantasy wizards, space robots, and mystery.') do |result|
      expect(result).to be_success, "world new failed:\n#{result.stderr}"

      config = YAML.safe_load_file(File.join(result.world_path, 'data', 'world_config.yml'))
      localized_en = config.dig('localized', 'en')

      aggregate_failures 'all four metadata fields pinned to sentinel' do
        expect(localized_en['story_genre']).to eq('unspecified')
        expect(localized_en['story_style']).to eq('unspecified')
        expect(localized_en['story_setting']).to eq('unspecified')
        expect(localized_en.dig('themes', 'primary')).to eq('unspecified')
      end

      status = Eidos::Spec::IntegrationWorldBuilder.run_eidos(
        'world', 'status', '-w', result.world_path
      )
      expect(status).to be_success, "world status failed:\n#{status.stderr}"

      # Status output must flag the unspecified fields as an action item;
      # ordering within the list is not part of the contract.
      aggregate_failures 'status output surfaces the unspecified fields' do
        expect(status.stdout).to include('Unspecified fields')
        expect(status.stdout).to include('genre')
        expect(status.stdout).to include('style')
        expect(status.stdout).to include('setting')
        expect(status.stdout).to include('theme')
      end
    end
  end
end
