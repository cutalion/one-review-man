# frozen_string_literal: true

require 'spec_helper'
require 'eidos/storage/factory'

RSpec.describe 'Storage extensibility' do
  # Minimal conforming backend — proves a new backend can plug in
  # without modifying StoryBible, CLI, or any application code.
  let(:null_entity_class) do
    Class.new do
      include Eidos::Storage::EntityStorage

      def initialize(**_opts); end
      def setup; end
      def story_bible_path = '(null)'
      def characters_dir = '(null)/characters'
      def locations_dir = '(null)/locations'
      def facts_path = '(null)/facts.yml'
      def relationships_path = '(null)/relationships.yml'
      def plot_threads_path = '(null)/plot_threads.yml'

      def all_characters = {}
      def get_character(_id) = nil
      def save_character(_id, _data) = nil
      def list_characters(appeared_in: nil) = [] # rubocop:disable Lint/UnusedMethodArgument
      def all_locations = {}
      def get_location(_id) = nil
      def save_location(_id, _data) = nil
      def all_facts = {}
      def get_facts_by_category(_category) = {}
      def add_fact(_category, _id, _data) = nil
      def search_facts(_query) = []
      def all_relationships = []
      def get_relationships_for(_character_id) = []
      def add_relationship(_data) = nil
      def all_plot_threads = []
      def active_plot_threads = []
      def add_plot_thread(_data) = nil
    end
  end

  let(:null_revision_class) do
    Class.new do
      include Eidos::Storage::RevisionStorage

      def initialize(**_opts); end
      def record(**_kwargs) = nil
      def history(**_kwargs) = []
      def get(**_kwargs) = nil
      def latest(**_kwargs) = nil
    end
  end

  let(:null_snapshot_class) do
    Class.new do
      include Eidos::Storage::SnapshotStorage

      def initialize(**_opts); end
      def create(**_kwargs) = {}
      def list = []
      def get(_name_or_version) = nil
      def latest = nil
      def snapshot_data(_name_or_version) = nil
    end
  end

  after do
    Eidos::Storage::Factory.backends.delete('null_test')
  end

  describe 'registering a conforming backend' do
    it 'succeeds without modifying core code' do
      expect do
        Eidos::Storage::Factory.register('null_test',
                                         entity_class: null_entity_class,
                                         revision_class: null_revision_class,
                                         snapshot_class: null_snapshot_class)
      end.not_to raise_error

      expect(Eidos::Storage::Factory.available_backends).to include('null_test')
    end

    it 'builds adapters from the registered backend' do
      Eidos::Storage::Factory.register('null_test',
                                       entity_class: null_entity_class,
                                       revision_class: null_revision_class,
                                       snapshot_class: null_snapshot_class)

      entity = Eidos::Storage::Factory.build_entity_storage('null_test')
      expect(entity.all_characters).to eq({})

      revision = Eidos::Storage::Factory.build_revision_storage('null_test')
      expect(revision.history).to eq([])

      snapshot = Eidos::Storage::Factory.build_snapshot_storage('null_test', entity_storage: entity)
      expect(snapshot.list).to eq([])
    end
  end

  describe 'rejecting a backend that does not include the contract module' do
    it 'raises error for entity class missing contract module' do
      bare_class = Class.new do
        def initialize(**_opts); end
      end

      expect do
        Eidos::Storage::Factory.register('null_test',
                                         entity_class: bare_class,
                                         revision_class: null_revision_class,
                                         snapshot_class: null_snapshot_class)
      end.to raise_error(ArgumentError, /must include EntityStorage contract module/)
    end

    it 'raises error for revision class missing contract module' do
      bare_class = Class.new do
        def initialize(**_opts); end
      end

      expect do
        Eidos::Storage::Factory.register('null_test',
                                         entity_class: null_entity_class,
                                         revision_class: bare_class,
                                         snapshot_class: null_snapshot_class)
      end.to raise_error(ArgumentError, /must include RevisionStorage contract module/)
    end

    it 'raises error for snapshot class missing contract module' do
      bare_class = Class.new do
        def initialize(**_opts); end
      end

      expect do
        Eidos::Storage::Factory.register('null_test',
                                         entity_class: null_entity_class,
                                         revision_class: null_revision_class,
                                         snapshot_class: bare_class)
      end.to raise_error(ArgumentError, /must include SnapshotStorage contract module/)
    end
  end

  describe 'contract stubs protect against unimplemented methods at runtime' do
    it 'raises NotImplementedError when calling unimplemented entity methods' do
      # A class that includes the contract but only implements setup
      minimal_class = Class.new do
        include Eidos::Storage::EntityStorage
        def initialize(**_opts); end
        def setup; end
      end

      instance = minimal_class.new
      expect { instance.all_characters }.to raise_error(NotImplementedError, /all_characters must be implemented/)
    end

    it 'raises NotImplementedError when calling unimplemented revision methods' do
      minimal_class = Class.new do
        include Eidos::Storage::RevisionStorage
        def initialize(**_opts); end
      end

      instance = minimal_class.new
      expect { instance.record }.to raise_error(NotImplementedError, /record must be implemented/)
    end

    it 'raises NotImplementedError when calling unimplemented snapshot methods' do
      minimal_class = Class.new do
        include Eidos::Storage::SnapshotStorage
        def initialize(**_opts); end
      end

      instance = minimal_class.new
      expect { instance.create }.to raise_error(NotImplementedError, /create must be implemented/)
    end
  end
end
