# Quickstart: Producer Contract Interface

## Using the ChapterProducer (Ruby API)

```ruby
require 'book_core/producers/chapter_producer'

# Create a chapter producer
producer = BookCore::Producers::ChapterProducer.new(
  project_root: '/path/to/books/one-review-man'
)

# Generate a chapter with default settings
result = producer.produce

# Generate pinned to a snapshot with custom output
result = producer.produce(
  snapshot: 'v1-launch',
  config: { auto_generate: true },
  output: '/tmp/my-chapters'
)

# Check result
if result.success
  puts "Generated #{result.artifacts.length} files at #{result.output_path}"
  puts "Canon version: #{result.canon_version}"
else
  puts "Failed: #{result.error}"
end
```

## CLI Usage (unchanged surface)

```bash
# Generate next chapter (same as before)
book generate chapter -b books/one-review-man

# Generate with explicit output location (new --output flag)
book generate chapter --output /tmp/chapters -b books/one-review-man

# Generate pinned to snapshot (existing --snapshot flag)
book generate chapter --snapshot v1-launch -b books/one-review-man
```

## Creating a New Producer

```ruby
# lib/book_core/producers/my_producer.rb
module BookCore
  module Producers
    class MyProducer
      include BookCore::Producer

      producer_name :my_thing
      producer_description "Generate my thing from Story Bible canon"
      default_output_path "content/my_things"

      def initialize(project_root:, **deps)
        @project_root = project_root
      end

      def produce(snapshot: nil, config: {}, output: nil)
        validate!(snapshot: snapshot, config: config, output: output)

        # ... your generation logic ...

        ProducerResult.new(
          success: true,
          output_path: output || default_output_path,
          canon_version: resolve_canon_version(snapshot),
          artifacts: ['/path/to/generated/file']
        )
      end
    end
  end
end

# Self-register
BookCore::Producer.register(:my_thing, BookCore::Producers::MyProducer)
```

## Looking Up Producers

```ruby
# Find by name
klass = BookCore::Producer.find(:chapter)
producer = klass.new(project_root: root)

# List all registered
BookCore::Producer.all.each do |name, klass|
  puts "#{name}: #{klass.producer_description}"
end
```
