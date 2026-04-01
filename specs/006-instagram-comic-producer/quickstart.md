# Quickstart: Instagram Comic Producer

## Generate comic panels from a chapter (Ruby API)

```ruby
require 'book_core/producers/instagram_comic_producer'

producer = BookCore::Producers::InstagramComicProducer.new(
  project_root: '/path/to/books/one-review-man'
)

# Generate 4 manga-style panels from chapter 1
result = producer.produce(
  config: {
    source: { type: "chapter", number: 1 },
    panel_count: 4,
    art_style: "manga",
    image_format: "square"
  },
  output: '/tmp/comic-panels'
)

if result.success?
  puts "Generated #{result.artifacts.length} panels at #{result.output_path}"
  # => Generated 5 panels at /tmp/comic-panels
  #    (4 PNGs + 1 YAML sidecar)
else
  puts "Error: #{result.error}"
end
```

## Generate with a canon snapshot

```ruby
result = producer.produce(
  snapshot: 'v1-launch',
  config: {
    source: { type: "chapter", number: 3 },
    art_style: "western comic",
    image_format: "portrait"
  }
)
# Output in default location: content/comics/
# Canon version recorded in panels_003.yml sidecar
```

## Description-only mode (preview without image generation)

```ruby
result = producer.produce(
  config: {
    source: { type: "chapter", number: 1 },
    description_only: true
  },
  output: '/tmp/comic-panels'
)
# Creates only panels_001.yml with scene descriptions
# No image generation API calls made
# panels have image_path: nil
```

## Re-generate images from saved descriptions

```ruby
# After editing panels_001.yml descriptions manually...
result = producer.produce(
  config: {
    source: { type: "chapter", number: 1 }
    # descriptions loaded from existing panels_001.yml
  },
  output: '/tmp/comic-panels'
)
# Uses saved descriptions, generates new images
```

## Look up the producer via registry

```ruby
require 'book_core/producers/instagram_comic_producer'

klass = BookCore::Producer.find(:instagram_comic)
producer = klass.new(project_root: root)
result = producer.produce(config: { source: { type: "chapter", number: 1 } })
```

## Output structure

After a full generation run:

```
/tmp/comic-panels/
├── panels_001.yml       # YAML sidecar with metadata + descriptions
├── panel_001_01.png     # Panel 1 (1024x1024 native)
├── panel_001_02.png     # Panel 2
├── panel_001_03.png     # Panel 3
└── panel_001_04.png     # Panel 4
```

The YAML sidecar contains:
```yaml
source:
  type: chapter
  number: 1
art_style: manga
image_format: square
canon_version: unversioned
generated_at: "2026-04-01T12:00:00Z"
panels:
  - sequence: 1
    scene_description: "A tired programmer slouches at his desk..."
    characters:
      - kenji_yamamoto
    image_path: panel_001_01.png
```
