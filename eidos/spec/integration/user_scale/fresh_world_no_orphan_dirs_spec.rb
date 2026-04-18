# frozen_string_literal: true

# T048 (feature 015 US5): a freshly scaffolded world must not carry
# form-specific empty dirs under content/. The 014 template eagerly
# created content/chapters/ and content/characters/ regardless of
# whether the world's intent had anything to do with chapters —
# the `world new` for the job-hunt demo produced empty chapter
# directories before a single piece was generated.
#
# Covers SC-005 in specs/015-scaffold-hardening/spec.md.

require 'spec_helper'
require 'support/integration_world_builder'
require 'find'

RSpec.describe 'eidos world new: fresh world has no orphan content/ subdirs' do
  include Eidos::Spec::IntegrationWorldBuilder

  it 'does not create content/chapters/ or content/characters/ on scaffold' do
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

      content_root = File.join(scaffold.world_path, 'content')
      aggregate_failures 'clean content/ tree' do
        expect(Dir).to exist(content_root)
        expect(Dir.children(content_root)).to eq([])
        expect(File).not_to exist(File.join(content_root, 'chapters'))
        expect(File).not_to exist(File.join(content_root, 'characters'))
      end
    end
  end
end
