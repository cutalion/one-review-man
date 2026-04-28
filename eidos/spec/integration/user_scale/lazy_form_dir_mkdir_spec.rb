# frozen_string_literal: true

# T049 (feature 015 US5): after scaffold + `produce piece --form haiku`,
# content/pieces/haiku/ must exist with the produced file — demonstrating
# that form dirs are created lazily at write time, not eagerly at scaffold.
#
# Covers FR-015 in specs/015-scaffold-hardening/spec.md.

require 'spec_helper'
require 'support/integration_world_builder'

RSpec.describe 'eidos produce piece: lazy form directory creation' do
  include Eidos::Spec::IntegrationWorldBuilder

  it 'creates content/pieces/haiku/ on first produce of the form' do
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

      haiku_dir = File.join(scaffold.world_path, 'content', 'pieces', 'haiku')
      expect(File).not_to exist(haiku_dir), 'haiku dir should not exist before produce'

      produce = Eidos::Spec::IntegrationWorldBuilder.run_eidos(
        'produce', 'piece', '--form', 'haiku', '-w', scaffold.world_path,
        '--prompt', 'about a silent code review',
        env: { 'MOCK_AI' => 'true' }
      )
      expect(produce).to be_success, "produce haiku failed:\nSTDOUT:\n#{produce.stdout}\nSTDERR:\n#{produce.stderr}"

      aggregate_failures 'haiku dir created with a piece file' do
        expect(Dir).to exist(haiku_dir), "expected #{haiku_dir} to exist after first produce"
        md_files = Dir.glob(File.join(haiku_dir, '*.md'))
        expect(md_files.length).to be >= 1
      end
    end
  end
end
