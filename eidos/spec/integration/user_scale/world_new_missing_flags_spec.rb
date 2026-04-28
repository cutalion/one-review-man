# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'support/integration_world_builder'

# T011 (feature 015 US3) — FR-010.
#
# Shelling `eidos world new --quick` without the required flags must
# (a) exit non-zero,
# (b) name the missing flags on stderr, and
# (c) leave no world scaffolding on disk at the target path.
RSpec.describe 'world new --quick missing required flags (015 US3)' do
  let(:eidos_bin) { Eidos::Spec::IntegrationWorldBuilder::EIDOS_BIN }
  let(:tmp_dir) { Dir.mktmpdir('orm-015-missing-flags-') }

  after { FileUtils.rm_rf(tmp_dir) if Dir.exist?(tmp_dir) }

  def shell_new(*argv)
    stdout, stderr, status = Open3.capture3(
      'ruby', eidos_bin,
      'world', 'new', '--quick', '-w', tmp_dir, '--no-seed',
      *argv
    )
    { stdout: stdout, stderr: stderr, status: status }
  end

  it 'exits non-zero and names --author, --premise as missing when only --title is given' do
    result = shell_new('--title', 'OnlyTitle')

    expect(result[:status].success?).to be(false), "expected non-zero exit, got stderr: #{result[:stderr]}"
    expect(result[:stderr]).to include('--author')
    expect(result[:stderr]).to include('--premise')
  end

  it 'exits non-zero and names all three missing when no flags are given' do
    result = shell_new

    expect(result[:status].success?).to be(false)
    expect(result[:stderr]).to include('--title')
    expect(result[:stderr]).to include('--author')
    expect(result[:stderr]).to include('--premise')
  end

  it 'leaves no world scaffolding on disk when required flags are missing' do
    shell_new('--title', 'X')

    expect(File.exist?(File.join(tmp_dir, 'data', 'world_config.yml'))).to be(false)
    expect(Dir.exist?(File.join(tmp_dir, 'data'))).to be(false)
    expect(Dir.exist?(File.join(tmp_dir, 'content'))).to be(false)
  end

  it 'rejects --default-language not in --languages with a clear message' do
    result = shell_new(
      '--title', 'T', '--author', 'A', '--premise', 'P',
      '--languages', 'en,ru', '--default-language', 'fr'
    )

    expect(result[:status].success?).to be(false)
    expect(result[:stderr]).to match(/default-language/)
    expect(result[:stderr]).to include('fr')
  end
end
