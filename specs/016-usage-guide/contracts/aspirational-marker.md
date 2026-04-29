# Contract: Aspirational Marker Syntax

**Owner**: `docs/usage-guide.md` author (the implementer / maintainer of guide content).
**Consumers**: doc-qa agent, impl-qa agent (both must detect markers identically).

This contract defines the exact form of the FR-007a aspirational marker — the annotation that flags a guide section as describing not-yet-implemented behavior.

---

## Form (the only form)

A Markdown blockquote line, exactly:

```markdown
## Section Title

> 🚧 **Not yet implemented** — describes the desired user experience; implementation tracked in spec NNN-name.
```

Or, when the implementation is not yet specced:

```markdown
> 🚧 **Not yet implemented** — describes the desired user experience; implementation tracked separately.
```

The blockquote MUST appear immediately under the H2 or H3 heading whose section it marks, with a single blank line between the heading and the marker. No other content may sit between the heading and the marker.

---

## Detection regex

Both agents MUST use this exact detection logic:

1. Find every Markdown heading (`^#{2,3}\s+.+$`).
2. For each heading, scan forward, skipping blank lines (`^\s*$`), to the first non-blank line.
3. If that line matches `^>\s*🚧\s*\*\*Not yet implemented\*\*`, the heading's section is aspirational.

The regex `^>\s*🚧\s*\*\*Not yet implemented\*\*` is the contract. Variations (different emoji, different bolding, missing colon) DO NOT mark the section aspirational and MUST NOT be treated as such by the agents.

---

## Where markers may NOT appear

- Inside the body paragraphs of a section (mid-section).
- Inside fenced code blocks.
- After H1 headings (the document-title heading is never aspirational).
- Stacked (two or more aspirational markers under one heading) — invalid form.

If an agent encounters a violation of these placement rules, it MUST report a **doc-qa Tier 2 (Internal Consistency) FAIL** for the affected heading, citing the line number.

---

## v1 invariant

The v1 ship of `docs/usage-guide.md` (per FR-003 / Q4 / SC-009) MUST contain ZERO markers. A grep for the regex against the v1 ship MUST return zero matches.

The marker mechanism exists for *post-v1* guide edits — when a future feature spec describes a desired user experience and the guide is updated to document it ahead of implementation.

---

## Worked examples

### Valid — minimal marker

```markdown
## Live multiplayer canon merging

> 🚧 **Not yet implemented** — describes the desired user experience; implementation tracked in spec 022-multiplayer-canon.

When two collaborators edit the same canon branch in real time, …
```

### Valid — heading hierarchy preserved

```markdown
### Branching strategies

#### Time-skip branches

> 🚧 **Not yet implemented** — describes the desired user experience; implementation tracked separately.

A time-skip branch lets you fast-forward your canon by N years …
```

### Invalid — marker not under heading

```markdown
## Reviewing canon changes

When you run `eidos canon review`, …

> 🚧 **Not yet implemented** — …    ← This is invalid; mid-section markers are forbidden.
```

### Invalid — typo in keyword

```markdown
## Live multiplayer canon merging

> 🚧 **Not yet built** — …    ← Detection regex requires exactly "Not yet implemented".
```

The agents will treat this section as **current** (not aspirational), which causes Tier-1 failures when the section's commands don't exist. The author can either fix the marker or accept the failures as "this section is broken."

---

## Lifecycle

- Creating a section as aspirational: write the section with the marker on day 1.
- Promoting an aspirational section to current: in the PR that implements the feature, delete the marker line and adjust the section body to match what the implementation actually does. Run impl-qa default mode in the same PR — Tier 1 should now PASS.
- Demoting a current section to aspirational: rare; usually means the maintainer is rolling back behavior. Add the marker, optionally adjust the body to describe the desired (rolled-forward) behavior. Doc-qa Tier 1/2 still apply to aspirational content (vision alignment + internal consistency) — only impl-qa Tier 1/2 are skipped.
