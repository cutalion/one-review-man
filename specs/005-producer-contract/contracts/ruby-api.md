# Ruby API Contract: Producer Interface

## Producer Module

```ruby
module BookCore
  module Producer
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def producer_name(name = nil)
        # Get or set producer name
      end

      def producer_description(desc = nil)
        # Get or set description
      end

      def default_output_path(path = nil)
        # Get or set default output path
      end
    end

    # Main entry point — must be implemented by each producer
    # @param snapshot [String, nil] Canon snapshot name, or nil for latest/unversioned
    # @param config [Hash] Producer-specific options hash
    # @param output [String, nil] Output directory path, or nil for default
    # @return [ProducerResult]
    def produce(snapshot: nil, config: {}, output: nil)
      raise NotImplementedError
    end

    # Pre-flight validation — can be overridden, base provides common checks
    # @raises [SnapshotNotFoundError] if snapshot specified but not found
    # @raises [ArgumentError] if required config keys missing
    def validate!(snapshot: nil, config: {}, output: nil)
      # Base implementation: validate snapshot exists if specified
    end
  end
end
```

## Producer Registry

```ruby
# Registration (in producer class file)
BookCore::Producer.register(:chapter, BookCore::Producers::ChapterProducer)

# Lookup
BookCore::Producer.find(:chapter)  # => BookCore::Producers::ChapterProducer
BookCore::Producer.all             # => { chapter: BookCore::Producers::ChapterProducer }
```

## ChapterProducer

```ruby
module BookCore
  module Producers
    class ChapterProducer
      include Producer

      producer_name :chapter
      producer_description "Generate book chapters from Story Bible canon"
      default_output_path "content/chapters"

      # @param project_root [String] Absolute path to book project
      # @param llm_service [LLMService, nil] Optional injected LLM service
      def initialize(project_root:, llm_service: nil, **deps)
      end

      # @param snapshot [String, nil] Canon snapshot name
      # @param config [Hash] Keys: auto_generate (Boolean), model (String)
      # @param output [String, nil] Output directory override
      # @return [ProducerResult]
      def produce(snapshot: nil, config: {}, output: nil)
      end
    end
  end
end
```

## ProducerResult

```ruby
module BookCore
  ProducerResult = Struct.new(
    :success, :output_path, :canon_version, :artifacts, :error,
    keyword_init: true
  )
end
```

## CLI Integration

```bash
# Existing command — unchanged surface, producer wired internally
book generate chapter --snapshot v1-launch --output /tmp/chapters -b books/one-review-man

# New --output flag added to generate chapter
# Passed through to ChapterProducer as output: parameter
```

## Error Handling

| Error | When | Response |
|-------|------|----------|
| SnapshotNotFoundError | Invalid --snapshot value | Raised during validate!, before generation |
| ArgumentError | Missing required config | Raised during validate! |
| ProducerResult(success: false) | Generation failure | Result returned with error message |
