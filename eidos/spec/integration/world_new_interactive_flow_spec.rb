# frozen_string_literal: true

# Realistic interactive-flow coverage for `eidos world new`.
# Drives the CLI via `StdinDriver.drive_cli` (Open3.popen3 + scripted
# stdin) — no RSpec-level stubbing of `ask` / `yes?`. Both the
# all-defaults path and the all-custom-answers path must produce a
# valid world on disk.
#
# A third example transiently monkey-patches the in-process `ask`
# helper so one call returns `nil`, and asserts the CLI surfaces that
# as a real failure (the `strip`-on-nil regression class).
#
# Feature: specs/013-spec-coverage-backfill (US4, T024 + T025)

require 'spec_helper'
require 'yaml'
require 'fileutils'
require 'stringio'
require_relative '../support/stdin_driver'
require 'eidos/cli/world'

RSpec.describe 'world new: realistic interactive flow' do
  around(:each) do |example|
    Dir.mktmpdir('orm-013-world-new-interactive-') do |tmpdir|
      @world_dir = tmpdir
      example.run
    end
  end

  # Detailed (non-quick) `world new` asks 9 questions in this order:
  #   1. World title           (default: "My New World")
  #   2. Author name           (default: "Anonymous")
  #   3. Short description     (default: "A generated world.")
  #   4. Languages             (default: "en")
  #   5. Genre                 (default: "unspecified" — feature 015 US4;
  #                             the pre-015 "fantasy" regex-inferred default
  #                             was a banned silent-fallback pattern)
  #   6. Writing style         (default: "unspecified")
  #   7. Setting               (default: "unspecified")
  #   8. Primary theme         (default: "unspecified")
  #   9. Secondary themes      (default: "")
  describe 'all defaults' do
    it 'scaffolds a world with the default answers when stdin is bare newlines' do
      result = Eidos::Spec::StdinDriver.drive_cli(
        argv: ['world', 'new', '-w', @world_dir, '--no-seed'],
        input_lines: [''] * 9
      )

      expect(result).to be_success, "stderr:\n#{result.stderr}"

      config = YAML.safe_load_file(File.join(@world_dir, 'data', 'world_config.yml'))
      en     = config.dig('localized', 'en') || {}
      aggregate_failures do
        expect(en['story_title']).to   eq('My New World')
        expect(en['author']).to        eq('Anonymous')
        expect(en['subtitle']).to      eq('A generated world.')
        expect(en['story_genre']).to   eq('unspecified')
        expect(en['story_style']).to   eq('unspecified')
        expect(en['story_setting']).to eq('unspecified')
        expect(en.dig('themes', 'primary')).to eq('unspecified')
        # Write-path contract: no legacy keys under the localized section.
        expect(en.keys).not_to include('title', 'genre', 'setting', 'humor_style',
                                      'book_title', 'book_genre', 'book_setting', 'book_style')
      end
    end
  end

  describe 'all custom answers' do
    it 'persists every user-provided value to world_config.yml' do
      custom = {
        title: 'Fixture Saga',
        author: 'Integration Tester',
        description: 'A spec-driven storyworld.',
        languages: 'en',
        genre: 'mystery',
        style: 'suspenseful',
        setting: 'abandoned observatory',
        primary_theme: 'discovery',
        secondary_themes: 'loss, obsession'
      }
      input_lines = custom.values

      result = Eidos::Spec::StdinDriver.drive_cli(
        argv: ['world', 'new', '-w', @world_dir, '--no-seed'],
        input_lines: input_lines
      )

      expect(result).to be_success, "stderr:\n#{result.stderr}"

      config = YAML.safe_load_file(File.join(@world_dir, 'data', 'world_config.yml'))
      en = config.dig('localized', 'en') || {}
      aggregate_failures do
        expect(en['story_title']).to   eq(custom[:title])
        expect(en['author']).to        eq(custom[:author])
        expect(en['subtitle']).to      eq(custom[:description])
        expect(en['story_genre']).to   eq(custom[:genre])
        expect(en['story_style']).to   eq(custom[:style])
        expect(en['story_setting']).to eq(custom[:setting])
        expect(en.dig('themes', 'primary')).to eq(custom[:primary_theme])
        expect(en.dig('themes', 'secondary')).to eq(%w[loss obsession])
        expect(en.keys).not_to include('title', 'genre', 'setting', 'humor_style',
                                      'book_title', 'book_genre', 'book_setting', 'book_style')
      end
    end
  end

  describe 'nil-return regression' do
    let(:original_ask) { Eidos::CLI::World.instance_method(:ask) }

    before do
      original = original_ask
      Eidos::CLI::World.define_method(:ask) do |question, *args, **kwargs|
        # Transient monkey-patch: simulate a prompt handler that returns
        # nil on a single call (previously caused `.strip` to blow up
        # further downstream — the "strip-on-nil" class of bug).
        return nil if question.to_s.include?('Secondary themes')

        # All other prompts accept the default by returning it directly
        # (avoids needing to redirect $stdin in-process).
        kwargs[:default] || ''
      end
    end

    after do
      saved = original_ask
      Eidos::CLI::World.define_method(:ask, saved)
    end

    it 'surfaces the nil return as a raised error rather than silently succeeding' do
      expect do
        Eidos::CLI::World.start(['new', '-w', @world_dir, '--no-seed'])
      end.to raise_error(NoMethodError, /nil/i)
    end
  end
end
