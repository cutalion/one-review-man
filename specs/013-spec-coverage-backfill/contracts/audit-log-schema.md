# Contract: `audit-log.md` schema

The durable IP-neutrality audit record lives at `specs/013-spec-coverage-backfill/audit-log.md`. Per Clarifications Q5, it is the source of truth for every ORM-leak finding and the decision taken.

## Structure

```markdown
# IP-Neutrality Audit Log — Feature 013

**Audit commit (pre-migration baseline)**: <SHORT-SHA>
**Migration PR**: <link or SHA range>
**Status**: <In progress | Complete>

## Findings

| # | File:line | Original content | Decision | New location | Commit |
|---|---|---|---|---|---|
| 1 | eidos/lib/eidos/chapter_generator.rb:147 | `"Write Chapter {CHAPTER_NUMBER} of a programming comedy story"` fallback | generalize | — | abc1234 |
| 2 | eidos/lib/eidos/chapter_generator.rb:747 | `find_character_real_name(chars, 'One Review Man')` | relocate | `worlds/one-review-man/data/character_aliases.yml` | def5678 |
| 3 | eidos/lib/eidos/world_config.rb:247 | `title.include?('One Review Man') \|\| title.include?('Ванревьюмэн')` | remove | — | abc1234 |
| 4 | eidos/lib/eidos/writer_agent.rb:123 | `"#{world_config['title'] || 'One Review Man'}", a programming comedy book` | parameterize | `world_config.story_description` | abc1234 |
| 5 | eidos/lib/eidos/prompts/chapter_prompts.txt | `{BOOK_TITLE}` etc. | generalize | — (renamed to `{STORY_TITLE}`) | abc1234 |
| ... | | | | | |

## Back-compat obligations

- `world_config.yml` loaders MUST accept legacy `book_*` keys for one release (FR-021).
- The ORM world at `worlds/one-review-man/data/world_config.yml` is migrated to `story_*` keys in this PR, so the back-compat path only serves hypothetical external users.

## Residual ORM content in the repo (expected)

After the audit, ORM-specific content MAY remain in:
- `worlds/one-review-man/**` — by design, this is the ORM storyworld tree.
- Documentation (`README.md`, `CLAUDE.md`, `docs/**`) — allowed per edge case.
- Spec support fixtures that explicitly use ORM names as example data (call out each one here).

No ORM-specific content MAY remain in:
- `eidos/lib/**` (except the back-compat loader path and its test)
- `eidos/lib/eidos/prompts/**` (shipped templates)
- `eidos/exe/**`, `eidos/bin/**`
```

## Decision enum (authoritative)

| Decision | Meaning |
|---|---|
| `generalize` | The content was rewritten to be genre-agnostic; no replacement needed from world config. Example: a default prompt phrasing that now works for any storyworld. |
| `parameterize` | The content was kept but driven from a `world_config.yml` key; the user's config fills it. Example: genre string injected via `{STORY_GENRE}`. |
| `relocate` | The content was moved out of the engine into an ORM-specific override file inside `worlds/one-review-man/`. Example: a character alias map. |
| `document-as-intentional` | The content stays where it is, but is explicitly annotated as intended/unavoidable (with the annotation itself living in-code). Example: the back-compat key loader's comment referencing `BOOK_*`. Use sparingly. |
| `remove` | The content was dead code / unused; deleted outright. |

## Validation rules

1. Every row MUST have a `file:line` that resolves against the audit's baseline commit (recorded in the document header).
2. Every row MUST have a non-empty `Decision` from the enum above.
3. Rows with decision `relocate` MUST have a non-`—` `New location`.
4. Rows with decision `generalize` / `remove` / `parameterize` / `document-as-intentional` MAY use `—` for `New location`.
5. The document MUST be committed in the same PR as the code changes it describes (FR-019).

## Completion signal

`Status: Complete` at the top of the document, combined with the grep-based SC-009/SC-010 checks passing, signals that US5 is closed.
