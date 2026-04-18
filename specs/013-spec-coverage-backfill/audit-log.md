# IP-Neutrality Audit Log — Feature 013

**Audit commit (pre-migration baseline)**: `4966b5f`
**Migration PR**: _(populated on merge — all fixes currently in working tree on branch `013-spec-coverage-backfill`)_
**Status**: Complete

## Findings

| # | File:line (at `4966b5f`) | Original content | Decision | New location | Commit |
|---|---|---|---|---|---|
| 1 | `eidos/lib/eidos/prompts/chapter_prompts.txt` (4 sites) | `{BOOK_TITLE}`, `{BOOK_GENRE}`, `{BOOK_SETTING}`, `{BOOK_STYLE}` | rename | `{STORY_TITLE}` / `{STORY_GENRE}` / `{STORY_SETTING}` / `{STORY_STYLE}` — same file | working tree (T031) |
| 2 | `eidos/lib/eidos/prompts/new_character_creation_prompt.txt` (3 sites) | `{BOOK_TITLE}`, `{BOOK_GENRE}`, `{BOOK_SETTING}` | rename | `{STORY_TITLE}` / `{STORY_GENRE}` / `{STORY_SETTING}` — same file | working tree (T031) |
| 3 | `eidos/lib/eidos/prompts/PLACEHOLDERS_REFERENCE.md` | "Story Context" section heading + "Book-specific" wording using `BOOK_*` | rename | Section renamed to "Story-specific"; keys documented as `STORY_*` with back-compat note | working tree (T031) |
| 4 | `eidos/templates/jekyll/{_config.yml,characters.md,characters.ru.md,index.md,index.ru.md}` | `{{BOOK_TITLE}}`, `{{BOOK_DESCRIPTION}}`, `{{BOOK_TITLE_RU}}`, `{{BOOK_GENRE_DESCRIPTION_RU}}` | rename | `{{STORY_TITLE}}` / `{{STORY_DESCRIPTION}}` / `{{STORY_TITLE_RU}}` / `{{STORY_GENRE_DESCRIPTION_RU}}` — same files | working tree (T031) |
| 5 | `eidos/lib/eidos/chapter_generator.rb:855–863` (fill site) | Hash keys `BOOK_TITLE`, `BOOK_GENRE`, `BOOK_SETTING`, `BOOK_STYLE` sourced from legacy accessors | rename + parameterize | Keys renamed to `STORY_*`; values sourced from `@config.story_title` / `story_genre` / `story_setting` / `story_style` | working tree (T032) |
| 6 | `eidos/lib/eidos/chapter_generator.rb` (`determine_book_setting` helper) | Method name baked "book" framing into engine | rename | Method renamed to `determine_story_setting`; callers updated | working tree (T032) |
| 7 | `eidos/lib/eidos/chapter_generator.rb` (`build_world_details_summary`, `build_character_guidelines`, `build_genre_guidelines`) | Metadata-reading helpers read `humor_style` / `genre` via legacy accessors | parameterize | Helpers now read `@config.story_style` / `story_genre`; back-compat chain absorbs legacy worlds | working tree (T032) |
| 8 | `eidos/lib/eidos/chapter_generator.rb` (`show_missing_information_guide`, `collect_genre_info`, `collect_style_info`, `collect_setting_info`) | Missing-field detection + interactive prompts used `BOOK_*` placeholder names and wrote legacy keys | rename | `STORY_*` placeholder names in detection; writes now `update_localized('en', 'story_X' => ...)` | working tree (T032) |
| 9 | `eidos/lib/eidos/cli/publish.rb` (Jekyll placeholder construction) | Hash keys `BOOK_TITLE`, `BOOK_AUTHOR`, `BOOK_GENRE`, plus `_RU` variants and `BOOK_GENRE_DESCRIPTION_RU` | rename | Keys renamed to `STORY_*`; value reads fall back through `story_<field>` → `<field>` for legacy worlds | working tree (T032) |
| 10 | `eidos/lib/eidos/chapter_generator.rb:147` | Fallback template literal `'Write Chapter {CHAPTER_NUMBER} of a programming comedy story'` | generalize | `'Write Chapter {CHAPTER_NUMBER} of a {{STORY_GENRE}} story'` — genre parameterized via existing fill path | working tree (T034) |
| 11 | `eidos/lib/eidos/chapter_generator.rb:340` | `nested_legacy = File.join(@project_root, 'books', 'one-review-man', '_chapters')` — legacy path fragment | remove | — (unreachable code path; no live callers confirmed via `Grep 'nested_legacy'`) | working tree (T035) |
| 12 | `eidos/lib/eidos/chapter_generator.rb:747` (`build_main_character_placeholders`) | `find_character_real_name(chars, 'One Review Man') ||` fallback branch gated on `config.one_review_man_world?` | remove (dead branch) | — (the generic `main_characters` array path already resolves ORM aliases via `worlds/one-review-man/data/world_config.yml` `generation.main_characters` config, so no new alias file was needed; the ORM branch was dead code) | working tree (T036) |
| 13 | `eidos/lib/eidos/world_config.rb:245–248` | `def one_review_man_world?; title.include?('One Review Man') \|\| title.include?('Ванревьюмэн'); end` | remove | — (only caller was the dead branch removed in finding #12; verified via `Grep 'one_review_man_world'` → zero hits outside spec) | working tree (T037) |
| 14 | `eidos/lib/eidos/writer_agent.rb:119–132` (`build_system_prompt`) | Framing hardcoded "programming comedy book", ORM fallback title/description, "Programming humor and parody" / "One-Punch Man style absurdist comedy" / "Technical jokes that developers will appreciate" | parameterize | Reads `config.story_title` / `config.story_genre` / `config.story_description` / `config.story_style` via new `world_config_object` helper; framing says "story" (IP-first worldview); genre-neutral style lines | working tree (T038) |
| 15 | `eidos/lib/eidos/llm_service.rb:659, 663, 683` (`build_chapter_translation_prompt`) | "programming comedy chapter", "One-Punch Man parody references", "Maintain the One-Punch Man parody style" | generalize | Genre-neutral wording: "chapter", "humor and tone", "Maintain the original stylistic voice" | working tree (T040 follow-up — discovered during SC-009 grep sweep) |
| 16 | `eidos/spec/eidos/world_config_spec.rb` (`#one_review_man_world?` describe block) | Two examples covering the removed predicate | remove | — (predicate deleted in finding #13; suite now 629 examples, previously 631) | working tree (T037) |
| 17 | `worlds/one-review-man/data/world_config.yml` (`localized.en`, `localized.ru`) | Legacy bare keys `title`, `genre`, `humor_style` | rename (data migration) | `story_title`, `story_genre`, `story_style`, plus new `story_setting` in both locales | working tree (T030) |

## US1 manual verification (T013)

- **Template broken**: renamed `{BOOK_TITLE}` → `{BOOK_TITL}` in `eidos/lib/eidos/prompts/chapter_prompts.txt`.
- **Suite run**: `MOCK_AI=true bundle exec rspec spec/generate_command_spec.rb` → 2 failures (expected).
- **Subprocess stderr** (reproduced via `bin/produce chapter --auto` in a minimal test world):
  ```
  Error: Prompt assertion failed during (no current spec example) → MockLLMService#generate_chapter_structured:
    category: unfilled placeholder
    placeholders: BOOK_TITL
    prompt (first 500 chars): "# Generic Chapter Generation Prompt\n\nGenerate Chapter 1\n\n## Story Context\n- Title: {BOOK_TITL}\n..."
  ```
- **Revert**: restored `{BOOK_TITLE}` → suite green (620 examples, 0 failures).
- **Engine fix folded in during T013**: `eidos/lib/eidos/chapter_generator.rb:849` now always emits `BOOK_*` placeholders (was gated on `localized_structure?`). The harness flagged this as a latent escape — a non-localized world would have shipped `{BOOK_TITLE}` literally to the LLM. Fix hoists `en_metadata` resolution out of the gate and relies on WorldConfig defaults.
- **Note**: tasks.md T013 scripts the break against `{{STORY_TITLE}}`, but the BOOK→STORY rename lands in Phase 7 / T031. Substituted `{BOOK_TITLE}` as the pre-rename equivalent; intent of the verification is unchanged.

## US5 IP-neutrality verification (T039 + T040)

- **T039 non-ORM world spec**: `eidos/spec/integration/ip_neutrality_non_orm_world_spec.rb` scaffolds a cooking-mystery world (`story_title: 'The Vanishing Chef'`, `story_genre: 'mystery'`, `story_setting: 'boutique restaurant kitchen'`, character `chef_marin`) in `Dir.mktmpdir`, runs `ruby bin/produce chapter --auto -w <tmpdir>` with `EIDOS_SPEC_PROMPT_LOG` set, asserts zero occurrences of 13 ORM terms (4 story-level phrases + 9 character ids) in the captured prompts. **Result: 1 example, 0 failures.**
- **T040 SC-009 grep sweep**:
  - `rg 'one.?review.?man' -i eidos/lib/` → **0 matches**
  - `rg 'Ванревьюмэн' eidos/lib/` → **0 matches**
  - `rg 'programming comedy' eidos/lib/` → **0 matches** (after llm_service.rb generalization — finding #15)
  - `rg 'One-Punch Man' eidos/lib/` → **0 matches** (after writer_agent.rb + llm_service.rb generalization — findings #14, #15)
- **T033 SC-010 grep sweep**:
  - `rg 'BOOK_(TITLE|GENRE|SETTING|STYLE)' eidos/lib/ eidos/lib/eidos/prompts/ eidos/templates/` → **0 matches**
  - `rg 'book_(title|genre|setting|style)' eidos/lib/` → **0 matches** (the back-compat accessor builds the key via string interpolation `"book_#{field}"`, so the literal string never appears in source)

## Back-compat obligations

- `world_config.yml` loaders MUST accept legacy `book_*` keys for one release (FR-021).
- Read-path chain implemented in `world_config.rb#localized_field_with_compat`: `story_<field>` → `book_<field>` → bare (`title`/`genre`/`setting`/`style`; plus `humor_style` as bare alias for `style`). First fallback hit per `(config_file_path, locale, field)` tuple emits a three-line deprecation notice to `$stderr` via `emit_deprecation_notice_once`; subsequent reads on the same tuple stay silent for the process lifetime.
- The ORM world at `worlds/one-review-man/data/world_config.yml` is migrated to `story_*` keys in this PR (finding #17), so the back-compat path only serves hypothetical external users.
- Back-compat spec: `eidos/spec/world_config_legacy_keys_spec.rb` (5 examples, 0 failures) locks all five legacy-reading scenarios.
- **TODO (follow-up release)**: remove the `book_<field>` and bare-name branches from `localized_field_with_compat` after two releases; the in-source `TODO(follow-up)` comment flags the removal site.

## Residual ORM content in the repo (expected)

After the audit, ORM-specific content MAY remain in:

- `worlds/one-review-man/**` — by design, this is the ORM storyworld tree. The data files now use `story_*` keys (finding #17) and carry ORM character names, relationships, plot threads, and narrative in their normal data fields. None of that leaks into engine `eidos/lib/` code.
- Documentation (`README.md`, `CLAUDE.md`, `docs/**`, `specs/**`) — allowed per edge case. The new `013-spec-coverage-backfill` spec + audit log intentionally enumerate ORM terms as grep targets.
- Spec support fixtures that explicitly use ORM names as example data (e.g. `spec/support/mock_llm_service.rb` mock chapter mentions `'Saitama'`-ish example — none of these ship in production code).

No ORM-specific content remains in:

- `eidos/lib/**` (except the back-compat loader path in `world_config.rb#localized_field_with_compat` and its dedicated spec).
- `eidos/lib/eidos/prompts/**` (shipped templates).
- `eidos/exe/**`, `eidos/bin/**`.
- `eidos/templates/jekyll/**` (all `BOOK_*` Jekyll placeholders renamed).
