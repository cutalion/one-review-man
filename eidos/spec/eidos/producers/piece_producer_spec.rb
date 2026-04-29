# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'eidos/producers/piece_producer'
require 'eidos/form_registry'
require 'eidos/world_config'

# T012 / US1 / feature 014-storyworld-pivot.
#
# PieceProducer#produce for the `vignette` form must write a file under
# content/pieces/vignette/<id>.md with piece frontmatter and measured
# length within tolerance of the requested 400 words. Stubs the LLM with
# a canned vignette response so the spec is deterministic and fast.
RSpec.describe Eidos::Producers::PieceProducer do
  let(:tmp_dir) { Dir.mktmpdir('piece_producer_spec') }

  let(:vignette_body) { 'word ' * 400 }
  let(:llm_response) do
    <<~TEXT.strip
      #{vignette_body.strip}

      ---CANON-DELTA---
      new_characters: []
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

  let(:registry) { Eidos::FormRegistry.new }
  let(:producer) do
    described_class.new(
      world_path: tmp_dir,
      llm_service: llm_service,
      form_registry: registry
    )
  end

  before { scaffold_world_state(tmp_dir) }
  after { FileUtils.rm_rf(tmp_dir) }

  describe '#produce with form=vignette' do
    it 'writes a file under content/pieces/vignette/<id>.md' do
      piece = producer.produce(form: 'vignette', prompt: 'A quiet job-search morning.', length: 400)

      expect(piece).to be_a(Eidos::Piece)
      expect(piece.form).to eq('vignette')
      expect(piece.category).to eq(:text)

      file = Dir.glob(File.join(tmp_dir, 'content', 'pieces', 'vignette', '*.md')).first
      expect(file).not_to be_nil
      expect(File.basename(File.dirname(file))).to eq('vignette')
    end

    it 'emits piece frontmatter with form/category/canon_version/canon_status' do
      producer.produce(form: 'vignette', prompt: 'x', length: 400)

      file = Dir.glob(File.join(tmp_dir, 'content', 'pieces', 'vignette', '*.md')).first
      raw = File.read(file)
      fm = YAML.safe_load(raw.split(/^---\s*$/, 3)[1], permitted_classes: [Date, Symbol])

      expect(fm['form']).to eq('vignette')
      expect(fm['category']).to eq('text')
      expect(fm['canon_status']).to eq('applied')
      # Post-018a: canon_version is an Integer (the global revision counter)
      # or a String (a snapshot label, when --snapshot is pinned).
      expect(fm['canon_version']).to be_a(Integer).or be_a(String)
      expect(fm['canon_version']).not_to be_nil
    end

    it 'strips the ---CANON-DELTA--- tail from the written body' do
      producer.produce(form: 'vignette', prompt: 'x', length: 400)

      file = Dir.glob(File.join(tmp_dir, 'content', 'pieces', 'vignette', '*.md')).first
      body = File.read(file).split(/^---\s*$/, 3)[2].to_s
      expect(body).not_to include('CANON-DELTA')
    end

    it 'measures length (word count) for text forms' do
      piece = producer.produce(form: 'vignette', prompt: 'x', length: 400)
      expect(piece.length_measured).to be_within(10).of(400)
    end

    it 'stores length as an integer word count, not a range string' do
      piece = producer.produce(form: 'vignette', prompt: 'x', length: 400)
      expect(piece.length_measured).to be_an(Integer)
    end
  end

  describe 'dry_run mode' do
    it 'returns a Piece without writing a file' do
      piece = nil
      output = capture_stdout do
        piece = producer.produce(form: 'vignette', prompt: 'x', length: 400, dry_run: true)
      end

      expect(piece).to be_a(Eidos::Piece)
      expect(Dir.glob(File.join(tmp_dir, 'content', 'pieces', '**', '*.md'))).to be_empty
      expect(output).to include('word')
    end
  end

  # T029 — canon_context injection (US2).
  #
  # When a form declares canon_context slices, PieceProducer must fill
  # {CANON_CONTEXT} with the appropriate blocks assembled from the bible.
  # When canon_context is [:none] or no bible is wired, {CANON_CONTEXT}
  # resolves to empty string without raising.
  describe 'canon_context injection (US2)' do
    let(:captured_prompts) { [] }
    let(:llm_service) do
      double('LLMService').tap do |s|
        allow(s).to receive(:generate_text) do |prompt:, **|
          captured_prompts << prompt
          llm_response
        end
      end
    end

    let(:bible) do
      double('Bible').tap do |b|
        allow(b).to receive(:characters).and_return([
                                                      { 'name' => 'Arthur Chen', 'description' => 'the applicant' },
                                                      { 'name' => 'Kenji Yamamoto', 'description' => 'the mentor' }
                                                    ])
        allow(b).to receive(:locations).and_return([
                                                     { 'name' => 'The Cubicle' },
                                                     { 'name' => 'The Coffee Shop' }
                                                   ])
      end
    end

    it 'injects all_characters slice into {CANON_CONTEXT}' do
      producer = described_class.new(
        world_path: tmp_dir,
        llm_service: llm_service,
        form_registry: registry,
        bible: bible
      )
      producer.produce(form: 'vignette', prompt: 'x', length: 100)

      prompt = captured_prompts.first
      expect(prompt).to include('Arthur Chen')
      expect(prompt).to include('Kenji Yamamoto')
      # Tokens must have been filled — none should survive.
      expect(prompt).not_to include('{CANON_CONTEXT}')
    end

    it 'resolves {CANON_CONTEXT} to empty without crashing when no bible is wired' do
      producer = described_class.new(
        world_path: tmp_dir,
        llm_service: llm_service,
        form_registry: registry
      )
      producer.produce(form: 'vignette', prompt: 'x', length: 100)

      prompt = captured_prompts.first
      expect(prompt).not_to include('{CANON_CONTEXT}')
    end

    it 'includes all_locations block when the form requests it' do
      # Build a bespoke form in a tmp registry that requests locations.
      forms_root = File.join(tmp_dir, 'data', 'forms')
      FileUtils.mkdir_p(forms_root)
      File.write(File.join(forms_root, 'scene.yml'), <<~YAML)
        name: scene
        category: text
        default_length: 100
        prompt_template_path: ./scene.prompt.txt
        canon_context:
          - all_locations
      YAML
      File.write(File.join(forms_root, 'scene.prompt.txt'),
                 "Write a scene.\n{CANON_CONTEXT}\n{USER_PROMPT}\n{LENGTH_TARGET}\n---CANON-DELTA---\n")

      custom_registry = Eidos::FormRegistry.new(world_path: tmp_dir)
      producer = described_class.new(
        world_path: tmp_dir,
        llm_service: llm_service,
        form_registry: custom_registry,
        bible: bible
      )

      producer.produce(form: 'scene', prompt: 'x')
      prompt = captured_prompts.first
      expect(prompt).to include('The Cubicle')
      expect(prompt).to include('The Coffee Shop')
    end
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
