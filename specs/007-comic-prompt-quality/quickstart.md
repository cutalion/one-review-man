# Quickstart: Comic Prompt Quality

## Verify text control in prompts (description-only mode)

```ruby
require 'book_core/producers/instagram_comic_producer'

producer = BookCore::Producers::InstagramComicProducer.new(
  project_root: '/path/to/books/one-review-man'
)

result = producer.produce(
  config: {
    source: { type: "chapter", number: 1 },
    description_only: true
  },
  output: '/tmp/comic-panels'
)

# Read the sidecar to inspect prompts
require 'yaml'
sidecar = YAML.load_file('/tmp/comic-panels/panels_001.yml')

sidecar['panels'].each do |panel|
  puts "Panel #{panel['sequence']}:"
  puts "  Scene: #{panel['scene_description'][0..80]}..."
  puts "  Text elements: #{panel['text_elements']&.length || 0}"
  panel['text_elements']&.each do |te|
    puts "    #{te['type']}: \"#{te['text']}\""
  end
  puts
end
```

## Expected output

Each panel should have:
1. **Scene description** with visual storytelling: camera angle, lighting, expressions, body language, composition
2. **Text elements** array: each with type (speech_bubble, sign, sound_effect, etc.) and exact text
3. Panels with no dialogue/text have an empty text_elements array

## Verify safeguard instruction in image prompts

After generating panels (non-description-only mode), the image prompts sent to the AI include:
- Exact text instructions: `speech bubble reading exactly: 'Another perfect review... how boring.'`
- Safeguard: `Do not add any text, words, or letters beyond what is explicitly specified in this prompt.`
- For text-free panels: `No text, no words, no letters, no speech bubbles anywhere in the image.`

## Test with MOCK_AI

```bash
cd book-generator
MOCK_AI=true bundle exec rspec spec/book_core/panel_description_generator_spec.rb
MOCK_AI=true bundle exec rspec spec/book_core/producers/instagram_comic_producer_spec.rb
```
