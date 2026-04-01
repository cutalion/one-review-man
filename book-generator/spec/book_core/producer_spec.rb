# frozen_string_literal: true

require 'book_core/producer'
require 'book_core/snapshot_errors'
require 'fileutils'
require 'tmpdir'

RSpec.describe BookCore::Producer do
  # Create a test producer class for each test to avoid state leakage
  let(:test_producer_class) do
    Class.new do
      include BookCore::Producer

      producer_name :test
      producer_description 'A test producer'
      default_output_path 'content/test'

      def initialize(project_root:, **_deps)
        @project_root = project_root
      end
    end
  end

  before do
    BookCore::Producer.reset_registry!
  end

  after do
    BookCore::Producer.reset_registry!
  end

  describe 'ClassMethods DSL' do
    it 'sets and gets producer_name' do
      expect(test_producer_class.producer_name).to eq(:test)
    end

    it 'sets and gets producer_description' do
      expect(test_producer_class.producer_description).to eq('A test producer')
    end

    it 'sets and gets default_output_path' do
      expect(test_producer_class.default_output_path).to eq('content/test')
    end
  end

  describe '#produce' do
    it 'raises NotImplementedError when not overridden' do
      producer = test_producer_class.new(project_root: '/tmp')
      expect { producer.produce }.to raise_error(NotImplementedError, /must implement #produce/)
    end
  end

  describe '#validate!' do
    let(:tmp_dir) { Dir.mktmpdir }

    after { FileUtils.rm_rf(tmp_dir) }

    it 'passes when no snapshot specified' do
      producer = test_producer_class.new(project_root: tmp_dir)
      expect { producer.validate! }.not_to raise_error
    end

    it 'raises SnapshotNotFoundError for invalid snapshot' do
      # Create story bible dir with snapshots structure
      bible_path = File.join(tmp_dir, 'data', 'story_bible')
      FileUtils.mkdir_p(File.join(bible_path, 'snapshots'))
      File.write(File.join(bible_path, 'snapshots', '_index.yml'), { 'snapshots' => [] }.to_yaml)

      producer = test_producer_class.new(project_root: tmp_dir)
      expect { producer.validate!(snapshot: 'nonexistent') }
        .to raise_error(BookCore::SnapshotNotFoundError)
    end

    it 'passes when output path parent is writable' do
      producer = test_producer_class.new(project_root: tmp_dir)
      output = File.join(tmp_dir, 'output', 'chapters')
      expect { producer.validate!(output: output) }.not_to raise_error
    end
  end

  describe 'Registry' do
    it 'registers a producer' do
      BookCore::Producer.register(:test, test_producer_class)
      expect(BookCore::Producer.find(:test)).to eq(test_producer_class)
    end

    it 'finds a registered producer by name' do
      BookCore::Producer.register(:test, test_producer_class)
      expect(BookCore::Producer.find(:test)).to eq(test_producer_class)
    end

    it 'returns nil for unregistered producer' do
      expect(BookCore::Producer.find(:nonexistent)).to be_nil
    end

    it 'lists all registered producers' do
      BookCore::Producer.register(:test, test_producer_class)
      all = BookCore::Producer.all
      expect(all).to eq({ test: test_producer_class })
    end

    it 'accepts string names and converts to symbol' do
      BookCore::Producer.register('test', test_producer_class)
      expect(BookCore::Producer.find('test')).to eq(test_producer_class)
    end

    it 'resets registry' do
      BookCore::Producer.register(:test, test_producer_class)
      BookCore::Producer.reset_registry!
      expect(BookCore::Producer.all).to be_empty
    end
  end

  describe 'extensibility (SC-002)' do
    it 'allows adding a new producer with only interface + registration' do
      # Define a completely new producer inline — no changes to existing code
      dummy_producer_class = Class.new do
        include BookCore::Producer

        producer_name :dummy
        producer_description 'A dummy producer for testing extensibility'
        default_output_path 'content/dummy'

        def initialize(project_root:, **_deps)
          @project_root = project_root
        end

        def produce(snapshot: nil, config: {}, output: nil)
          BookCore::ProducerResult.new(
            success: true,
            output_path: output || File.join(@project_root, self.class.default_output_path),
            canon_version: 'unversioned',
            artifacts: [],
            error: nil
          )
        end
      end

      BookCore::Producer.register(:dummy, dummy_producer_class)

      # Verify it's discoverable
      expect(BookCore::Producer.find(:dummy)).to eq(dummy_producer_class)

      # Verify it works through the interface
      producer = dummy_producer_class.new(project_root: '/tmp')
      result = producer.produce
      expect(result.success?).to be true
      expect(result.canon_version).to eq('unversioned')
    end
  end
end
