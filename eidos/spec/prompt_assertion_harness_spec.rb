# frozen_string_literal: true

require 'spec_helper'
require 'support/prompt_assertion_harness'

RSpec.describe Eidos::Spec::PromptAssertionHarness do
  describe '.assert!' do
    it 'passes cleanly for a fully-filled prompt with no warnings' do
      expect do
        described_class.assert!(
          prompt: 'Write Chapter 3 of the story.',
          warnings: [],
          caller_desc: 'test: clean prompt'
        )
      end.not_to raise_error
    end

    it 'fails when a single-brace {PLACEHOLDER} token remains in the prompt' do
      expect do
        described_class.assert!(
          prompt: 'Write Chapter {CHAPTER_NUMBER} of the story.',
          warnings: [],
          caller_desc: 'test: single-brace leak'
        )
      end.to raise_error(Eidos::Spec::PromptAssertionFailure) do |err|
        expect(err.category).to eq('unfilled placeholder')
        expect(err.unfilled).to include('CHAPTER_NUMBER')
        expect(err.message).to include('CHAPTER_NUMBER')
        expect(err.message).to include('test: single-brace leak')
      end
    end

    it 'fails when a double-brace {{PLACEHOLDER}} token remains in the prompt' do
      expect do
        described_class.assert!(
          prompt: 'Write a {{STORY_GENRE}} story.',
          warnings: [],
          caller_desc: 'test: double-brace leak'
        )
      end.to raise_error(Eidos::Spec::PromptAssertionFailure) do |err|
        expect(err.category).to eq('unfilled placeholder')
        expect(err.unfilled).to include('STORY_GENRE')
      end
    end

    it 'deduplicates placeholders: a single {{FOO}} surfaces once, not twice' do
      expect do
        described_class.assert!(
          prompt: 'Ref1 {{FOO}} and ref2 {{FOO}}.',
          warnings: [],
          caller_desc: 'test: dedup'
        )
      end.to raise_error(Eidos::Spec::PromptAssertionFailure) do |err|
        expect(err.unfilled).to eq(['FOO'])
      end
    end

    it 'does not double-report a {{FOO}} leak as both single and double brace' do
      expect do
        described_class.assert!(
          prompt: '{{UNFILLED_TOKEN}}',
          warnings: [],
          caller_desc: 'test: no double-count'
        )
      end.to raise_error(Eidos::Spec::PromptAssertionFailure) do |err|
        expect(err.unfilled).to eq(['UNFILLED_TOKEN'])
      end
    end

    it 'fails when an "Unused placeholders" warning was emitted during construction' do
      expect do
        described_class.assert!(
          prompt: 'Write Chapter 3 of the story.',
          warnings: ['⚠️  Warning: Unused placeholders provided: EXTRA_KEY'],
          caller_desc: 'test: unused warning'
        )
      end.to raise_error(Eidos::Spec::PromptAssertionFailure) do |err|
        expect(err.category).to eq('unused placeholder warning')
        expect(err.message).to include('EXTRA_KEY')
      end
    end

    it 'ignores warnings that do not mention "Unused placeholders"' do
      expect do
        described_class.assert!(
          prompt: 'Write Chapter 3 of the story.',
          warnings: ['deprecation notice: something unrelated'],
          caller_desc: 'test: unrelated warning'
        )
      end.not_to raise_error
    end

    it 'is suppressed inside PromptAssertionHarness.disabled { ... }' do
      expect do
        described_class.disabled do
          described_class.assert!(
            prompt: 'Write Chapter {CHAPTER_NUMBER} of the story.',
            warnings: ['⚠️  Warning: Unused placeholders provided: EXTRA'],
            caller_desc: 'test: disabled block'
          )
        end
      end.not_to raise_error
    end

    it 're-enables the harness after the disabled block returns' do
      described_class.disabled { 1 + 1 } # open-and-close

      expect do
        described_class.assert!(
          prompt: 'Write Chapter {CHAPTER_NUMBER} of the story.',
          warnings: [],
          caller_desc: 'test: re-enabled'
        )
      end.to raise_error(Eidos::Spec::PromptAssertionFailure)
    end

    it 'includes a truncated prompt preview in the failure message' do
      long_prompt = ('x' * 600) + ' {LEAK}'
      expect do
        described_class.assert!(
          prompt: long_prompt,
          warnings: [],
          caller_desc: 'test: truncation'
        )
      end.to raise_error(Eidos::Spec::PromptAssertionFailure) do |err|
        expect(err.message).to include('...')
        expect(err.message.length).to be < long_prompt.length + 200
      end
    end
  end
end
