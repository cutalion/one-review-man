# frozen_string_literal: true

require 'spec_helper'
require 'eidos/cli/main'
require 'eidos/cli/probe_cli'
require 'stringio'
require 'tmpdir'
require 'fileutils'
require 'json'

RSpec.describe Eidos::CLI::ProbeCli do
  # Exercise the CLI through Main so we also cover the Thor registration.
  def capture_run(args)
    out = StringIO.new
    err = StringIO.new
    code = nil
    orig_stdout = $stdout
    orig_stderr = $stderr
    $stdout = out
    $stderr = err
    begin
      Eidos::CLI::Main.start(['probe', *args])
      code = 0
    rescue SystemExit => e
      code = e.status
    ensure
      $stdout = orig_stdout
      $stderr = orig_stderr
    end
    [out.string, err.string, code]
  end

  def stub_probe(result)
    instance = instance_double(Eidos::Probe, run: result)
    allow(Eidos::Probe).to receive(:new).and_return(instance)
    instance
  end

  let(:ok_result) do
    Eidos::ProbeResult.new(
      status: :ok,
      provider: 'openai',
      model: 'gpt-4o-mini',
      latency_ms: 842,
      response_text: 'PROBE OK',
      input_tokens: 23,
      output_tokens: 4
    )
  end

  let(:fail_result) do
    Eidos::ProbeResult.new(
      status: :fail,
      provider: 'openai',
      model: 'gpt-foo',
      latency_ms: 120,
      failure_category: :unknown_model,
      error_message: 'The model `gpt-foo` does not exist'
    )
  end

  describe 'happy path' do
    before { stub_probe(ok_result) }

    it 'prints human-readable OK line and exits 0' do
      out, _err, code = capture_run(['gpt-4o-mini', '--api-key=sk-test'])
      expect(code).to eq(0)
      expect(out).to include('OK openai gpt-4o-mini (842ms)')
      expect(out).to include('"PROBE OK"')
    end

    it 'includes tokens with --metrics' do
      out, _err, code = capture_run(['gpt-4o-mini', '--api-key=sk-test', '--metrics'])
      expect(code).to eq(0)
      expect(out).to include('23 in / 4 out tokens')
    end

    it 'emits JSON with --json' do
      out, _err, code = capture_run(['gpt-4o-mini', '--api-key=sk-test', '--json'])
      expect(code).to eq(0)
      parsed = JSON.parse(out.strip)
      expect(parsed).to include(
        'status' => 'ok',
        'provider' => 'openai',
        'model' => 'gpt-4o-mini',
        'latency_ms' => 842,
        'response_text' => 'PROBE OK'
      )
    end
  end

  describe 'custom prompt' do
    let(:haiku_result) do
      Eidos::ProbeResult.new(
        status: :ok,
        provider: 'openai',
        model: 'gpt-4o-mini',
        latency_ms: 500,
        response_text: "silent cursor blinks\nreviewer reads every line\nwhispered `LGTM`",
        input_tokens: 12,
        output_tokens: 30
      )
    end

    it 'passes --prompt through to Probe and omits the default system prompt' do
      captured = nil
      allow(Eidos::Probe).to receive(:new) do |**opts|
        captured = opts
        instance_double(Eidos::Probe, run: haiku_result)
      end

      _out, _err, code = capture_run([
        'gpt-4o-mini', '--api-key=sk-test',
        '--prompt', 'Write a haiku about code review.'
      ])
      expect(code).to eq(0)
      expect(captured[:prompt]).to eq('Write a haiku about code review.')
      expect(captured[:system_prompt]).to be_nil
    end

    it 'bumps default max_tokens to 500 when --prompt is given' do
      captured = nil
      allow(Eidos::Probe).to receive(:new) do |**opts|
        captured = opts
        instance_double(Eidos::Probe, run: haiku_result)
      end

      capture_run(['gpt-4o-mini', '--api-key=sk-test', '--prompt', 'hi'])
      expect(captured[:max_tokens]).to eq(500)
    end

    it 'honors an explicit --max-tokens override' do
      captured = nil
      allow(Eidos::Probe).to receive(:new) do |**opts|
        captured = opts
        instance_double(Eidos::Probe, run: haiku_result)
      end

      capture_run(['gpt-4o-mini', '--api-key=sk-test', '--prompt', 'hi', '--max-tokens=42'])
      expect(captured[:max_tokens]).to eq(42)
    end

    it 'prints multi-line verbose output for --prompt' do
      stub_probe(haiku_result)
      out, _err, code = capture_run([
        'gpt-4o-mini', '--api-key=sk-test',
        '--prompt', 'Write a haiku about code review.'
      ])
      expect(code).to eq(0)
      expect(out).to include('--- response ---')
      expect(out).to include('silent cursor blinks')
      expect(out).to include("whispered `LGTM`")
    end

    it 'emits JSON with the full response_text when --json is combined with --prompt' do
      stub_probe(haiku_result)
      out, _err, code = capture_run([
        'gpt-4o-mini', '--api-key=sk-test', '--json',
        '--prompt', 'Write a haiku about code review.'
      ])
      expect(code).to eq(0)
      parsed = JSON.parse(out.strip)
      expect(parsed['response_text']).to include('silent cursor blinks')
    end
  end

  describe 'failure path' do
    before { stub_probe(fail_result) }

    it 'prints FAIL line and exits 1' do
      out, _err, code = capture_run(['gpt-foo', '--api-key=sk-test'])
      expect(code).to eq(1)
      expect(out).to include('FAIL openai gpt-foo [unknown_model]')
      expect(out).to include('The model `gpt-foo` does not exist')
    end
  end

  describe 'credential resolution' do
    it 'exits 2 with a clear message when no api key anywhere' do
      orig_openai = ENV.delete('OPENAI_API_KEY')
      orig_openrouter = ENV.delete('OPENROUTER_API_KEY')
      begin
        _out, err, code = capture_run(['some-model'])
        expect(code).to eq(2)
        expect(err).to include("No API key for provider 'openai'")
        expect(err).to include('OPENAI_API_KEY')
      ensure
        ENV['OPENAI_API_KEY']     = orig_openai if orig_openai
        ENV['OPENROUTER_API_KEY'] = orig_openrouter if orig_openrouter
      end
    end

    it 'exits 2 on unsupported provider' do
      _out, err, code = capture_run(['m', '--provider=anthropic', '--api-key=x'])
      expect(code).to eq(2)
      expect(err).to include("Unsupported provider 'anthropic'")
    end
  end

  describe 'help-flag handling' do
    %w[--help -h help].each do |arg|
      it "shows help (not an error) for #{arg.inspect} as model arg" do
        out, err, code = capture_run([arg])
        expect(code).to eq(0)
        expect(out).to include('probe')
        expect(err).to be_empty
      end
    end

    it 'rejects other flag-looking models with a pointer to help' do
      _out, err, code = capture_run(['--something-weird', '--api-key=x'])
      expect(code).to eq(2)
      expect(err).to include('looks like a flag')
      expect(err).to include('eidos help probe')
    end

    it 'reads api_key_env from world settings when -w is given' do
      Dir.mktmpdir do |world|
        data = File.join(world, 'data')
        FileUtils.mkdir_p(data)
        File.write(File.join(data, 'settings.yml'), <<~YAML)
          providers:
            openai:
              api_key_env: CUSTOM_KEY_VAR
        YAML

        captured_api_key = nil
        allow(Eidos::Probe).to receive(:new) do |**opts|
          captured_api_key = opts[:api_key]
          instance_double(Eidos::Probe, run: ok_result)
        end

        ENV['CUSTOM_KEY_VAR'] = 'from-custom-env'
        begin
          _out, _err, code = capture_run(['gpt-4o-mini', '-w', world])
          expect(code).to eq(0)
          expect(captured_api_key).to eq('from-custom-env')
        ensure
          ENV.delete('CUSTOM_KEY_VAR')
        end
      end
    end

    it 'flag beats world settings beats default ENV' do
      Dir.mktmpdir do |world|
        data = File.join(world, 'data')
        FileUtils.mkdir_p(data)
        File.write(File.join(data, 'settings.yml'), <<~YAML)
          providers:
            openai:
              api_key_env: WORLD_KEY
        YAML
        orig_env_openai = ENV['OPENAI_API_KEY']
        ENV['WORLD_KEY']       = 'world-value'
        ENV['OPENAI_API_KEY']  = 'env-value'

        captured = nil
        allow(Eidos::Probe).to receive(:new) do |**opts|
          captured = opts[:api_key]
          instance_double(Eidos::Probe, run: ok_result)
        end

        begin
          capture_run(['m', '-w', world, '--api-key=flag-value'])
          expect(captured).to eq('flag-value')

          capture_run(['m', '-w', world])
          expect(captured).to eq('world-value')

          ENV.delete('WORLD_KEY')
          capture_run(['m'])
          expect(captured).to eq('env-value')
        ensure
          ENV.delete('WORLD_KEY')
          if orig_env_openai
            ENV['OPENAI_API_KEY'] = orig_env_openai
          else
            ENV.delete('OPENAI_API_KEY')
          end
        end
      end
    end
  end
end
