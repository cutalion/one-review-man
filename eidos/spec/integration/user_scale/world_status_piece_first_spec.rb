# frozen_string_literal: true

# T056 (feature 015 US6): end-to-end assertion that `world status`, run
# against a freshly scaffolded world after two `produce piece` calls,
# reports piece counts by form and does NOT emit the legacy
# chapter-centric "Run: produce chapter" suggestion.
#
# Covers SC-006 in specs/015-scaffold-hardening/spec.md.

require 'spec_helper'
require 'support/integration_world_builder'

RSpec.describe 'eidos world status: piece-first rendering (US6)' do
  include Eidos::Spec::IntegrationWorldBuilder

  it 'groups disk pieces by form and omits the chapter-only suggestion' do
    build_world(
      premise: 'Short vignette about an AI-era job hunt.',
      extra_flags: {
        '--genre' => 'comedy',
        '--style' => 'deadpan',
        '--setting' => 'open-plan office',
        '--theme' => 'disillusionment'
      }
    ) do |scaffold|
      expect(scaffold).to be_success, "world new failed:\n#{scaffold.stderr}"

      # Empty world: piece-first hint, no chapter suggestion.
      empty_status = Eidos::Spec::IntegrationWorldBuilder.run_eidos(
        'world', 'status', '-w', scaffold.world_path
      )
      expect(empty_status).to be_success, "world status (empty) failed:\n#{empty_status.stderr}"
      aggregate_failures 'empty-world status shape' do
        expect(empty_status.stdout).not_to match(/Run:\s*produce chapter/)
        expect(empty_status.stdout).not_to match(/Ready for chapter generation/)
        expect(empty_status.stdout).to include('produce piece')
      end

      # Produce a haiku, then a vignette.
      haiku = Eidos::Spec::IntegrationWorldBuilder.run_eidos(
        'produce', 'piece', '--form', 'haiku',
        '-w', scaffold.world_path, '--prompt', 'silent code review',
        env: { 'MOCK_AI' => 'true' }
      )
      expect(haiku).to be_success, "produce haiku failed:\nSTDERR:\n#{haiku.stderr}"

      vignette = Eidos::Spec::IntegrationWorldBuilder.run_eidos(
        'produce', 'piece', '--form', 'vignette',
        '-w', scaffold.world_path, '--prompt', 'forgotten commit',
        env: { 'MOCK_AI' => 'true' }
      )
      expect(vignette).to be_success, "produce vignette failed:\nSTDERR:\n#{vignette.stderr}"

      populated = Eidos::Spec::IntegrationWorldBuilder.run_eidos(
        'world', 'status', '-w', scaffold.world_path
      )
      expect(populated).to be_success, "world status failed:\n#{populated.stderr}"

      aggregate_failures 'piece-first counts in status output' do
        expect(populated.stdout).to match(/haiku:\s*1/)
        expect(populated.stdout).to match(/vignette:\s*1/)
        expect(populated.stdout).to match(/Total:\s*2/)
        expect(populated.stdout).not_to match(/Run:\s*produce chapter/)
      end
    end
  end
end
