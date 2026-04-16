# frozen_string_literal: true

require 'json'
require_relative 'probe_result'

begin
  require 'openai'
rescue LoadError
  # Defer until usage — the openai gem is a runtime dep, but we keep
  # the require guarded so probe_result.rb loading doesn't fail in isolation.
end

module Eidos
  # Cheap reachability probe for a (provider, model) combination.
  #
  # Uses OpenAI::Client directly (not LLMService) so that mock-AI mode,
  # retry logic, and debug dumping in LLMService do not interfere with a
  # probe run. A probe is meant to be honest.
  class Probe
    class MissingCredentialError < StandardError; end
    class UnsupportedProviderError < StandardError; end

    SUPPORTED_PROVIDERS = %w[openai openrouter].freeze

    # Fixed prompt — small, cheap, provider-agnostic.
    SYSTEM_PROMPT = 'You are a probe. Reply with the exact text requested, nothing else.'
    USER_PROMPT   = 'Reply with exactly the two words: PROBE OK'
    MAX_TOKENS    = 20
    EXCERPT_LEN   = 80

    OPENROUTER_BASE_URL = 'https://openrouter.ai/api/v1'

    def initialize(provider:, model:, api_key:, base_url: nil, timeout: 60, client: nil)
      @provider = provider.to_s
      raise UnsupportedProviderError, "Unsupported provider '#{@provider}'. Supported: #{SUPPORTED_PROVIDERS.join(', ')}" \
        unless SUPPORTED_PROVIDERS.include?(@provider)
      raise MissingCredentialError, "No API key provided for provider '#{@provider}'" if api_key.nil? || api_key.to_s.empty?

      @model    = model.to_s
      @api_key  = api_key
      @base_url = base_url || default_base_url(@provider)
      @timeout  = timeout
      @client   = client # for injection in tests
    end

    def run
      started = monotonic_ms
      response = client.chat(
        parameters: {
          model: @model,
          messages: [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user',   content: USER_PROMPT }
          ],
          max_tokens: MAX_TOKENS
        }
      )
      latency = monotonic_ms - started

      content = response.dig('choices', 0, 'message', 'content').to_s
      usage   = response['usage'] || {}

      ProbeResult.new(
        status: :ok,
        provider: @provider,
        model: @model,
        latency_ms: latency,
        response_excerpt: sanitize(content)[0, EXCERPT_LEN],
        input_tokens: usage['prompt_tokens'],
        output_tokens: usage['completion_tokens']
      )
    rescue StandardError => e
      latency = monotonic_ms - started
      category, message = classify(e)
      ProbeResult.new(
        status: :fail,
        provider: @provider,
        model: @model,
        latency_ms: latency,
        failure_category: category,
        error_message: sanitize(message)
      )
    end

    private

    def client
      @client ||= begin
        raise 'openai gem is not loaded' unless defined?(OpenAI::Client)

        options = {
          access_token: @api_key,
          log_errors: false,
          request_timeout: @timeout
        }
        options[:uri_base] = @base_url if @base_url
        OpenAI::Client.new(**options)
      end
    end

    def default_base_url(provider)
      provider == 'openrouter' ? OPENROUTER_BASE_URL : nil
    end

    def monotonic_ms
      (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000).to_i
    end

    # Map an exception to (category, provider_message).
    # Order matters: more specific checks first.
    def classify(err)
      message = extract_message(err)

      if timeout_error?(err)
        [:network, message.empty? ? 'request timed out' : message]
      elsif connection_error?(err)
        [:network, message.empty? ? err.class.name : message]
      elsif (status = http_status(err))
        classify_http(status, message)
      elsif message =~ /(model).*(not found|does not exist|unknown)/i
        [:unknown_model, message]
      else
        [:other, message.empty? ? err.class.name : message]
      end
    end

    def classify_http(status, message)
      case status
      when 401, 403
        [:auth, message.empty? ? "HTTP #{status}" : message]
      when 404
        [:unknown_model, message.empty? ? "HTTP #{status}" : message]
      when 429
        [:rate_limit, message.empty? ? "HTTP #{status}" : message]
      else
        # Some providers return 400 for unknown models; check message.
        if message =~ /(model).*(not found|does not exist|unknown|invalid)/i
          [:unknown_model, message]
        else
          [:other, message.empty? ? "HTTP #{status}" : message]
        end
      end
    end

    def timeout_error?(err)
      return true if defined?(Faraday::TimeoutError) && err.is_a?(Faraday::TimeoutError)
      return true if err.is_a?(Timeout::Error)

      err.class.name =~ /Timeout/
    end

    def connection_error?(err)
      return true if defined?(Faraday::ConnectionFailed) && err.is_a?(Faraday::ConnectionFailed)
      return true if err.is_a?(SocketError)

      false
    end

    def http_status(err)
      return unless err.respond_to?(:response) && err.response.is_a?(Hash)

      err.response[:status]
    end

    def extract_message(err)
      body = err.response[:body] if err.respond_to?(:response) && err.response.is_a?(Hash)
      # Try to parse a JSON error body and pull the message out.
      if body.is_a?(String) && !body.empty?
        begin
          parsed = JSON.parse(body)
          msg = parsed.dig('error', 'message') || parsed['message']
          return msg.to_s if msg && !msg.to_s.empty?
        rescue JSON::ParserError
          # fall through to raw body
        end
        return body[0, 500]
      end
      err.message.to_s
    end

    # Defensive scrub: never leak the api_key into any output field.
    def sanitize(text)
      return '' if text.nil?

      text.to_s.gsub(@api_key.to_s, '[REDACTED]')
    end
  end
end
