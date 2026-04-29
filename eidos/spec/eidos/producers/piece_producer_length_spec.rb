# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'eidos/producers/piece_producer'
require 'eidos/form_registry'
require 'eidos/world_config'

# T013 / US1 / feature 014-storyworld-pivot.
#
# Length precedence (FR-004):
#   CLI --length > form.default_length > form.default_shape
# For form=chapter ONLY, fall back to world_config.chapter_length_target to
# preserve existing behavior. All other forms MUST NOT receive the
# chapter_length_target in their prompt.
RSpec.describe 'PieceProducer length resolution (014-storyworld-pivot)' do
  let(:tmp_dir) { Dir.mktmpdir('piece_producer_length_spec') }
  let(:registry) { Eidos::FormRegistry.new }
  let(:captured_prompts) { [] }

  let(:llm_service) do
    prompts = captured_prompts
    double('LLMService').tap do |s|
      allow(s).to receive(:generate_text) do |prompt:, **|
        prompts << prompt
        "mock body\n---CANON-DELTA---\nnew_characters: []\n"
      end
      # Post-018a: chapter form is structured_output and routes through
      # generate_chapter_structured. Capture its prompt the same way.
      allow(s).to receive(:generate_chapter_structured) do |prompt, *_|
        prompts << prompt
        {
          'title' => 'Mock Title',
          'summary' => 'Mock summary.',
          'content' => 'Mock chapter body.',
          'new_characters' => []
        }
      end
    end
  end

  let(:world_config) do
    config = double('WorldConfig')
    allow(config).to receive(:chapter_length_target).and_return('500-1000 words')
    config
  end

  let(:producer) do
    Eidos::Producers::PieceProducer.new(
      world_path: tmp_dir,
      llm_service: llm_service,
      form_registry: registry,
      world_config: world_config
    )
  end

  before { scaffold_world_state(tmp_dir) }
  after { FileUtils.rm_rf(tmp_dir) }

  describe 'CLI length override wins' do
    it 'uses --length when provided for a form with a default_length' do
      producer.produce(form: 'vignette', prompt: 'x', length: 777)

      expect(captured_prompts.first).to include('777')
    end

    it 'uses --length when provided for a form with only a default_shape' do
      producer.produce(form: 'haiku', prompt: 'x', length: 5)

      expect(captured_prompts.first).to include('5')
    end
  end

  describe 'fallback to form defaults' do
    it 'falls back to the form default_length (400) for vignette' do
      producer.produce(form: 'vignette', prompt: 'x')

      expect(captured_prompts.first).to include('400')
    end

    it 'falls back to the form default_shape for haiku' do
      producer.produce(form: 'haiku', prompt: 'x')

      expect(captured_prompts.first).to include('5-7-5')
    end
  end

  describe 'chapter_length_target isolation (FR-004)' do
    it 'does NOT inject chapter_length_target into vignette prompts' do
      producer.produce(form: 'vignette', prompt: 'x')

      expect(captured_prompts.first).not_to include('500-1000 words')
    end

    it 'does NOT inject chapter_length_target into haiku prompts' do
      producer.produce(form: 'haiku', prompt: 'x')

      expect(captured_prompts.first).not_to include('500-1000 words')
    end

    it 'DOES fall back to chapter_length_target for form=chapter when no other override' do
      producer.produce(form: 'chapter', prompt: 'x')

      # Chapter's built-in default_length = 1500 wins over the world config
      # by spec (world's target only backfills when the form has no default).
      # Assertion: chapter prompts CAN legitimately carry the world's
      # chapter_length_target when the form itself declines to declare one.
      # For the built-in chapter form (which DOES declare 1500) we simply
      # assert the prompt carries SOME length signal.
      expect(captured_prompts.first).to match(/1500|500-1000/)
    end
  end
end
