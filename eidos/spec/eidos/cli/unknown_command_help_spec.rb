# frozen_string_literal: true

require 'spec_helper'
require 'eidos/cli/main'
require 'stringio'

RSpec.describe 'CLI unknown-command → help' do
  def capture(argv)
    out = StringIO.new
    err = StringIO.new
    code = nil
    orig_stdout = $stdout
    orig_stderr = $stderr
    $stdout = out
    $stderr = err
    begin
      Eidos::CLI::Main.start(argv)
      code = 0
    rescue SystemExit => e
      code = e.status
    ensure
      $stdout = orig_stdout
      $stderr = orig_stderr
    end
    [out.string, err.string, code]
  end

  it 'prints "Unknown command" and help output for top-level unknown command' do
    out, _err, code = capture(['status'])

    expect(out).to include('Unknown command: "status"')
    expect(out).to include('Commands:')
    # Subcommands listed (the banner's basename is $PROGRAM_NAME, not "eidos",
    # when run under rspec — so match on the Thor command name only).
    expect(out).to match(/\bworld SUBCOMMAND/)
    expect(out).to match(/\bbible SUBCOMMAND/)
    expect(code).to eq(1)
  end

  it 'prints "Unknown command" and help output for unknown subcommand of world' do
    out, _err, code = capture(%w[world foo])

    expect(out).to include('Unknown command: "foo"')
    expect(out).to match(/\bworld new\b/)
    expect(out).to match(/\bworld status\b/)
    expect(code).to eq(1)
  end

  it 'still runs a valid top-level command without the help banner' do
    out, _err, code = capture(['version'])

    expect(out).to match(/eidos \d/)
    expect(out).not_to include('Unknown command')
    expect(code).to eq(0)
  end
end
