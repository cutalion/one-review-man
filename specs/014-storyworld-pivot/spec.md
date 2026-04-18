# Feature Specification: IP-Generator Pivot — Pieces, Forms, and Canon Feedback

**Feature Branch**: `014-storyworld-pivot`
**Created**: 2026-04-18
**Status**: Draft
**Input**: User description: Pivot Eidos from book-generator framing to IP-management system. The world (canon / Story Bible) is the single source of truth. Users produce various kinds of pieces — chapter, short story, vignette, haiku, comic script, character portrait, social post, illustration — and every produced piece feeds canon deltas back into the bible. P1: terminology pivot + unshackle length. P2: open-ended content forms. P3: universal canon-extraction contract.

## Clarifications

### Session 2026-04-18

- Q: What is the primary way a user reviews and resolves pending canon deltas? → A: **Optimistic apply with post-hoc audit.** Deltas merge into canon eagerly as part of piece production. A separate diagnostic operation (`canon review`) runs later (on-demand or in background) and surfaces potential issues — hallucinations, conflicts with existing canon, divergences from established patterns. The user then decides per finding: revert (undo the delta and optionally regenerate the piece), leave as-is, patch the canon manually, or other user-directed remediation. There is no "deferred / pending approval" gate before a delta becomes canonical.
- Q: When a user reverts a piece via `canon review`, what happens to the piece file on disk? → A: **Keep and disconnect.** The piece file stays on disk; its record is marked `canon_status: reverted`. The canon delta is rolled back so the bible no longer reflects the piece's additions, but the piece content remains inspectable and reusable (the user can regenerate, re-extract, or re-canonicalize later). Non-destructive by default; a future feature may add an explicit archive/delete affordance if needed.
- Q: What is the MVP scope of `canon review` detection? → A: **Explicit findings only.** The review surfaces only findings that were written to the audit log at delta-application time (conflicts from FR-020, malformed deltas from FR-022) plus orphaned-reference findings produced by revert cascades. No semantic/heuristic detection in MVP — no LLM pass, no rule engine for "suspected hallucinations" or "divergence from established patterns." Smarter detections are explicitly deferred (see Future Work / Deferred Review Capabilities).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Produce non-chapter pieces without book-era defaults (Priority: P1)

A storyworld author wants to add a short piece — a 400-word vignette, a tonal sketch, a one-paragraph entry — to an existing world. Today every generated artifact is treated as "a chapter" with a 1500–3000-word floor baked into the prompt, chapter-numbering frontmatter, and book-era terminology throughout the CLI, docs, and configuration. This story delivers the minimum terminology pivot: the system recognizes any generated artifact as a *piece* with a declared *form*, a length decided per invocation (not per world), and a canon-version reference — while existing `produce chapter` commands keep working unchanged for already-published worlds.

**Why this priority**: This is the minimum viable pivot. It unblocks users who want content outside the book frame without requiring any new form registry or canon-feedback contract. It is also a prerequisite for the remaining stories, since both rely on the "piece" abstraction and the removal of hard length floors.

**Independent Test**: A user can open a world, ask for a 400-word vignette via the CLI, and receive a piece whose output is not named `NNN-chapter.md`, does not carry chapter-numbering frontmatter, and whose length approximates 400 words — while on the same or a different world, `produce chapter` still works and produces output identical in shape to what it produced before this feature.

**Acceptance Scenarios**:

1. **Given** an existing world with previously-generated chapters, **When** the user runs the existing chapter-production command, **Then** a new chapter is generated and saved with no behavioral change from pre-feature output.
2. **Given** any world, **When** the user produces a piece in a non-chapter form with an explicit length target (e.g. 400 words, or 3 lines), **Then** the generated piece approximates that length and is not subject to the world's chapter length range.
3. **Given** a world whose configuration specifies a chapter length range, **When** the user produces a piece in any form other than chapter, **Then** the chapter length range does not appear in the produced piece's prompt or bound its output.
4. **Given** a produced piece of any form, **When** its saved record is inspected, **Then** the record includes the piece's form, its approximate measured length, the canon version it was produced from, and a stable identifier.
5. **Given** a user reads the project's top-level documentation and CLI help, **When** they try to understand how content is organized, **Then** the docs describe pieces (with chapter as one form) and do not claim the world is "a book" with numbered chapters as the organizing unit.

---

### User Story 2 - Produce content in an arbitrary form without waiting for engine changes (Priority: P2)

