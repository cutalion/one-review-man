# frozen_string_literal: true

# T031 (feature 015 US1): a canon-delta whose LLM emitted bare-string
# entries instead of mappings must surface every drop as an
# `[parse-drop]` finding in `eidos canon review` — not a silent stderr
# warning that the user never sees.
#
# Covers SC-004 in specs/015-scaffold-hardening/spec.md.
#
# Mechanics: MOCK_RESPONSE=canon_delta_bare_string (fixture added in T005)
# forces MockLLMService#generate_text to return a piece body whose
# ---CANON-DELTA--- tail carries two bare-string entries — one in
# new_characters, one in new_facts. The produce → apply pipeline must:
#   1. Drop each bare string into parse_error.drops.
#   2. Open one AuditFinding{kind: "parse-drop"} per drop.
#   3. Render both as `[parse-drop]` lines in `canon review`.

require 'spec_helper'
require 'support/integration_world_builder'

RSpec.describe 'eidos canon review: parse-drop findings visible' do
  include Eidos::Spec::IntegrationWorldBuilder

  it 'surfaces each bare-string drop as an [parse-drop] finding with section and value' do
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
        env: { 'MOCK_AI' => 'true', 'MOCK_RESPONSE' => 'canon_delta_bare_string' }
      )
      expect(produce).to be_success, "produce vignette failed:\nSTDOUT:\n#{produce.stdout}\nSTDERR:\n#{produce.stderr}"

      review = Eidos::Spec::IntegrationWorldBuilder.run_eidos(
        'canon', 'review', '-w', scaffold.world_path
      )
      expect(review).to be_success, "canon review failed:\nSTDERR:\n#{review.stderr}"

      aggregate_failures 'canon review surfaces both bare-string drops' do
        expect(review.stdout).to include('[parse-drop]')
        # Rendered twice — one per drop in the fixture.
        expect(review.stdout.scan('[parse-drop]').length).to eq(2)
        # Each rendering names the offending section and the verbatim value.
        expect(review.stdout).to include('new_characters')
        expect(review.stdout).to include('new_facts')
        expect(review.stdout).to include('Arthur is a programmer')
        expect(review.stdout).to include('the office is grim')
      end
    end
  end
end
