# frozen_string_literal: true

require 'spec_helper'
require 'eidos/probe'
require 'faraday'

RSpec.describe Eidos::Probe do
  let(:fake_client) { instance_double(OpenAI::Client) }
  let(:api_key) { 'sk-FAKE-KEY-FOR-TESTS' }

  def build_probe(overrides = {})
    described_class.new(
      provider: 'openai',
      model: 'gpt-4o-mini',
      api_key: api_key,
      client: fake_client,
      **overrides
    )
  end

  def faraday_error(status:, body:)
    Faraday::ClientError.new('boom', status: status, body: body.to_json)
  end

  # ruby-openai parses JSON bodies into a Hash before raising.
  def faraday_error_hash(status:, body:)
    Faraday::ClientError.new('boom', status: status, body: body)
  end

  describe 'initialization' do
    it 'raises on missing api_key' do
      expect {
        described_class.new(provider: 'openai', model: 'm', api_key: nil)
      }.to raise_error(Eidos::Probe::MissingCredentialError)
    end

    it 'raises on empty api_key' do
      expect {
        described_class.new(provider: 'openai', model: 'm', api_key: '')
      }.to raise_error(Eidos::Probe::MissingCredentialError)
    end

    it 'raises on unsupported provider' do
      expect {
        described_class.new(provider: 'anthropic', model: 'm', api_key: 'k')
      }.to raise_error(Eidos::Probe::UnsupportedProviderError)
    end
  end

  describe '#run happy path' do
    let(:response) do
      {
        'choices' => [{ 'message' => { 'content' => 'PROBE OK' } }],
        'usage' => { 'prompt_tokens' => 23, 'completion_tokens' => 4 }
      }
    end

    before { allow(fake_client).to receive(:chat).and_return(response) }

    it 'returns an OK result with provider, model, latency, excerpt, tokens' do
      result = build_probe.run

      expect(result).to be_ok
      expect(result.provider).to eq('openai')
      expect(result.model).to eq('gpt-4o-mini')
      expect(result.latency_ms).to be_a(Integer).and be >= 0
      expect(result.response_text).to eq('PROBE OK')
      expect(result.input_tokens).to eq(23)
      expect(result.output_tokens).to eq(4)
      expect(result.failure_category).to be_nil
      expect(result.error_message).to be_nil
    end

    it 'sends the fixed probe prompt with max_tokens cap' do
      expect(fake_client).to receive(:chat) do |parameters:|
        expect(parameters[:model]).to eq('gpt-4o-mini')
        expect(parameters[:max_tokens]).to eq(Eidos::Probe::MAX_TOKENS)
        expect(parameters[:messages].first[:role]).to eq('system')
        expect(parameters[:messages].last[:content]).to include('PROBE OK')
        response
      end

      build_probe.run
    end

    it 'honors a custom prompt and max_tokens' do
      expect(fake_client).to receive(:chat) do |parameters:|
        expect(parameters[:max_tokens]).to eq(400)
        expect(parameters[:messages].map { |m| m[:role] }).to eq(%w[user])
        expect(parameters[:messages].first[:content]).to eq('Write a haiku about code review.')
        response
      end

      build_probe(prompt: 'Write a haiku about code review.', system_prompt: nil, max_tokens: 400).run
    end

    it 'keeps the system prompt by default even with a custom user prompt' do
      expect(fake_client).to receive(:chat) do |parameters:|
        expect(parameters[:messages].first[:role]).to eq('system')
        response
      end

      build_probe(prompt: 'hi').run
    end

    it 'returns the full response text without truncation' do
      allow(fake_client).to receive(:chat).and_return(
        'choices' => [{ 'message' => { 'content' => 'x' * 500 } }]
      )
      result = build_probe.run
      expect(result.response_text.length).to eq(500)
    end

    it 'leaves token counts nil when provider omits usage' do
      allow(fake_client).to receive(:chat).and_return(
        'choices' => [{ 'message' => { 'content' => 'OK' } }]
      )
      result = build_probe.run
      expect(result.input_tokens).to be_nil
      expect(result.output_tokens).to be_nil
    end
  end

  describe '#run failure classification' do
    it 'classifies HTTP 404 as :unknown_model' do
      allow(fake_client).to receive(:chat)
        .and_raise(faraday_error(status: 404, body: { 'error' => { 'message' => 'no such model' } }))

      result = build_probe.run
      expect(result).to be_fail
      expect(result.failure_category).to eq(:unknown_model)
      expect(result.error_message).to eq('no such model')
    end

    it 'classifies a 400 with "model not found" body as :unknown_model' do
      allow(fake_client).to receive(:chat)
        .and_raise(faraday_error(status: 400, body: { 'error' => { 'message' => "The model `gpt-foo` does not exist" } }))

      result = build_probe.run
      expect(result.failure_category).to eq(:unknown_model)
    end

    it 'classifies HTTP 401 as :auth' do
      allow(fake_client).to receive(:chat)
        .and_raise(faraday_error(status: 401, body: { 'error' => { 'message' => 'bad key' } }))

      expect(build_probe.run.failure_category).to eq(:auth)
    end

    it 'classifies HTTP 403 as :auth' do
      allow(fake_client).to receive(:chat)
        .and_raise(faraday_error(status: 403, body: { 'error' => { 'message' => 'forbidden' } }))

      expect(build_probe.run.failure_category).to eq(:auth)
    end

    it 'classifies HTTP 429 as :rate_limit' do
      allow(fake_client).to receive(:chat)
        .and_raise(faraday_error(status: 429, body: { 'error' => { 'message' => 'slow down' } }))

      expect(build_probe.run.failure_category).to eq(:rate_limit)
    end

    it 'classifies HTTP 500 as :other' do
      allow(fake_client).to receive(:chat)
        .and_raise(faraday_error(status: 500, body: { 'error' => { 'message' => 'internal' } }))

      result = build_probe.run
      expect(result.failure_category).to eq(:other)
      expect(result.error_message).to eq('internal')
    end

    it 'classifies Faraday::TimeoutError as :network' do
      allow(fake_client).to receive(:chat).and_raise(Faraday::TimeoutError.new('timeout'))
      expect(build_probe.run.failure_category).to eq(:network)
    end

    it 'classifies Faraday::ConnectionFailed as :network' do
      allow(fake_client).to receive(:chat).and_raise(Faraday::ConnectionFailed.new('refused'))
      expect(build_probe.run.failure_category).to eq(:network)
    end

    it 'classifies SocketError as :network' do
      allow(fake_client).to receive(:chat).and_raise(SocketError.new('dns fail'))
      expect(build_probe.run.failure_category).to eq(:network)
    end

    it 'does not raise on provider errors — always returns a ProbeResult' do
      allow(fake_client).to receive(:chat).and_raise(StandardError.new('weird'))
      expect { build_probe.run }.not_to raise_error
    end

    it 'extracts the message from a Hash body (ruby-openai style)' do
      allow(fake_client).to receive(:chat).and_raise(
        faraday_error_hash(
          status: 500,
          body: { 'error' => { 'message' => 'internal server wobble' } }
        )
      )
      result = build_probe.run
      expect(result.error_message).to eq('internal server wobble')
    end
  end

  describe 'adaptive max_tokens → max_completion_tokens retry' do
    let(:unsupported_error) do
      faraday_error_hash(
        status: 400,
        body: {
          'error' => {
            'message' => "Unsupported parameter: 'max_tokens' is not supported with this model. Use 'max_completion_tokens' instead.",
            'type' => 'invalid_request_error',
            'param' => 'max_tokens',
            'code' => 'unsupported_parameter'
          }
        }
      )
    end

    it 'retries with max_completion_tokens when provider rejects max_tokens' do
      call_count = 0
      allow(fake_client).to receive(:chat) do |parameters:|
        call_count += 1
        if call_count == 1
          expect(parameters).to have_key(:max_tokens)
          raise unsupported_error
        else
          expect(parameters).to have_key(:max_completion_tokens)
          expect(parameters).not_to have_key(:max_tokens)
          { 'choices' => [{ 'message' => { 'content' => 'PROBE OK' } }] }
        end
      end

      result = build_probe.run
      expect(call_count).to eq(2)
      expect(result).to be_ok
    end

    it 'does not retry for unrelated 400 errors' do
      other_400 = faraday_error_hash(
        status: 400,
        body: { 'error' => { 'message' => 'bad request', 'code' => 'invalid_something' } }
      )
      allow(fake_client).to receive(:chat).and_raise(other_400)

      result = build_probe.run
      expect(result.failure_category).to eq(:other)
      expect(fake_client).to have_received(:chat).once
    end
  end

  describe 'secret hygiene' do
    it 'scrubs api_key from response_text if it ever appears' do
      echoed = "your key #{api_key} is valid"
      allow(fake_client).to receive(:chat).and_return(
        'choices' => [{ 'message' => { 'content' => echoed } }]
      )
      result = build_probe.run
      expect(result.response_text).not_to include(api_key)
      expect(result.response_text).to include('[REDACTED]')
    end

    it 'scrubs api_key from error_message if it ever appears' do
      allow(fake_client).to receive(:chat)
        .and_raise(faraday_error(status: 401, body: { 'error' => { 'message' => "key #{api_key} rejected" } }))

      result = build_probe.run
      expect(result.error_message).not_to include(api_key)
      expect(result.error_message).to include('[REDACTED]')
    end
  end

  describe 'openrouter provider' do
    it 'defaults base_url to the OpenRouter endpoint' do
      captured = nil
      allow(OpenAI::Client).to receive(:new) do |**opts|
        captured = opts
        fake_client
      end
      allow(fake_client).to receive(:chat).and_return(
        'choices' => [{ 'message' => { 'content' => 'OK' } }]
      )

      described_class.new(provider: 'openrouter', model: 'x/y', api_key: 'k').run
      expect(captured[:uri_base]).to eq(Eidos::Probe::OPENROUTER_BASE_URL)
    end
  end
end