A storyworld author wants to generate content in a form the gem did not ship with: a haiku about a specific character, an Instagram caption for a recent event, a comic panel script, a character-portrait image prompt, a one-minute video script. They should not have to fork the gem or write Ruby. This story delivers an open content-form registry: built-in forms ship with sensible defaults, and a world can add its own forms by dropping a form-definition file into the world's data directory. The CLI discovers forms automatically; the user invokes any form via `produce piece --form <name>` or, when unambiguous, the short `produce <name>`.

**Why this priority**: Once the piece abstraction exists (P1), unlocking arbitrary forms is the leverage point that turns Eidos from "content generator" into "IP-scale content engine." Keeping it separable from P1 means we can ship the terminology pivot even if form-authoring tooling needs more iteration.

**Independent Test**: A user adds a single form-definition file to their world's data directory declaring a new form (e.g. "haiku" with a 3-line shape and a haiku-style prompt template). Without restarting the CLI or editing the gem, they invoke the form from the CLI and receive a piece that matches the declared shape.

**Acceptance Scenarios**:

1. **Given** a built-in form registered with the engine (chapter, haiku, vignette, comic-script, portrait, social-post, illustration), **When** the user runs `produce <form-name>` with an appropriate prompt, **Then** the piece is generated using the form's default length/shape and prompt template.
2. **Given** a world that declares a custom form in its data directory, **When** the CLI lists available forms for that world, **Then** the custom form appears alongside built-in forms.
3. **Given** a world's custom form name that does not collide with built-ins, **When** the user invokes the short CLI form (`produce <name>`), **Then** the piece is generated using the custom form.
4. **Given** a world's custom form name that collides with a built-in, **When** the user invokes the short CLI form, **Then** the world's form takes precedence and the user is informed which form was used.
5. **Given** a form categorized as a text form vs. an image form vs. a script form, **When** a piece of that form is generated, **Then** its output lands in a category-appropriate shape (text file / image asset + prompt / structured script), and its record annotates which category it belongs to.
6. **Given** a user invokes a form name that is not registered anywhere, **When** the CLI processes the command, **Then** the user sees a clear error listing available forms for their world.

---

### User Story 3 - Every produced piece keeps the world consistent, with audit as the safety net (Priority: P3)

A storyworld author generates many pieces over time — a chapter introduces a new AI named "Gidg.it," a haiku mentions a new location called "The CloudSwamp Lobby," a social post names a recurring joke. Today only the chapter producer feeds these back into the Story Bible; every other form is a dead-end for canon. This story delivers a universal canon-extraction contract: *every* producer, regardless of form, emits a structured canon-delta record alongside its output (new characters, new locations, new facts, new events, new relationships, updates to existing entities). Deltas are applied **optimistically**: they merge into canon as part of piece production, so the next piece already sees them. A separate **canon-review** operation runs later (on-demand or in background) and surfaces findings — conflicts with prior canon, likely hallucinations, divergences — with per-finding remediation: revert the piece (and optionally regenerate), leave as-is, or patch the canon manually. A dry-run mode previews a piece and its deltas without writing anything.

**Why this priority**: This closes the loop promised by the Storyworld framing. Without it, users who produce pieces in non-chapter forms (P2) experience a silent drift: their bible never learns from those pieces, so subsequent pieces contradict them. P3 is the correctness ceiling — without it, P2 is half a feature. Prioritized below P1/P2 because a world can still operate with P1/P2 alone, just with drift risk that the user manages manually. The optimistic model keeps generation friction low; correctness is enforced retroactively by review, not by blocking each piece.

**Independent Test**: A user generates a piece that introduces a new character. The character is added to the bible immediately; the next piece produced in that world has that character available in its context automatically. Later, the user runs `canon review`; if no issues are detected the review reports clean, and if an issue exists the user sees it with remediation options (revert / leave / patch).

**Acceptance Scenarios**:

