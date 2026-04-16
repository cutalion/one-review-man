# frozen_string_literal: true

module Eidos
  # Outcome of a single Probe#run invocation.
  #
  # Status is :ok or :fail. On :fail, failure_category is one of:
  #   :unknown_model | :auth | :network | :rate_limit | :other
  ProbeResult = Struct.new(
    :status,
    :provider,
    :model,
    :latency_ms,
    :response_excerpt,
    :input_tokens,
    :output_tokens,
    :failure_category,
    :error_message,
    keyword_init: true
  ) do
    def ok?
      status == :ok
    end

    def fail?
      status == :fail
    end

    def to_h
      super.compact
    end
  end
end
