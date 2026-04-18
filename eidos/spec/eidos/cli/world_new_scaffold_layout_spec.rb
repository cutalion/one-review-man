# frozen_string_literal: true

# T047 (feature 015 US5): `world new` used to eagerly create
# `content/chapters/` and `content/characters/` even though the
# new piece-first architecture doesn't require either — form dirs
# should appear on first `produce`. This spec drives
# `create_directories` directly and asserts the `content/` tree
# is empty after scaffold.
#
# Contract: specs/015-scaffold-hardening/spec.md FR-015.

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'eidos/cli/world'

RSpec.describe Eidos::CLI::World, 'US5 scaffold layout' do
  let(:tmp_dir) { Dir.mktmpdir('world_new_scaffold_') }

  after { FileUtils.rm_rf(tmp_dir) if Dir.exist?(tmp_dir) }

  it 'creates no orphan subdirectories under content/' do
    world_cli = described_class.new
    world_cli.send(:create_directories, tmp_dir)

    content_root = File.join(tmp_dir, 'content')
    expect(Dir).to exist(content_root)
    expect(Dir.children(content_root)).to eq([])
  end

  it 'still creates the data/ directory (canonical world data root)' do
    world_cli = described_class.new
    world_cli.send(:create_directories, tmp_dir)

    expect(Dir).to exist(File.join(tmp_dir, 'data'))
  end
end