1. **Given** a piece is produced from any registered form, **When** the piece is saved, **Then** a structured canon-delta record is saved alongside it naming zero or more of: new characters, new locations, new facts, new events, new relationships, updates to existing entities.
2. **Given** a user runs a piece producer with a dry-run flag, **When** generation completes, **Then** the piece content and its canon-delta record are shown to the user, nothing is written to the bible, and no persistent piece record is created.
3. **Given** a produced piece with non-empty canon deltas in default (auto-apply) mode, **When** the piece is finalized, **Then** all deltas in the record are applied atomically to the bible (all-or-none on validation failure) and the piece record references the resulting canon version.
4. **Given** a piece's delta introduces a new character whose id collides with an existing character in the bible but with different attributes, **When** the delta is applied, **Then** the delta is applied, the collision is recorded as a finding in the world's canon-review audit log with references to both the prior canon state and the new piece, and generation does not block.
5. **Given** one or more findings exist in the audit log, **When** the user runs `canon review`, **Then** each finding is presented with its context (which piece introduced it, what was prior canon, what is the suspected issue) and the user can choose: revert the originating piece (roll back its delta, optionally regenerate), leave the finding as accepted, or patch the canon manually. Closed findings MUST remain visible in the log with their resolution.
6. **Given** a producer for an image form, **When** a piece is produced, **Then** the canon-delta record is derived from the generation prompt and user-supplied metadata (not from the pixels), and the contract still produces zero or more valid delta entries.
7. **Given** a second piece is produced after a first piece's deltas were applied, **When** the second piece's prompt is assembled, **Then** the new canon entries from the first piece appear in the second piece's context automatically.
8. **Given** the user selects "revert" on a finding during `canon review`, **When** the revert completes, **Then** the delta associated with the originating piece is rolled back to its prior state, the piece file remains on disk with its record marked `canon_status: reverted` (non-destructive), and a subsequent `canon review` no longer lists that finding.

---

### Edge Cases

- **Chapter producer back-compat**: what if the old chapter command is invoked in a world that has never produced a chapter under the new piece system? The chapter path must still produce the same-shape output it always did (same directory, same frontmatter keys), even though internally it goes through the generic piece flow.
- **Form name collision**: what if a user's world declares a form named "chapter" that overrides the built-in? The built-in chapter must never disappear silently; the override is allowed but the user is informed on invocation which form was used.
- **Missing length for a free-form ask**: what if a user invokes a form without specifying length and the form declares no default? The system picks the shape that is natural for the form (e.g. a haiku is short regardless); it does not fall back to the chapter length range.
- **Conflicting canon delta (optimistic mode)**: what if a piece's delta proposes a new character whose id is already in the bible with a different backstory? The delta is applied (optimistic), and a finding is recorded in the audit log for later resolution via `canon review`. Generation does not stall; the canon stays moving.
- **Malformed delta response from the language model**: what if the model's canon-delta section is missing, incomplete, or ill-structured? The piece content is still saved (no data loss), the delta record is saved as `empty` with a diagnostic note, and a warning plus an audit-log finding is surfaced so `canon review` can prompt the user to re-extract or hand-edit later.
- **Image form with no extractable text**: what if a producer for an image form has no associated text to extract canon from? The delta record is permitted to be empty; the piece is still recorded with a canon-version reference.
- **User explicitly wants zero canon impact**: what if a user produces a piece that should not feed the bible (e.g. a test/preview/throwaway)? The system offers a flag to generate a piece without recording a piece record at all (equivalent to a one-shot dry-run that still prints the content).
- **Revert of a piece whose canon delta has been superseded by a later piece**: what if the user reverts piece A, but piece B (produced later) already referenced the entity piece A introduced? Piece A's file stays on disk (marked `canon_status: reverted`), its delta rolls back, and the revert surfaces the downstream dependency as a secondary finding rather than silently orphaning piece B; the user decides whether to cascade-revert, re-attach (reinstate the delta), or accept the dangling reference.
- **Documentation drift**: the terminology pivot must leave no file in the repository that treats "chapter" as a synonym for "any generated unit of content."

## Requirements *(mandatory)*

### Functional Requirements

**Piece abstraction (P1):**

- **FR-001**: The system MUST represent every generated content artifact as a piece with at minimum: a stable identifier, a form name, a generated date, a canon-version reference, and its approximate measured length.
- **FR-002**: The system MUST continue to support the existing chapter-production command with no change to its output shape (filename, directory, frontmatter keys), so existing published worlds keep building.
- **FR-003**: The system MUST allow users to produce a piece in a form other than chapter via a generic "produce piece" entry point, with the form selected per invocation.
- **FR-004**: The system MUST allow users to specify a target length per piece invocation, and MUST NOT apply the world-wide chapter length range to pieces in other forms.
- **FR-005**: The system MUST remove or rename, in user-facing materials (top-level docs, CLI help text, prompt placeholder reference), any language that presents "chapter" as the sole or primary unit of generated content.
- **FR-006**: The system MUST preserve existing world content directories as they are; the chapter form MUST continue to write to the existing chapter directory, and non-chapter forms MUST write to a dedicated pieces area that does not collide with the chapter directory.
- **FR-007**: The system MUST record the form of each piece so that subsequent tooling (listings, reading order, search) can filter and group by form without parsing content.

