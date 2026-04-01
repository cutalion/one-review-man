# Ruby API Contract: Instagram Comic Producer

## InstagramComicProducer

```ruby
module BookCore
  module Producers
    class InstagramComicProducer
      include BookCore::Producer

      producer_name :instagram_comic
      producer_description "Generate comic-style panels from narrative sources"
      default_output_path "content/comics"

      # @param project_root [String] Absolute path to IP project root
      # @param llm_service [LLMService, nil] Optional injected LLM service
      def initialize(project_root:, llm_service: nil)
      end

      # @param snapshot [String, nil] Canon snapshot name, or nil for latest
      # @param config [Hash] Producer-specific options:
      #   - :source [Hash] REQUIRED { type: "chapter", number: Integer }
      #   - :panel_count [Integer] Number of panels (default: 4)
      #   - :art_style [String] Art style (default: "manga")
      #   - :image_format [String] "square" or "portrait" (default: "square")
      #   - :description_only [Boolean] Skip image generation (default: false)
      # @param output [String, nil] Output directory path
      # @return [ProducerResult]
      def produce(snapshot: nil, config: {}, output: nil)
      end
    end
  end
end

# Self-register
BookCore::Producer.register(:instagram_comic, BookCore::Producers::InstagramComicProducer)
```

## CharacterAppearance

```ruby
module BookCore
  class CharacterAppearance
    # @param character_data [Hash] Raw character YAML data from Story Bible
    def initialize(character_data)
    end

    # @return [String] Character display name
    attr_reader :name

    # @return [String] Character slug/id
    attr_reader :id

    # @return [String] Composed visual description for image prompts
    def to_prompt
      # Returns: "Kenji Yamamoto: 28 years old, light skin, messy black hair,
      #           tired eyes with dark circles, wearing worn-out grey hoodie and jeans,
      #           always looks sleepy and slouches"
    end

    # Extract CharacterAppearance objects for all characters in a Story Bible
    # @param story_bible_path [String] Path to story_bible directory
    # @return [Hash<String, CharacterAppearance>] Keyed by character id
    def self.extract_all(story_bible_path)
    end
  end
end
```

## PanelDescriptionGenerator

```ruby
module BookCore
  class PanelDescriptionGenerator
    # @param llm_service [LLMService] Text LLM service for scene selection
    def initialize(llm_service)
    end

    # Generate panel descriptions from narrative content
    # @param content [String] Narrative text (chapter markdown body)
    # @param characters [Hash<String, CharacterAppearance>] Available characters
    # @param panel_count [Integer] Number of panels to generate
    # @param art_style [String] Art style for prompt composition
    # @return [Array<ComicPanel>] Panels with descriptions, no images
    def generate(content:, characters:, panel_count: 4, art_style: "manga")
    end
  end
end
```

## ComicPanel

```ruby
module BookCore
  class ComicPanel
    attr_reader :sequence, :scene_description, :characters
    attr_accessor :image_path

    # @param sequence [Integer] 1-based panel number
    # @param scene_description [String] Scene description for image generation
    # @param characters [Array<String>] Character ids referenced
    # @param image_path [String, nil] Path to generated image
    def initialize(sequence:, scene_description:, characters: [], image_path: nil)
    end

    # @return [Hash] YAML-serializable representation
    def to_h
    end
  end
end
```

## PanelSet

```ruby
module BookCore
  class PanelSet
    attr_reader :source, :art_style, :image_format, :canon_version, :panels, :generated_at

    # @param source [Hash] e.g., { type: "chapter", number: 1 }
    # @param art_style [String]
    # @param image_format [String] "square" or "portrait"
    # @param canon_version [String, Hash]
    # @param panels [Array<ComicPanel>]
    def initialize(source:, art_style:, image_format:, canon_version:, panels: [])
    end

    # Save as YAML sidecar file
    # @param output_dir [String] Directory to write panels_NNN.yml
    # @return [String] Path to written sidecar file
    def save_sidecar(output_dir)
    end

    # Load from existing YAML sidecar file
    # @param path [String] Path to panels_NNN.yml
    # @return [PanelSet]
    def self.load_sidecar(path)
    end

    # @return [Boolean] true if all panels have image_paths
    def fully_generated?
    end

    # @return [Hash] YAML-serializable representation
    def to_h
    end
  end
end
```

## Config Hash Reference

```ruby
config = {
  source: { type: "chapter", number: 1 },  # REQUIRED
  panel_count: 4,                           # optional, default: 4
  art_style: "manga",                       # optional, default: "manga"
  image_format: "square",                   # optional, "square"|"portrait", default: "square"
  description_only: false                   # optional, default: false
}
```

## Error Handling

| Error | When | Response |
|-------|------|----------|
| ArgumentError("source is required") | No :source in config | Raised during validate! |
| ArgumentError("invalid source type") | Unknown source type | Raised during validate! |
| ArgumentError("source content not found") | Chapter file doesn't exist | Raised during validate! |
| ArgumentError("invalid panel_count") | panel_count <= 0 | Raised during validate! |
| SnapshotNotFoundError | Invalid snapshot name | Raised during validate! (inherited from Producer) |
| ProducerResult(success: false) | Image generation failure | Partial result with error; successful panels saved |
