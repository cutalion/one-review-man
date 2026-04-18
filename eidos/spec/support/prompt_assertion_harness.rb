# frozen_string_literal: true

# Runtime prompt-call assertion harness.
#
# Contract: specs/013-spec-coverage-backfill/contracts/prompt-assertion.md
# Background: specs/013-spec-coverage-backfill/research.md (R2)
#
# Wraps MockLLMService so every outgoing prompt is inspected for
# unfilled {PLACEHOLDER} tokens and warnings emitted during construction.

module Eidos
  module Spec
    # Raised when an LLM call carries a prompt that shouldn't have shipped.
    class PromptAssertionFailure < StandardError
      attr_reader :prompt, :unfilled, :unused_warnings, :caller_desc, :category

      def initialize(prompt:, unfilled:, unused_warnings:, caller_desc:)
        @prompt = prompt
        @unfilled = unfilled
        @unused_warnings = unused_warnings
        @caller_desc = caller_desc
        @category = unfilled.any? ? 'unfilled placeholder' : 'unused placeholder warning'
        super(build_message)
      end

      private

      def build_message
        lines = ["Prompt assertion failed during #{caller_desc}:"]
        lines << "  category: #{category}"
        if unfilled.any?
          lines << "  placeholders: #{unfilled.join(', ')}"
        else
          lines << "  warning: #{unused_warnings.join(' | ')}"
        end
        truncated = prompt.to_s.length > 500 ? "#{prompt[0, 500]}..." : prompt.to_s
        lines << "  prompt (first 500 chars): #{truncated.inspect}"
        lines.join("\n")
      end
    end

    module PromptAssertionHarness
      SINGLE_BRACE_TOKEN = /\{([A-Z_][A-Z0-9_]*)\}/.freeze
      DOUBLE_BRACE_TOKEN = /\{\{([A-Z_][A-Z0-9_]*)\}\}/.freeze

      # Inspect an outgoing prompt + any warnings emitted during its construction.
      # Raises PromptAssertionFailure if either signal fires.
      #
      # @param prompt [String] full prompt string leaving the SUT
      # @param warnings [Array<String>] captured $stderr lines from prompt building
      # @param caller_desc [String] human-readable call-site description
      def self.assert!(prompt:, warnings:, caller_desc:)
        return if disabled?

        unfilled = extract_unfilled(prompt.to_s)
        unused   = extract_unused_warnings(warnings)

        return unless unfilled.any? || unused.any?

        raise PromptAssertionFailure.new(
          prompt: prompt,
          unfilled: unfilled,
          unused_warnings: unused,
          caller_desc: caller_desc
        )
      end

      # Two-pass extraction: strip {{DOUBLE}} matches first so a legitimate
      # {{FOO}} leftover isn't also reported as a {FOO} single-brace hit.
      # Any remaining {{...}} after PromptUtils.build_prompt has a chance to
      # run shouldn't happen — PromptUtils raises UnfilledPlaceholdersError
      # earlier — but we guard against bypass paths (mock stubs, hand-built
      # strings handed straight to the LLM service).
      def self.extract_unfilled(prompt)
        double = prompt.scan(DOUBLE_BRACE_TOKEN).flatten
        remainder = prompt.gsub(DOUBLE_BRACE_TOKEN, '')
        single = remainder.scan(SINGLE_BRACE_TOKEN).flatten
        (double + single).uniq
      end

      def self.extract_unused_warnings(warnings)
        warnings.select { |w| w.to_s.include?('Unused placeholders') }
      end

      # Temporarily suppress the harness. Used by the harness's own self-test
      # spec to verify the detection logic without the wrapper short-circuiting
      # the raise. Not for use by feature specs — the design intentionally
      # has no opt-out list (see contract).
      def self.disabled(&block)
        Thread.current[:prompt_assertion_disabled] = true
        yield
      ensure
        Thread.current[:prompt_assertion_disabled] = false
      end

      def self.disabled?
        Thread.current[:prompt_assertion_disabled] == true
      end
    end
  end
end