**Open-ended form registry (P2):**

- **FR-008**: The system MUST ship a baseline of built-in forms covering at minimum: chapter, haiku, vignette, short-story, comic-script, portrait, social-post, illustration.
- **FR-009**: The system MUST allow a world to declare custom forms via file(s) in the world's data directory, without requiring any change to the installed gem or CLI.
- **FR-010**: Each form, built-in or custom, MUST declare: its name, its category (text / image / script), its default target length or shape, and its prompt template.
- **FR-011**: The system MUST auto-discover custom forms on each CLI invocation; users MUST NOT need to register or rebuild anything to pick up a newly added form.
- **FR-012**: The CLI MUST expose registered forms both via an explicit flag (`--form <name>`) and, when the name is unambiguous in that world, via a short subcommand (`produce <name>`).
- **FR-013**: When a world's custom form name collides with a built-in, the custom form MUST take precedence; the user MUST be informed which form was selected on that invocation.
- **FR-014**: The CLI MUST surface a clear error listing available forms when a user invokes an unregistered form name.
- **FR-015**: Form templates MUST be able to declare which canon slices they need in their context (e.g. "all characters," "recent events from current chapter," "none") without changing the engine.

**Universal canon-extraction contract (P3):**

- **FR-016**: Every piece producer, regardless of form or category, MUST emit a structured canon-delta record alongside the piece output. The delta record MAY be empty.
- **FR-017**: A canon-delta record MUST be able to express, at minimum: new characters, new locations, new facts, new events, new relationships, and updates to existing entities.
- **FR-018**: The system MUST support two canon-application modes per producer invocation: (a) auto-apply (default) — deltas are merged into canon eagerly as part of piece production, so the next piece already sees them; (b) dry-run — show the piece and the would-be deltas, write nothing. There is no "deferred / pending approval" mode; review happens retroactively (FR-028–FR-030).
- **FR-019**: In auto-apply mode, deltas MUST be applied transactionally — either all deltas in a record are applied or none are; partial state MUST NOT be written to the bible.
- **FR-020**: When a delta conflicts with existing canon (same entity id, different attribute values), the system MUST apply the delta (optimistic) and record the conflict as a finding in the world's canon-review audit log, referencing both the prior canon state and the piece that introduced the conflict. Generation MUST NOT stall on conflicts.
- **FR-021**: After deltas are applied, subsequent piece invocations MUST see the new canon entries in their assembled prompt context.
- **FR-022**: When the language model returns a malformed or missing delta record, the system MUST still save the piece content, record the delta as empty with a diagnostic note, warn the user, and open an audit-log finding so `canon review` can prompt for re-extraction or manual repair later — without crashing the producer or losing the generated text.
- **FR-023**: For image-form producers, the canon-delta record MUST be derivable from the generation prompt and user-supplied metadata; pixel analysis is out of scope.
- **FR-024**: Each piece record MUST cite the canon version it was produced against, and each applied delta MUST bump the canon version so lineage is traceable.

**Post-hoc canon review (P3, audit model):**

- **FR-028**: The system MUST provide a `canon review` operation that reads the world's audit log and presents its findings. MVP scope is **explicit findings only**: conflicts logged by FR-020, malformed-delta findings logged by FR-022, and orphaned-reference findings produced when a revert cascades (per the revert-supersession edge case). Semantic/heuristic detection (suspected hallucinations, divergence from established patterns, style drift, etc.) is NOT in MVP and is tracked under "Future Work / Deferred Review Capabilities." The review MUST be runnable on-demand from the CLI; a background/watch mode MAY be added as a follow-up.
- **FR-029**: For each finding, `canon review` MUST present: the originating piece, the canon state before and after the delta, a human-readable explanation of the suspected issue, and remediation options at minimum: (a) revert the piece — roll back its delta and mark the piece record `canon_status: reverted` while keeping the piece file on disk (non-destructive), with an optional follow-up to regenerate a replacement piece; (b) accept / leave as-is (mark the finding closed without changes); (c) patch canon manually (user edits the entity, and the finding closes when the conflict no longer exists). Additional user-directed actions MAY be offered. Revert MUST NOT delete the piece file.
- **FR-030**: The audit log MUST persist per-world in the world's data directory. Closed findings MUST remain queryable (who resolved, when, how) so past decisions are traceable. Open findings MUST survive across CLI invocations.

**Compatibility and non-disruption:**

