# frozen_string_literal: true

require 'eidos/producers/chapter_producer'
require 'eidos/producer'
require 'eidos/producer_result'
require 'eidos/snapshot_errors'
require 'tmpdir'
require 'fileutils'

RSpec.describe Eidos::Producers::ChapterProducer do
  let(:tmp_dir) { Dir.mktmpdir }

  before do
    # Set up a minimal book project structure
    FileUtils.mkdir_p(File.join(tmp_dir, 'data'))
    FileUtils.mkdir_p(File.join(tmp_dir, 'content', 'chapters'))
    FileUtils.mkdir_p(File.join(tmp_dir, 'content', 'characters'))

    # Create minimal world_metadata.yml
    File.write(File.join(tmp_dir, 'data', 'world_metadata.yml'), {
      'title' => 'Test Book',
      'current_chapter' => 0,
      'total_chapters' => 10
    }.to_yaml)

    # Create minimal settings.yml
    File.write(File.join(tmp_dir, 'data', 'settings.yml'), {
      'llm' => {
        'provider' => 'openai',
        'model' => 'gpt-4o-mini',
        'temperature' => 0.7,
        'timeout' => 240,
        'default_options' => { 'max_tokens' => 12_000 }
      }
    }.to_yaml)
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  describe 'Producer interface' do
    it 'includes the Producer module' do
      expect(described_class.ancestors).to include(Eidos::Producer)
    end

    it 'has producer_name :chapter' do
      expect(described_class.producer_name).to eq(:chapter)
    end

    it 'has a description' do
      expect(described_class.producer_description).to be_a(String)
      expect(described_class.producer_description).not_to be_empty
    end

    it 'has a default output path' do
      expect(described_class.default_output_path).to eq('content/chapters')
    end
  end

  describe '#produce' do
    let(:mock_chapter_data) do
      {
        'title' => 'Test Chapter',
        'content' => 'Once upon a time in a code review far far away...',
        'summary' => 'A test chapter',
        'programming_themes' => ['testing'],
        'comedy_elements' => ['sarcasm'],
        'difficulty_level' => 'beginner',
        'one_punch_man_references' => [],
        'new_characters' => [],
        'story_facts' => {}
      }
    end

    it 'returns a ProducerResult', :aggregate_failures do
      producer = described_class.new(project_root: tmp_dir)

      # Stub the internal ChapterGenerator to avoid LLM calls
      generator = instance_double(Eidos::ChapterGenerator)
      allow(Eidos::ChapterGenerator).to receive(:new).and_return(generator)
      allow(generator).to receive(:generate_next_chapter).and_return('chapter content')

      result = producer.produce(config: { auto_generate: true })

      expect(result).to be_a(Eidos::ProducerResult)
      expect(result.success?).to be true
      expect(result.canon_version).not_to be_nil
    end

    it 'passes snapshot to ChapterGenerator' do
      producer = described_class.new(project_root: tmp_dir)

      generator = instance_double(Eidos::ChapterGenerator)
      allow(Eidos::ChapterGenerator).to receive(:new).and_return(generator)
      allow(generator).to receive(:generate_next_chapter).and_return('content')

      producer.produce(snapshot: nil, config: { auto_generate: true })

      expect(Eidos::ChapterGenerator).to have_received(:new).with(
        hash_including(snapshot: nil)
      )
    end

    it 'returns failure result on error' do
      producer = described_class.new(project_root: tmp_dir)

      generator = instance_double(Eidos::ChapterGenerator)
      allow(Eidos::ChapterGenerator).to receive(:new).and_return(generator)
      allow(generator).to receive(:generate_next_chapter).and_raise(StandardError, 'LLM failed')

      result = producer.produce(config: { auto_generate: true })

      expect(result.success?).to be false
      expect(result.error).to include('LLM failed')
    end
  end

  describe 'output location' do
    it 'writes to explicit output path when provided' do
      output_dir = File.join(tmp_dir, 'custom_output')

      producer = described_class.new(project_root: tmp_dir)

      generator = instance_double(Eidos::ChapterGenerator)
      allow(Eidos::ChapterGenerator).to receive(:new).and_return(generator)
      allow(generator).to receive(:generate_next_chapter).and_return('content')

      result = producer.produce(config: { auto_generate: true }, output: output_dir)

      expect(result.output_path).to eq(output_dir)
      expect(Dir.exist?(output_dir)).to be true
    end

    it 'uses default output path when not provided' do
      producer = described_class.new(project_root: tmp_dir)

      generator = instance_double(Eidos::ChapterGenerator)
      allow(Eidos::ChapterGenerator).to receive(:new).and_return(generator)
      allow(generator).to receive(:generate_next_chapter).and_return('content')

      result = producer.produce(config: { auto_generate: true })

      expect(result.output_path).to eq(File.join(tmp_dir, 'content/chapters'))
    end

    it 'creates output directory if missing' do
      output_dir = File.join(tmp_dir, 'nonexistent', 'deeply', 'nested')

      producer = described_class.new(project_root: tmp_dir)

      generator = instance_double(Eidos::ChapterGenerator)
      allow(Eidos::ChapterGenerator).to receive(:new).and_return(generator)
      allow(generator).to receive(:generate_next_chapter).and_return('content')

      producer.produce(config: { auto_generate: true }, output: output_dir)

      expect(Dir.exist?(output_dir)).to be true
    end
  end

  describe '#validate!' do
    it 'raises SnapshotNotFoundError for invalid snapshot' do
      # Set up story bible with empty snapshots
      bible_path = File.join(tmp_dir, 'data', 'story_bible')
      FileUtils.mkdir_p(File.join(bible_path, 'snapshots'))
      File.write(File.join(bible_path, 'snapshots', '_index.yml'), { 'snapshots' => [] }.to_yaml)

      producer = described_class.new(project_root: tmp_dir)
      expect { producer.validate!(snapshot: 'nonexistent') }
        .to raise_error(Eidos::SnapshotNotFoundError)
    end
  end

  describe 'registration' do
    it 'is registered in the Producer registry' do
      # Re-register since other tests may have reset the registry
      Eidos::Producer.register(:chapter, described_class)
      expect(Eidos::Producer.find(:chapter)).to eq(described_class)
    end
  end

  # T011 / US1 / feature 012-fix-ux-unify-bible
  describe '--content-model override routing' do
    it 'routes config[:model] through Configuration.load as content.model (not llm.model)' do
      producer = described_class.new(project_root: tmp_dir)
      generator = instance_double(Eidos::ChapterGenerator)
      allow(Eidos::ChapterGenerator).to receive(:new).and_return(generator)
      allow(generator).to receive(:generate_next_chapter).and_return('content')
      allow(Eidos::Configuration).to receive(:load).and_call_original

      producer.produce(config: { auto_generate: true, model: 'gpt-test-xyz' })

      expect(Eidos::Configuration).to have_received(:load).with(
        File.expand_path(tmp_dir), hash_including('content.model' => 'gpt-test-xyz')
      )
    end
  end
end
