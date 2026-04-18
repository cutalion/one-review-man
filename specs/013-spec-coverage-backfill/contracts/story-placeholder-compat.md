# Contract: `BOOK_*` → `STORY_*` back-compat read

Per Clarifications Q2 and FR-021, legacy `book_*` keys in `world_config.yml` MUST continue to load for one release. This contract specifies the exact back-compat behavior.

## Scope

The four placeholder pairs:

| Legacy key (accepted on read) | New key (canonical) |
|---|---|
| `generation.localized.<locale>.book_title` (or `title`) | `generation.localized.<locale>.story_title` |
| `generation.localized.<locale>.book_genre` (or `genre`) | `generation.localized.<locale>.story_genre` |
| `generation.localized.<locale>.book_setting` (or `setting`) | `generation.localized.<locale>.story_setting` |
| `generation.localized.<locale>.book_style` (or `style`) | `generation.localized.<locale>.story_style` |

## Read-path behavior (`lib/eidos/world_config.rb`)

```ruby
def story_title(locale = current_locale)
  localized = @data.dig('generation', 'localized', locale) || {}
  return localized['story_title'] if localized.key?('story_title')
  if (legacy = localized['book_title'] || localized['title'])
    emit_deprecation_notice_once(locale, 'title')
    return legacy
  end
  nil
end
# ...and the same shape for story_genre / story_setting / story_style
```

**Rules**:
1. `story_<field>` wins if present.
2. If absent, `book_<field>` is read, else the bare field name (`title`, `genre`, `setting`, `style`) — existing configs use the bare names.
3. Any fallback path emits a deprecation notice via `emit_deprecation_notice_once` (keyed by `(config_file_path, locale, field)` so it fires at most once per config-per-field-per-process).

**Deprecation notice format** (to `$stderr`):
```
⚠️  DEPRECATED: <config_file> uses legacy `<field>` key for locale `<locale>`.
   Rename to `story_<field>` before the next release.
   See specs/013-spec-coverage-backfill/spec.md Clarifications Q2.
```

## Write-path behavior

**`eidos world new` and all other writers MUST only emit `story_*` keys.** No writer introduces new `book_*` or bare-field-name keys. This is enforced by:
1. The new `world_config.yml` template writes `story_title:` etc.
2. A spec scaffolds a fresh world and asserts the generated YAML contains `story_title` / `story_genre` / `story_setting` / `story_style` and does NOT contain any of `book_title`, `title`, `book_genre`, `genre`, `book_setting`, `setting`, `book_style`, `style` (at the localized section).

## Placeholder usage in templates

All shipped templates use `{STORY_TITLE}`, `{STORY_GENRE}`, `{STORY_SETTING}`, `{STORY_STYLE}`. No shipped template references `BOOK_*` for these four fields after the migration (SC-010).

## Spec coverage

A dedicated spec (`spec/world_config_legacy_keys_spec.rb`) verifies:

1. A config with only `title:` under `generation.localized.en` reads as `story_title` with a deprecation notice.
2. A config with only `book_title:` reads identically, with the same deprecation notice.
3. A config with both `book_title:` and `story_title:` prefers `story_title` and emits no deprecation notice.
4. The deprecation notice fires at most once per `(config, locale, field)` per process.
5. `eidos world new` generates a config that passes step (3) without notices on subsequent loads.

## Removal in a follow-up feature

The back-compat read path is explicitly tagged `# TODO(follow-up): remove after two releases` so a future feature can delete it without archaeology. The deprecation notice includes the ref to this feature's spec so recipients of the notice can find the full context.
