# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'fileutils'
require 'eidos/cli/world'

RSpec.describe Eidos::CLI::World do
  # Covers T009 (interactive defaults appear in their prompts' option lists)
  # and T010 (language is asked at most once) for feature 012-fix-ux-unify-bible.

  let(:tmp_dir) { Dir.mktmpdir('world_new_spec') }
  let(:recorded_asks) { [] }

  after { FileUtils.rm_rf(tmp_dir) }

  before do
    # Stub Thor's ask so we don't block on $stdin and so we can inspect the
    # exact prompts / defaults the user would see.
    allow_any_instance_of(described_class).to receive(:ask) do |_, prompt, *rest|
      opts = rest.last.is_a?(Hash) ? rest.last : {}
      recorded_asks << [prompt.to_s, opts]
      (opts[:default] || '').to_s
    end

    # yes? is only used for the "create in current directory?" confirmation,
    # which is skipped when --world-dir is supplied; stub defensively anyway.
    allow_any_instance_of(described_class).to receive(:yes?).and_return(true)
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  # ----- T010 ---------------------------------------------------------------

  describe 'language prompt (T010 / US1)' do
    it 'asks for language at most once when the user keeps the default single language' do
      capture_stdout do
        described_class.start(['new', '--world-dir', tmp_dir])
      end

      language_prompts = recorded_asks.count do |prompt, _|
        prompt.downcase.include?('language')
      end

      expect(language_prompts).to be <= 1
    end
  end

  # ----- T009 ---------------------------------------------------------------

  describe 'interactive defaults appear in the advertised options list (T009 / US1)' do
    it 'does not advertise a default value that is absent from its own option list' do
      # Drive the detailed (non-quick) path to exercise the genre/style prompts.
      capture_stdout do
        described_class.start(['new', '--world-dir', tmp_dir])
      end

      offenders = recorded_asks.filter_map do |prompt, opts|
        next unless opts[:default]

        # Extract a parenthesised option list of >=4 comma-separated items,
        # e.g. "(fantasy, sci-fi, mystery, thriller, ...)". Small
        # parentheticals like "(comma-separated, e.g. en,ru)" are advisory
        # text, not option lists, so we skip anything with <=3 tokens or any
        # "e.g."-style hint.
        list_match = prompt.match(/\(([^()]*(?:,[^()]*){3,})\)/)
        next unless list_match
        next if list_match[1].downcase.include?('e.g.')

        options = list_match[1].split(',').map(&:strip)
        default = opts[:default].to_s.strip
        next if default.empty?
        next if options.include?(default)

        "#{prompt.inspect} advertises #{options.inspect} but default is #{default.inspect}"
      end

      expect(offenders).to be_empty,
                           "These interactive prompts offer defaults outside their own option lists:\n  #{offenders.join("\n  ")}"
    end
  end

  # ----- T023 ---------------------------------------------------------------

  describe 'fresh world layout (T023 / US2 / feature 012)' do
    it 'creates data/story_bible/ and does NOT create data/world.yml or data/story_facts.yml' do
      capture_stdout do
        described_class.start(['new', '--world-dir', tmp_dir])
      end

      expect(Dir.exist?(File.join(tmp_dir, 'data', 'story_bible'))).to be(true)
      expect(File.exist?(File.join(tmp_dir, 'data', 'world.yml'))).to be(false)
      expect(File.exist?(File.join(tmp_dir, 'data', 'story_facts.yml'))).to be(false)
    end
  end
end
