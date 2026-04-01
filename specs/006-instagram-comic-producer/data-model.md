# Data Model: Instagram Comic Producer

## Entities

### ComicPanel (Value Object)

A single panel in a comic set. Immutable once created; image path is nil until generation.

| Attribute | Type | Description |
|-----------|------|-------------|
| sequence | Integer | 1-based panel number within the set |
| scene_description | String | Detailed scene description for image generation |
| characters | Array<String> | Character names referenced in this panel |
| image_path | String or nil | Absolute path to generated PNG file (nil before generation) |

**Naming convention**: `panel_NNN_NN.png` where NNN is source identifier, NN is sequence number.

**Lifecycle**: Created with scene_description during panel description step. Image path populated after image generation. No state transitions beyond that.

### PanelSet (Aggregate)

A collection of ComicPanels for one narrative source. Persisted as a YAML sidecar file.

| Attribute | Type | Description |
|-----------|------|-------------|
| source | Hash | Source reference: `{ type: "chapter", number: 1 }` |
| art_style | String | Art style used (e.g., "manga", "western comic", "pixel art") |
| image_format | String | "square" or "portrait" |
| canon_version | String or Hash | Canon version reference from snapshot or "unversioned" |
| panels | Array<ComicPanel> | Ordered list of panels in this set |
| generated_at | String | ISO 8601 timestamp of generation |

**Persistence**: YAML sidecar file named `panels_NNN.yml` in the output directory, where NNN is the zero-padded source identifier.

**Sidecar YAML structure**:
```yaml
source:
  type: chapter
  number: 1
art_style: manga
image_format: square
canon_version: v1-launch
generated_at: "2026-04-01T12:00:00Z"
panels:
  - sequence: 1
    scene_description: "A tired programmer in a grey hoodie..."
    characters:
      - kenji_yamamoto
    image_path: panel_001_01.png
  - sequence: 2
    scene_description: "..."
    characters:
      - kenji_yamamoto
      - emily_chen
    image_path: panel_001_02.png
```

**Lifecycle**:
1. Created empty (description-only mode): panels have scene_descriptions, image_path is nil
2. Fully generated: all panels have image_paths populated
3. Re-generated from saved descriptions: loaded from sidecar, image generation re-run

### CharacterAppearance (Value Object)

Visual description of a character extracted from Story Bible data. Used to build consistent image prompts.

| Attribute | Type | Description |
|-----------|------|-------------|
| name | String | Character display name |
| id | String | Character slug/identifier |
| physical_description | String | Composed text description of appearance |
| age | String or nil | Character age |
| skin_tone | String or nil | Skin tone |
| hair | String or nil | Hair description |
| eyes | String or nil | Eye description |
| outfit | String or nil | Clothing description |
| distinguishing_features | String or nil | Notable visual features |

**Source**: Extracted from Story Bible character YAML files under `data/story_bible/characters/`. Fields map directly from the `physical_appearance` hash in each character file.

**Composed prompt format**: Built from individual fields into a single visual description string suitable for injection into image generation prompts.

## Relationships

```
InstagramComicProducer (includes Producer module)
  ├── uses → LLMService (injected, for text + image generation)
  ├── uses → StoryBible (reads character data)
  ├── uses → SnapshotStore (if snapshot specified)
  ├── creates → PanelSet
  │     └── contains → ComicPanel[]
  └── uses → CharacterAppearance[] (extracted from StoryBible)

PanelDescriptionGenerator
  ├── uses → LLMService (text generation only)
  ├── reads → narrative source content (chapter markdown)
  ├── reads → CharacterAppearance[] (for prompt enrichment)
  └── produces → Array<ComicPanel> (descriptions only, no images)

CharacterAppearance
  └── reads from → StoryBible character YAML files
```

## Storage

### Output artifacts (per generation run)

Written to the producer's output directory:

```
output/
├── panels_001.yml       # YAML sidecar (metadata + panel descriptions)
├── panel_001_01.png     # Panel 1 image
├── panel_001_02.png     # Panel 2 image
├── panel_001_03.png     # Panel 3 image
└── panel_001_04.png     # Panel 4 image
```

### Input data (read-only)

- **Narrative content**: `content/chapters/NNN-chapter.md` (markdown with YAML front matter)
- **Character data**: `data/story_bible/characters/*.yml` (character YAML files with physical_appearance)
- **Snapshots**: `data/story_bible/snapshots/` (via SnapshotStore, if snapshot specified)
