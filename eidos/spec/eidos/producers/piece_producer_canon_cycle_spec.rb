# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'eidos/producers/piece_producer'
require 'eidos/form_registry'
require 'eidos/audit_log'
require 'eidos/story_bible'
require 'eidos/bible'

# T049 — US3 / feature 014-storyworld-pivot.
#
# A subsequent piece sees a prior piece's new canon entry in its
# assembled {CANON_CONTEXT} — without user intervention (SC-009).
RSpec.describe Eidos::Producers::PieceProducer, 'canon cycle (US3)' do
  let(:tmp_dir) { Dir.mktmpdir('piece_producer_cycle') }
  let(:registry) { Eidos::FormRegistry.new }
  let(:bible) { Eidos::Bible.new(world_path: tmp_dir) }
  let(:audit_log) { Eidos::AuditLog.new(world_path: tmp_dir) }

  let(:first_response) do
    <<~TEXT
      Body of the first piece, introducing Kev-Bot.

      ---CANON-DELTA---
      new_characters:
        - id: kev-bot
          name: Kev-Bot
          description: Self-described lifestyle not a bot.
      new_locations: []
      new_facts: []
      new_events: []
      new_relationships: []
      entity_updates: []
    TEXT
  end

  # The captured_prompts array lets us assert on the SECOND invocation's
  # prompt — confirming that the bible now contains Kev-Bot.
  let(:captured_prompts) { [] }

  let(:llm_service) do
    dbl = double('LLMService')
    allow(dbl).to receive(:generate_text) do |prompt:, **|
      captured_prompts << prompt
      if captured_prompts.length == 1
        first_response
      else
        <<~TEXT
          Body of the second piece, quoting Kev-Bot.

          ---CANON-DELTA---
          new_characters: []
          new_locations: []
          new_facts: []
          new_events: []
          new_relationships: []
          entity_updates: []
        TEXT
      end
    end
    dbl
  end

  before { bible.engine_bible.setup }
  after  { FileUtils.rm_rf(tmp_dir) }

  def build_producer
    described_class.new(
      world_path: tmp_dir,
      llm_service: llm_service,
      form_registry: registry,
      bible: bible,
      audit_log: audit_log
    )
  end

  it 'surfaces prior-piece canon entries in the next prompts {CANON_CONTEXT}' do
    build_producer.produce(form: 'vignette', prompt: 'intro piece', length: 100)
    # Now a new producer invocation (fresh registry cache) should see Kev-Bot.
    build_producer.produce(form: 'vignette', prompt: 'follow-up piece', length: 100)

    second_prompt = captured_prompts[1]
    expect(second_prompt).to include('Kev-Bot')
  end
end