- **FR-025**: No storage-schema change is permitted beyond adding piece records, canon-delta records, and canon-review audit-log entries; existing bible/canon primitives MUST be reused.
- **FR-026**: Running any pre-existing CLI workflow (world creation, chapter production, translation, publishing) on an existing world MUST succeed without migration.
- **FR-027**: The test suite MUST pass with mock-AI enabled and MUST cover at minimum: P1's chapter-path back-compat, P2's custom-form discovery, and P3's dry-run / auto-apply / canon-review flows including at least one conflict finding and one revert path.

### Key Entities *(include if feature involves data)*

- **World**: The IP canon container. Already exists (name, description, configuration, Story Bible, canon history). Not changed by this feature, but its "target chapters" and "chapter length target" fields are demoted from hard global constraints to advisory defaults applied only to the chapter form.
- **Piece**: A generated content artifact. Attributes: stable id, form name, category (text / image / script), generated date, approximate length/shape, canon version at production time, reference to its canon-delta record, `canon_status` (`applied` by default, `reverted` after a `canon review` revert), and content (inline text, or file path for image/script assets). Supersedes "chapter" as the general organizing unit; chapters become pieces whose form is "chapter." A piece with `canon_status: reverted` remains on disk and inspectable; its delta no longer contributes to canon.
- **Form**: The recipe for generating a piece. Attributes: name, category (text / image / script), default length/shape, prompt template, declared canon context requirements, optional ownership (built-in vs. world-local). Forms are discovered from the gem's defaults plus the current world's form-definition files.
- **Canon Delta**: The structured record of bible changes implied by a produced piece. Sections (any may be empty): new characters, new locations, new facts, new events, new relationships, entity updates. Associated with exactly one piece. Lifecycle: `proposed` (dry-run only; never persisted) → `applied` (default, after auto-apply writes succeed) → optionally `reverted` (rolled back via `canon review`). There is no "deferred" or "pending approval" state; audit-log findings against an applied delta are tracked separately on the Audit Finding entity.
- **Form Registry**: The runtime view of all forms available for a given world — built-ins plus world-local forms, with world-local winning on name collision. Rebuilt per CLI invocation; not persisted.
- **Audit Finding**: A post-hoc issue flagged against applied canon. Attributes: originating piece, finding kind (in MVP: `conflict` / `malformed-delta` / `orphaned-reference`; future kinds reserved, see Future Work), severity hint, prior canon snapshot reference, current canon snapshot reference, human-readable explanation, status (`open` / `closed`), resolution action taken (revert / accept / patch-canon / other), resolved-at timestamp. Persisted per-world in the audit log. In MVP, findings are created only at the explicit logging points (FR-020 conflicts, FR-022 malformed deltas, revert cascades); `canon review` itself does not synthesize new findings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

**P1 (terminology + unshackle length):**

- **SC-001**: A user producing a piece in a non-chapter form in any world can target a length outside the world's chapter length range (shorter or longer) and the produced piece's measured length falls within a reasonable tolerance of the requested target, not pulled back into the chapter range.
- **SC-002**: A user running the pre-existing chapter-production command on the existing storyworld in this repository gets output that is byte-identical in shape (filename pattern, frontmatter keys, directory) to pre-feature output.
- **SC-003**: A reader scanning the project's top-level documentation, CLI help, and prompt placeholder reference finds zero statements that frame the world as "a book" with numbered chapters as the sole unit of content.

**P2 (open-ended forms):**

- **SC-004**: A user can add a new form to their world and invoke it from the CLI within the same shell session without restarting anything or editing gem code.
- **SC-005**: A user can produce at least five distinct piece forms from a single world in a single afternoon without modifying any file outside that world's directory tree.
- **SC-006**: When a user invokes a form name that does not exist in any registry, they see, within the error output, the list of forms they could have invoked for that world — with no prior knowledge required.

**P3 (universal canon feedback + audit):**

- **SC-007**: Every producer, for every registered form, emits a canon-delta record on every invocation. Producers that emit no deltas emit an explicitly empty record; none produce no record at all.
- **SC-008**: A user running dry-run on any form sees both the piece content and the canon deltas in their terminal output before any file is written; no bible or canon files change in dry-run.
- **SC-009**: When a producer's output introduces a new character, a second piece produced afterward in the same world has that character available in its prompt context without the user doing anything between the two invocations.
- **SC-010**: When the language model returns malformed delta data, the piece content is still recoverable from disk after the run, the canon-delta record notes the malformation, and a finding is visible in `canon review` — zero cases of silent data loss.
- **SC-013**: When a piece introduces a delta that conflicts with prior canon, the user can discover the conflict by running `canon review` in the same world without knowing in advance which piece caused it, and can revert the originating piece in a single decision — with the revert reflected in subsequent canon state.

