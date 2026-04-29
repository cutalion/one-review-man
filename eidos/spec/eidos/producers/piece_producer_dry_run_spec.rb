# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'eidos/producers/piece_producer'
require 'eidos/form_registry'
require 'eidos/audit_log'
require 'eidos/story_bible'

# T048 — US3 / feature 014-storyworld-pivot.
#
# PieceProducer --dry-run writes zero files (no piece, no delta, no
# audit entry) and prints the delta tail to stdout (FR-018 mode b).
RSpec.describe Eidos::Producers::PieceProducer, 'dry-run (US3)' do
  let(:tmp_dir) { Dir.mktmpdir('piece_producer_dry_run') }
  let(:registry) { Eidos::FormRegistry.new }
  let(:bible) { Eidos::StoryBible.new(project_root: tmp_dir) }
  let(:audit_log) { Eidos::AuditLog.new(world_path: tmp_dir) }

  let(:llm_response) do
    <<~TEXT
      A 3-line haiku about a silent code review.

      ---CANON-DELTA---
      new_characters:
        - id: ghost-reviewer
          name: Ghost Reviewer
      new_locations: []
      new_facts: []
      new_events: []
      new_relationships: []
      entity_updates: []
    TEXT
  end

  let(:llm_service) do
    double('LLMService').tap do |s|
      allow(s).to receive(:generate_text) { |prompt:, **| llm_response }
    end
  end

  let(:producer) do
    described_class.new(
      world_path: tmp_dir,
      llm_service: llm_service,
      form_registry: registry,
      bible: bible,
      audit_log: audit_log
    )
  end

  before do
    bible.setup
    scaffold_world_state(tmp_dir)
  end
  after  { FileUtils.rm_rf(tmp_dir) }

  it 'writes zero piece files, zero delta files, zero audit entries' do
    output = capture_stdout do
      producer.produce(form: 'haiku', prompt: 'silent code review', dry_run: true)
    end

    expect(Dir.glob(File.join(tmp_dir, 'content', 'pieces', '**', '*.md'))).to be_empty
    expect(Dir.glob(File.join(tmp_dir, 'data', 'canon_deltas', '*.yml'))).to be_empty
    expect(audit_log.all).to be_empty
    # Canon is untouched.
    expect(bible.characters).to be_empty
    # Dry-run prints both the body and the delta tail so the user can eyeball them.
    expect(output).to include('haiku about a silent code review')
    expect(output).to include('---CANON-DELTA---')
    expect(output).to include('ghost-reviewer')
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
