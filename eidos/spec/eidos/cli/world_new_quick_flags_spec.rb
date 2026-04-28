# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'eidos/cli/world'

# T007 + T008 (feature 015 US3): the non-interactive `world new --quick`
# flag surface defined in specs/015-scaffold-hardening/contracts/cli-flags.md.
#
# These tests exercise the CLI as a black box — they instantiate the Thor
# class and drive it with the argv surface a user would type. They do NOT
# shell out; that's the integration suite's job (T010/T011).
#
# Note on Thor keys: bare flag names become symbol keys in
# `commands['new'].options`; hyphenated flag names stay as string keys.
# Hence `:title` but `'default-language'`.
RSpec.describe Eidos::CLI::World, 'US3 --quick flag surface' do
  let(:tmp_dir) { Dir.mktmpdir('world_new_quick_flags') }

  after { FileUtils.rm_rf(tmp_dir) if Dir.exist?(tmp_dir) }

  # Captures stdout/stderr AND preserves the captured bytes even when the
  # block raises (SystemExit on validation failure). Writes into the
  # caller-supplied hash so `expect { ... }.to raise_error` still applies
  # to the block itself.
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

  # ----- T007: Thor option declarations ------------------------------------

  describe 'declared Thor options for `new`' do
    let(:new_options) { described_class.commands['new'].options }

    it 'declares --title as an optional String' do
      opt = new_options[:title]
      expect(opt).not_to be_nil, 'expected --title to be declared on `new`'
      expect(opt.type).to eq(:string)
    end

    it 'declares --author as an optional String' do
      opt = new_options[:author]
      expect(opt).not_to be_nil, 'expected --author to be declared on `new`'
      expect(opt.type).to eq(:string)
    end

    it 'declares --premise as an optional String (multi-line allowed)' do
      opt = new_options[:premise]
      expect(opt).not_to be_nil, 'expected --premise to be declared on `new`'
      expect(opt.type).to eq(:string)
    end

    it 'declares --languages as a String (comma-separated codes)' do
      opt = new_options[:languages]
      expect(opt).not_to be_nil, 'expected --languages to be declared on `new`'
      expect(opt.type).to eq(:string)
    end

    it 'declares --default-language as a String' do
      opt = new_options['default-language']
      expect(opt).not_to be_nil, 'expected --default-language to be declared on `new`'
      expect(opt.type).to eq(:string)
    end

    # Covers the contract rule that no flag is hard-required at the Thor
    # level — required-flag validation is done by the command body so we
    # can emit a combined error naming every missing flag at once.
    it 'does not mark any of the quick-setup flags as Thor-required' do
      [:title, :author, :premise, :languages, 'default-language'].each do |key|
        opt = new_options[key]
        expect(opt&.required).not_to eq(true),
                                     "#{key} should not be Thor-required (command validates instead)"
      end
    end
  end

  # ----- Flag-driven scaffolding (happy path) -------------------------------

  describe 'non-interactive --quick with all required flags' do
    it 'writes world_config.yml from flag values, no stdin reads' do
      captured = {}
      capture_streams(into: captured) do
        described_class.start(
          [
            'new', '-w', tmp_dir, '--quick', '--no-seed',
            '--title', 'Test World',
            '--author', 'QA',
            '--premise', "line one\nline two\nline three",
            '--languages', 'en'
          ]
        )
      end

      config_path = File.join(tmp_dir, 'data', 'world_config.yml')
      expect(File.exist?(config_path)).to be(true), "stderr was: #{captured[:stderr]}"

      config = YAML.safe_load_file(config_path)
      expect(config['languages']).to eq(['en'])
      expect(config['default_language']).to eq('en')
      expect(config.dig('localized', 'en', 'story_title')).to eq('Test World')
      expect(config.dig('localized', 'en', 'author')).to eq('QA')
      expect(config.dig('localized', 'en', 'subtitle')).to eq("line one\nline two\nline three")
    end

    it 'parses --languages as comma-separated and honours --default-language' do
      captured = {}
      capture_streams(into: captured) do
        described_class.start(
          [
            'new', '-w', tmp_dir, '--quick', '--no-seed',
            '--title', 'Multi-Lang',
            '--author', 'QA',
            '--premise', 'A premise.',
            '--languages', 'en,ru',
            '--default-language', 'ru'
          ]
        )
      end

      config = YAML.safe_load_file(File.join(tmp_dir, 'data', 'world_config.yml'))
      expect(config['languages']).to eq(%w[en ru])
      expect(config['default_language']).to eq('ru')
    end

    it 'defaults --languages to [en] and --default-language to en when flag omitted' do
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
      expect(config['languages']).to eq(['en'])
      expect(config['default_language']).to eq('en')
    end
  end

  # ----- T008: missing-flag error ------------------------------------------

  describe 'missing required flags under --quick' do
    it 'exits non-zero and names every missing flag when only --title is passed' do
      captured = {}
      expect do
        capture_streams(into: captured) do
          described_class.start(
            ['new', '-w', tmp_dir, '--quick', '--no-seed', '--title', 'OnlyTitle']
          )
        end
      end.to raise_error(SystemExit) { |e| expect(e.status).not_to eq(0) }

      expect(captured[:stderr]).to include('--author')
      expect(captured[:stderr]).to include('--premise')
      # "Missing:" section should not list --title because it was supplied.
      expect(captured[:stderr]).to match(/Missing:[^\n]*(?!--title)/)
    end

    it 'exits non-zero when --title is the sole missing flag' do
      captured = {}
      expect do
        capture_streams(into: captured) do
          described_class.start(
            [
              'new', '-w', tmp_dir, '--quick', '--no-seed',
              '--author', 'A', '--premise', 'P'
            ]
          )
        end
      end.to raise_error(SystemExit) { |e| expect(e.status).not_to eq(0) }

      # The "Missing:" line names --title.
      expect(captured[:stderr]).to match(/Missing:[^\n]*--title/)
    end

    it 'does not create the world directory when required flags are missing' do
      captured = {}
      expect do
        capture_streams(into: captured) do
          described_class.start(
            ['new', '-w', tmp_dir, '--quick', '--no-seed', '--title', 'X']
          )
        end
      end.to raise_error(SystemExit)

      # tmp_dir itself is created by Dir.mktmpdir; what must NOT exist is
      # the world scaffolding beneath it.
      expect(File.exist?(File.join(tmp_dir, 'data', 'world_config.yml'))).to be(false)
      expect(Dir.exist?(File.join(tmp_dir, 'data'))).to be(false)
    end

    it 'rejects --default-language that is not a member of --languages' do
      captured = {}
      expect do
        capture_streams(into: captured) do
          described_class.start(
            [
              'new', '-w', tmp_dir, '--quick', '--no-seed',
              '--title', 'T', '--author', 'A', '--premise', 'P',
              '--languages', 'en,ru', '--default-language', 'fr'
            ]
          )
        end
      end.to raise_error(SystemExit) { |e| expect(e.status).not_to eq(0) }

      expect(captured[:stderr]).to match(/default-language/)
      expect(captured[:stderr]).to include('fr')
    end

    it 'rejects --languages that is empty after trimming' do
      captured = {}
      expect do
        capture_streams(into: captured) do
          described_class.start(
            [
              'new', '-w', tmp_dir, '--quick', '--no-seed',
              '--title', 'T', '--author', 'A', '--premise', 'P',
              '--languages', '  ,  '
            ]
          )
        end
      end.to raise_error(SystemExit) { |e| expect(e.status).not_to eq(0) }
    end
  end
end
