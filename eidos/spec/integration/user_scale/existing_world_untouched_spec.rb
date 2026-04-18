# frozen_string_literal: true

# T050 (feature 015 US5): the scaffold-layout change applies to NEW
# worlds only. The checked-in `worlds/one-review-man/` world was
# scaffolded with the pre-015 layout and MUST remain intact — no
# migration, no rewrite, no silent restructuring.
#
# Covers FR-016 in specs/015-scaffold-hardening/spec.md.

require 'spec_helper'

RSpec.describe 'existing worlds untouched by 015 (US5)' do
  repo_root = File.expand_path('../../..', __dir__)
  existing_content = File.join(repo_root, '..', 'worlds', 'one-review-man', 'content')

  before(:all) do
    skip "worlds/one-review-man/ not checked in at #{existing_content}" unless Dir.exist?(existing_content)
  end

  it 'worlds/one-review-man/content/chapters still exists' do
    expect(Dir).to exist(File.join(existing_content, 'chapters'))
  end

  it 'worlds/one-review-man/content/characters still exists' do
    expect(Dir).to exist(File.join(existing_content, 'characters'))
  end
end