**Cross-cutting:**

- **SC-011**: The test suite passes in mock-AI mode with no behavioral regression on prior workflows (world creation, existing chapter production, translation, publishing).
- **SC-012**: After this feature, a new engineer reading the constitution and top-level docs can explain, without reading code, what a "piece," a "form," a "canon delta," and a "canon review finding" are, and the relationship among them.

## Future Work / Deferred Review Capabilities

`canon review` in MVP is deliberately thin — it reads the audit log, it doesn't think. The following are tracked here as explicit non-MVP work so they don't get forgotten when the review feature grows a brain. Each item, when taken up, becomes its own spec.

- **Orphaned-reference proactive scan**: walk every piece and verify all entity ids it references still exist in canon; open `orphaned-reference` findings for any that don't, without waiting for a revert to trigger them.
- **Duplicate-entity heuristic**: detect likely duplicates in canon (e.g. two characters with near-identical names or overlapping attribute signatures) and open `duplicate-entity-suspected` findings.
- **Schema / shape-drift detection**: flag entities whose attributes diverge from the declared shape for their kind (e.g. a character missing a field every other character carries).
- **Semantic divergence detection (LLM-assisted)**: another model pass compares a piece's narrative against current canon and flags contradictions or style/voice drift. Requires its own eval suite per Principle VI.
- **Hallucination detection (LLM-assisted)**: flag deltas whose entities appear to be fabrications rather than legitimate new canon (e.g. a character introduced by name only, no attributes, no grounding). Also eval-gated.
- **Background / watch mode**: run `canon review` automatically after each piece production (or on a schedule) rather than requiring explicit invocation.
- **Finding severity and filtering**: richer severity taxonomy, per-kind filters, and workflows for triaging large backlogs.
- **Cross-world review**: detect contradictions across sibling worlds that share lore (if/when multi-world lore reuse is introduced).

Adding any of these items requires a new kind value for Audit Finding; the MVP kind list is the reserved set and new kinds extend it rather than replace it.

## Assumptions

- **Arcs are out of scope**: ordering of pieces (reading order, arcs, books) is deferred. In P1, a piece of form `chapter` still carries a chapter number (as a property of that form); pieces of other forms carry no linear number. Arc-level grouping is a future feature.
- **Publishing is out of scope**: Jekyll theming, navigation, and site layout are untouched. If the Jekyll site needs to render new piece forms later, that is a downstream feature. For the `one-review-man` world, only chapter-form pieces need to be renderable for now, and the chapter path is unchanged.
- **Image-form canon extraction is text-driven**: the canon-delta record for an image piece is derived from the user's generation prompt and any explicit metadata they supplied; no pixel-level analysis is performed.
- **Length is a target, not a contract**: the system requests a target length from the model; the produced piece approximates it but is not padded or truncated mechanically. "Approximately" means within a reasonable tolerance for the form and the language model used.
- **Canon application is optimistic by default**: deltas are applied eagerly at piece-production time. Dry-run is the only opt-out. Correctness is enforced retroactively by `canon review`, not by gating each piece behind manual approval. This keeps generation friction low and makes consistency a safety net rather than a choke point.
- **Canon-review audit log is per-world**: findings live in the world's data directory so each world's review queue is independent. Open findings persist across CLI invocations; closed findings remain queryable for provenance.
- **`canon review` is idempotent and non-destructive by default**: running it never modifies canon; it only surfaces findings. Mutations happen only when the user picks a remediation action on a specific finding.
- **Custom form templates are per-world**: a form definition lives in the world's data directory and applies only to that world. There is no user-global or repository-global form catalog at this stage.
- **Canon version is the existing canon-version primitive**: this feature does not introduce a new versioning mechanism; it reuses the existing canon revision/snapshot system. Reverts go through that system, so a revert is just another canon transition.
- **No migration is required**: existing worlds keep working as-is. Chapter pieces continue to land in their current directory and carry their current frontmatter keys. Non-chapter pieces live under a separate area. Existing worlds start with an empty audit log and accrue findings only as new pieces are produced or `canon review` is run.
- **"Piece" is the chosen term**: `piece` is committed to as the user-facing name for the general unit, with `form` as the kind. Alternatives considered (entry, artifact, work, item) are not exposed in CLI, docs, or identifiers.
