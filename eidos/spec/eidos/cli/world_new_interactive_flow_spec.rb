# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'fileutils'
require 'eidos/cli/world'

# T009 (feature 015 US3): the existing interactive `world new` flow must
# keep working when $stdin is a TTY AND no quick-setup flags are passed.
# The contract (cli-flags.md §Behavior) says: "Interactive TTY + no flags
# (existing behavior preserved): If $stdin.tty? == true AND zero quick-setup
# flags provided → fall through to the existing tty-prompt interactive
# flow. No change."
#
# We can't easily fake a real TTY in RSpec, so we stub `$stdin.tty?` to
# return true and stub `ask` to return defaults. The assertion is that
# the interactive asker runs AT LEAST the expected number of times — if
# the non-interactive branch were taken by mistake, `ask` would never fire.
RSpec.describe Eidos::CLI::World, 'interactive flow fallthrough (US3 T009)' do
  let(:tmp_dir) { Dir.mktmpdir('world_new_interactive_flow') }
  let(:recorded_asks) { [] }

  after { FileUtils.rm_rf(tmp_dir) }

  before do
    # Pretend stdin is a TTY so `non_interactive_quick?` returns false for
    # the --quick + no-flags case.
    allow($stdin).to receive(:tty?).and_return(true)

    # Trap every `ask` so we can count calls and return the advertised
    # default for each prompt.
    allow_any_instance_of(described_class).to receive(:ask) do |_, prompt, *rest|
      opts = rest.last.is_a?(Hash) ? rest.last : {}
      recorded_asks << [prompt.to_s, opts]
      (opts[:default] || '').to_s
    end

    # yes? is used by the directory-create confirmation and the seed
    # prompt; default to true so the flow completes without blocking.
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

  it 'asks interactive prompts when TTY + zero quick-setup flags + no --quick' do
    capture_stdout do
      described_class.start(['new', '-w', tmp_dir, '--no-seed'])
    end

    # The detailed flow asks at minimum: title, author, description, languages,
    # genre, style, setting, primary theme, secondary themes.
    expect(recorded_asks.size).to be >= 8

    prompt_text = recorded_asks.map(&:first).join("\n").downcase
    expect(prompt_text).to include('world title')
    expect(prompt_text).to include('author')
    expect(prompt_text).to include('description')
  end

  it 'asks interactive prompts under --quick when TTY and zero quick-setup flags' do
    capture_stdout do
      described_class.start(['new', '-w', tmp_dir, '--quick'])
    end

    # --quick still asks the four core questions (title, author, description,
    # languages) interactively when no flags are passed and stdin is a TTY.
    expect(recorded_asks.size).to be >= 4

    prompt_text = recorded_asks.map(&:first).join("\n").downcase
    expect(prompt_text).to include('world title')
    expect(prompt_text).to include('author')
    expect(prompt_text).to include('description')
  end

  it 'bypasses interactive prompts when --quick AND any quick-setup flag is provided' do
    capture_stdout do
      described_class.start(
        [
          'new', '-w', tmp_dir, '--quick', '--no-seed',
          '--title', 'Flagged World',
          '--author', 'QA',
          '--premise', 'Short premise.'
        ]
      )
    end

    # Non-interactive path: no `ask` calls at all.
    expect(recorded_asks).to be_empty
  end

  it 'bypasses interactive prompts when --quick AND stdin is not a TTY' do
    allow($stdin).to receive(:tty?).and_return(false)

    # With --quick and non-TTY, non_interactive_quick? is true; missing
    # required flags should trigger the exit path — proving we took the
    # non-interactive branch (no `ask` fired).
    expect do
      capture_stdout do
        # Redirect stderr so the SystemExit message doesn't noise the test
        # output.
        original = $stderr
        $stderr = StringIO.new
        begin
          described_class.start(['new', '-w', tmp_dir, '--quick', '--no-seed'])
        ensure
          $stderr = original
        end
      end
    end.to raise_error(SystemExit)

    expect(recorded_asks).to be_empty
  end
end
