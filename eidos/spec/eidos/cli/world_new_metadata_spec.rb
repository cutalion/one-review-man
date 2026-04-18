# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'eidos/cli/world'

# T017 (feature 015 US4): non-interactive `world new --quick` must route the
# four metadata flags (--genre / --style / --setting / --theme) into the world
# config verbatim when provided, and write the literal sentinel "unspecified"
# when absent. No regex heuristics, no substitution.
#
# Contract: specs/015-scaffold-hardening/contracts/cli-flags.md §world new.
RSpec.describe Eidos::CLI::World, 'US4 --quick metadata flags' do
  let(:tmp_dir) { Dir.mktmpdir('world_new_metadata') }

  after { FileUtils.rm_rf(tmp_dir) if Dir.exist?(tmp_dir) }

  def capture_streams(into:)
    original_out = $stdout
    original_err = $stderr
    out = StringIO.new
    err = StringIO.new
    $stdout = out
    $stderr = err
    begin
      yield
    ensure
      into[:stdout] = out.string
      into[:stderr] = err.string
      $stdout = original_out
      $stderr = original_err
    end
  end

  # ----- Thor option declarations -----------------------------------------

  describe 'declared Thor options for `new`' do
    let(:new_options) { described_class.commands['new'].options }

    it 'declares --genre as an optional String' do
      opt = new_options[:genre]
      expect(opt).not_to be_nil, 'expected --genre to be declared on `new`'
      expect(opt.type).to eq(:string)
    end

    it 'declares --style as an optional String' do
      opt = new_options[:style]
      expect(opt).not_to be_nil, 'expected --style to be declared on `new`'
      expect(opt.type).to eq(:string)
    end

    it 'declares --setting as an optional String' do
      opt = new_options[:setting]
      expect(opt).not_to be_nil, 'expected --setting to be declared on `new`'
      expect(opt.type).to eq(:string)
    end

    it 'declares --theme as an optional String' do
      opt = new_options[:theme]
      expect(opt).not_to be_nil, 'expected --theme to be declared on `new`'
      expect(opt.type).to eq(:string)
    end

    it 'does not mark any metadata flag as Thor-required' do
      %i[genre style setting theme].each do |key|
        opt = new_options[key]
        expect(opt&.required).not_to eq(true),
                                     "#{key} should not be Thor-required (optional metadata)"
      end
    end
  end

  # ----- Flag values flow through to world_config.yml verbatim -----------

  describe 'metadata flags land in world_config.yml verbatim when provided' do
    it 'routes --genre/--style/--setting/--theme into localized.en fields' do
      captured = {}
      capture_streams(into: captured) do
        described_class.start(
          [
            'new', '-w', tmp_dir, '--quick', '--no-seed',
            '--title', 'Test', '--author', 'QA',
            '--premise', 'A premise.',
            '--genre', 'comedy',
            '--style', 'deadpan',
            '--setting', 'open-plan office',
            '--theme', 'disillusionment'
          ]
        )
      end

      config_path = File.join(tmp_dir, 'data', 'world_config.yml')
      expect(File.exist?(config_path)).to be(true), "stderr was: #{captured[:stderr]}"

      config = YAML.safe_load_file(config_path)
      localized_en = config.dig('localized', 'en')
      expect(localized_en['story_genre']).to eq('comedy')
      expect(localized_en['story_style']).to eq('deadpan')
      expect(localized_en['story_setting']).to eq('open-plan office')
      expect(localized_en.dig('themes', 'primary')).to eq('disillusionment')
    end

    it 'preserves multi-word metadata values (no split, no heuristic rewrite)' do
      captured = {}
      capture_streams(into: captured) do
        described_class.start(
          [
            'new', '-w', tmp_dir, '--quick', '--no-seed',
            '--title', 'T', '--author', 'A', '--premise', 'P',
            '--setting', 'post-apocalyptic Toronto subway tunnels'
          ]
        )
      end

      config = YAML.safe_load_file(File.join(tmp_dir, 'data', 'world_config.yml'))
      expect(config.dig('localized', 'en', 'story_setting'))
        .to eq('post-apocalyptic Toronto subway tunnels')
    end
  end

  # ----- Absent metadata flags write the "unspecified" sentinel ----------

  describe 'absent metadata flags write the literal sentinel "unspecified"' do
    it 'writes story_genre/style/setting/themes.primary as "unspecified"' do
      captured = {}
      capture_streams(into: captured) do
        described_class.start(
          [
            'new', '-w', tmp_dir, '--quick', '--no-seed',
            '--title', 'T', '--author', 'A', '--premise', 'P'
          ]
        )
      end

      config = YAML.safe_load_file(File.join(tmp_dir, 'data', 'world_config.yml'))
      localized_en = config.dig('localized', 'en')
      expect(localized_en['story_genre']).to eq('unspecified')
      expect(localized_en['story_style']).to eq('unspecified')
      expect(localized_en['story_setting']).to eq('unspecified')
      expect(localized_en.dig('themes', 'primary')).to eq('unspecified')
    end

    it 'does NOT substitute a regex-inferred value when premise mentions trigger words' do
      # Before US4 these premise keywords would have triggered the regex
      # heuristics (fantasy / mystery / space / adventure / humor). Under US4,
      # no flag → "unspecified" regardless of what the premise contains.
      captured = {}
      capture_streams(into: captured) do
        described_class.start(
          [
            'new', '-w', tmp_dir, '--quick', '--no-seed',
            '--title', 'T', '--author', 'A',
            '--premise', 'A funny space adventure with magic and mystery in a detective office.'
          ]
        )
      end

      config = YAML.safe_load_file(File.join(tmp_dir, 'data', 'world_config.yml'))
      localized_en = config.dig('localized', 'en')
      expect(localized_en['story_genre']).to eq('unspecified')
      expect(localized_en['story_style']).to eq('unspecified')
      expect(localized_en['story_setting']).to eq('unspecified')
      expect(localized_en.dig('themes', 'primary')).to eq('unspecified')
    end
  end

  # ----- Mixed (some flags provided, others absent) -----------------------

  describe 'partial metadata flags' do
    it 'honours provided flags verbatim and sentinels the rest' do
      captured = {}
      capture_streams(into: captured) do
        described_class.start(
          [
            'new', '-w', tmp_dir, '--quick', '--no-seed',
            '--title', 'T', '--author', 'A', '--premise', 'P',
            '--genre', 'comedy'
          ]
        )
      end

      config = YAML.safe_load_file(File.join(tmp_dir, 'data', 'world_config.yml'))
      localized_en = config.dig('localized', 'en')
      expect(localized_en['story_genre']).to eq('comedy')
      expect(localized_en['story_style']).to eq('unspecified')
      expect(localized_en['story_setting']).to eq('unspecified')
      expect(localized_en.dig('themes', 'primary')).to eq('unspecified')
    end
  end
end
