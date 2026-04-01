# frozen_string_literal: true

require 'book_core/producer_result'
require 'book_core/snapshot_store'
require 'book_core/snapshot_errors'
require 'book_core/story_bible'

module BookCore
  module Producer
    def self.included(base)
      base.extend(ClassMethods)
    end

    # Class-level registry
    @registry = {}

    class << self
      def register(name, klass)
        @registry[name.to_sym] = klass
      end

      def find(name)
        @registry[name.to_sym]
      end

      def all
        @registry.dup
      end

      def reset_registry!
        @registry.clear
      end
    end

    module ClassMethods
      def producer_name(name = nil)
        if name
          @producer_name = name.to_sym
        else
          @producer_name
        end
      end

      def producer_description(desc = nil)
        if desc
          @producer_description = desc
        else
          @producer_description
        end
      end

      def default_output_path(path = nil)
        if path
          @default_output_path = path
        else
          @default_output_path
        end
      end
    end

    def produce(snapshot: nil, config: {}, output: nil)
      raise NotImplementedError, "#{self.class} must implement #produce"
    end

    def validate!(snapshot: nil, config: {}, output: nil)
      validate_snapshot!(snapshot) if snapshot
      validate_output_path!(output) if output
    end

    private

    def validate_snapshot!(snapshot_name)
      bible_path = File.join(@project_root, StoryBible::STORY_BIBLE_DIR)
      return unless Dir.exist?(bible_path)

      store = SnapshotStore.new(story_bible_path: bible_path)
      result = store.get(snapshot_name)
      raise SnapshotNotFoundError, "Snapshot '#{snapshot_name}' not found" unless result
    end

    def validate_output_path!(output)
      parent = File.dirname(File.expand_path(output))
      return if File.writable?(parent) || !File.exist?(parent)

      raise ArgumentError, "Output path '#{output}' is not writable"
    end
  end
end
