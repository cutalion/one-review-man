# Form Definition Contract

**Feature**: 014-storyworld-pivot

Forms are declared as YAML files. Built-ins live at `eidos/lib/eidos/forms/<name>.yml`. World-local forms live at `worlds/<name>/data/forms/<name>.yml`. The FormRegistry loads both sets per CLI invocation; world-local wins on name collision (FR-013).

## Schema

```yaml
# worlds/<name>/data/forms/haiku.yml  OR  eidos/lib/eidos/forms/haiku.yml
name: haiku                     # REQUIRED. [a-z][a-z0-9-]* unique within registry.
category: text                  # REQUIRED. text | image | script.
default_length: 3               # optional. Integer in form's natural unit.
default_shape: "3 lines, 5-7-5" # optional. Free-form string for non-numeric shapes.
prompt_template_path: ./haiku.prompt.txt
                                # REQUIRED. Relative to this YAML file's directory.
                                # File MUST exist at load time.
canon_context:                  # optional. Defaults to [all_characters].
  - all_characters
  - recent_events
```

**At least one of** `default_length` / `default_shape` MUST be present.

**Supported `canon_context` values (MVP)**:
- `all_characters` — inject the world's full character list.
- `recent_events` — inject the last N events from canon (N = 5 in MVP).
- `current_chapter` — inject the most recent chapter-form piece's summary (meaningful only when the calling invocation is adding to a chapter arc).
- `all_locations` — inject the world's full location list.
- `none` — no canon injected; piece is a standalone draft.

Unknown values cause the form to be skipped with a stderr warning.

## Prompt template contract

The template file referenced by `prompt_template_path` uses the existing `{PLACEHOLDER}` / `{{PLACEHOLDER}}` system and MUST include:

1. A `{USER_PROMPT}` placeholder where the `--prompt` text is injected.
2. A `{LENGTH_TARGET}` placeholder where the resolved length/shape is injected.
3. A `{CANON_CONTEXT}` placeholder where the requested canon slices are injected.
4. A trailing canon-delta request block matching the pattern below.

### Canon-delta request block (trailing section, REQUIRED)

The template MUST end with an instruction block like the following. The exact wording is the author's choice; the sentinel line and YAML shape are fixed:

```text
After your piece, emit the canonical changes it introduces. Write them after a line
containing exactly:

---CANON-DELTA---

Then a YAML document of the shape:

new_characters: []      # list of {id, name, role, description, ...}
new_locations: []       # list of {id, name, description, ...}
new_facts: []           # list of {subject, kind, value}
new_events: []          # list of {when, who, what, where}
new_relationships: []   # list of {subject_id, kind, object_id}
entity_updates: []      # list of {entity_kind, entity_id, attribute, old_value, new_value}

Any section may be empty. If your piece introduces nothing canonical, emit all empty lists.
```

The `CanonDelta.parse` routine splits on `---CANON-DELTA---` and loads the YAML after it. Malformed output (missing sentinel, unparseable YAML, wrong top-level shape) produces an empty delta with `parse_error` set and opens a `:malformed-delta` audit finding per FR-022.

## Template testability

Because the prompt-assertion harness in `MockLLMService` fails any spec whose outgoing prompt carries an unfilled `{PLACEHOLDER}` or whose template declares unused placeholders, all new form templates MUST:

- Have every declared placeholder filled by the `PieceProducer` fill step, AND
- Reference only placeholders supplied by the producer.

Failures surface as `Prompt assertion failed ... → MockLLMService#generate_text` with the exact placeholder names.

## Registry notice

When a world-local form overrides a built-in, the CLI prints on that invocation:

```text
Using world-local form 'haiku' (overrides built-in).
```

This is the only place the CLI tells the user which form won; after that line the invocation proceeds normally.
