# frozen_string_literal: true

# T042 (feature 015 US2): a well-formed canon-delta declaring a
# character by name — no explicit `id` — must result in a file on
# disk under `data/story_bible/characters/<slug>.yml`. The 014
# job-hunt demo produced a comic-script piece whose delta declared
# Arthur + Arthur's Apartment, got `applied_at` stamped with
# `parse_error: nil`, and yet `data/story_bible/characters/` stayed
# empty. Root cause: `apply_character`/`apply_location` had
# `return nil unless id` and the parser didn't derive id from name.
#
# Covers SC-003 in specs/015-scaffold-hardening/spec.md.
#
# Mechanics: MOCK_RESPONSE=canon_delta_arthur_well_formed (fixture
# added in T005) forces MockLLMService#generate_text to return a
# piece body whose tail carries `new_characters: [{name: Arthur,
# description: A programmer}]`. The produce → apply pipeline must:
#   1. Derive id='arthur' via ValidationUtils.slugify in normalize_section.
#   2. Persist a file at data/story_bible/characters/arthur.yml.
#   3. The file's `description` matches the canon-delta declaration.

require 'spec_helper'
require 'support/integration_world_builder'
require 'yaml'

RSpec.describe 'eidos produce: canon-delta entities persist to bible' do
  include Eidos::Spec::IntegrationWorldBuilder

  it 'writes data/story_bible/characters/arthur.yml after produce + apply' do
    build_world(
      premise: 'Deadpan office vignette about an AI-replaced recruiter.',
      extra_flags: {
        '--genre' => 'comedy',
        '--style' => 'deadpan',
        '--setting' => 'open-plan office',
        '--theme' => 'disillusionment'
      }
    ) do |scaffold|
      expect(scaffold).to be_success, "world new failed:\n#{scaffold.stderr}"

      produce = Eidos::Spec::IntegrationWorldBuilder.run_eidos(
        'produce', 'vignette', '-w', scaffold.world_path,
        '--prompt', 'Any prompt; the mock response is canned.',
        env: { 'MOCK_AI' => 'true', 'MOCK_RESPONSE' => 'canon_delta_arthur_well_formed' }
      )
      expect(produce).to be_success, "produce vignette failed:\nSTDOUT:\n#{produce.stdout}\nSTDERR:\n#{produce.stderr}"

      arthur_path = File.join(scaffold.world_path, 'data', 'story_bible', 'characters', 'arthur.yml')

      aggregate_failures 'arthur.yml persisted with matching description' do
        expect(File).to exist(arthur_path), "expected #{arthur_path} to exist after apply"
        data = YAML.load_file(arthur_path)
        expect(data['id']).to eq('arthur')
        expect(data['name']).to eq('Arthur')
        expect(data['description']).to eq('A programmer')
      end
    end
  end
end
