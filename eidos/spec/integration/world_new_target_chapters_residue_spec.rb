# frozen_string_literal: true

# Regression canary for the `target_chapters` removal: a previous
# version of `world new` wrote a `target_chapters` key to the world
# metadata, and `world status` rendered "Progress: 0/Not set" when
# that key was missing. Both were removed; this spec pins that
# removal so the field cannot quietly return.
#
# Feature: specs/013-spec-coverage-backfill (US3, T022)

require 'spec_helper'
require 'fileutils'
require 'open3'
require 'yaml'
require 'tmpdir'

RSpec.describe 'world new + world status: no target_chapters residue' do
  let(:world_cli) { File.expand_path('../../bin/world', __dir__) }

  around(:each) do |example|
    Dir.mktmpdir('orm-013-target-chapters-') do |tmpdir|
      @world_dir = tmpdir
      example.run
    end
  end

  it 'scaffolds a world with no target_chapters and reports progress without "Not set"' do
    new_status = run_world_new(@world_dir)
    expect(new_status).to be_success, 'world new failed; see STDERR from the subprocess'

    config_yml = File.join(@world_dir, 'data', 'world_config.yml')
    state_yml  = File.join(@world_dir, 'data', 'world_state.yml')

    aggregate_failures do
      expect(File).to exist(config_yml)
      expect(File).to exist(state_yml)

      config_tree = YAML.safe_load_file(config_yml)
      state_tree  = YAML.safe_load_file(state_yml)
      expect(yaml_contains_key?(config_tree, 'target_chapters')).to be(false),
                                                                    "target_chapters present in world_config.yml:\n#{config_tree.to_yaml}"
      expect(yaml_contains_key?(state_tree, 'target_chapters')).to be(false),
                                                                   "target_chapters present in world_state.yml:\n#{state_tree.to_yaml}"
    end

    status_stdout, status_stderr, status_exit = Open3.capture3(
      'ruby', world_cli, 'status', '-w', @world_dir
    )
    expect(status_exit).to be_success, "world status failed:\nSTDERR:\n#{status_stderr}"

    aggregate_failures do
      expect(status_stdout).not_to include('target_chapters')
      expect(status_stdout).not_to include('Not set')
      expect(status_stdout).to include('Progress:')
    end
  end

  # Drive `world new` non-interactively via the 015 flag surface (US3).
  # All required values are supplied as Thor options; no stdin reads.
  def run_world_new(root)
    stdout_str, _stderr_str, status = Open3.capture3(
      'ruby', world_cli, 'new', '-w', root, '--quick', '--no-seed',
      '--title', 'My New World',
      '--author', 'Anonymous',
      '--premise', 'A generated world.',
      '--languages', 'en'
    )
    @new_stdout = stdout_str
    status
  end

  def yaml_contains_key?(node, key)
    case node
    when Hash
      return true if node.key?(key)

      node.any? { |_, v| yaml_contains_key?(v, key) }
    when Array
      node.any? { |v| yaml_contains_key?(v, key) }
    else
      false
    end
  end
end
