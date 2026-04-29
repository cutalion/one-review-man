# Eidos Usage Guide

This guide walks you through every workflow Eidos supports, from "I have an idea for a storyworld" to "my world has been evolving for months and I want to translate, branch, and publish it." It is organized by what you're trying to do — pick a section by your goal, not by command name.

If you haven't read [the pitch](pitch.md) yet, start there. It's short. It tells you what Eidos *is*, who it's for, and (importantly) what it is *not*. Reading it first means the rest of this guide will feel less arbitrary.

This guide assumes you have Eidos installed — either as a gem (`gem install eidos`) or running from a checkout of the monorepo (`eidos/exe/eidos`). Wherever this guide says `eidos`, substitute the path that works in your setup.

## Contents

1. [Get oriented](#1-get-oriented) — the mental model, glossary, and the things Eidos deliberately doesn't do.
2. [Create your first world](#2-create-your-first-world) — scaffolding a world from scratch, interactively or non-interactively.
3. [Produce your first piece](#3-produce-your-first-piece) — picking a form, generating a piece, understanding what just happened to your world.
4. [Inspect what just happened](#4-inspect-what-just-happened) — reading piece metadata, canon-delta history, and the bible.
5. [Evolving your world](#5-evolving-your-world) — reviewing canon changes, branching to try a what-if, merging, rolling back.
6. [Translating your world](#6-translating-your-world) — producing other-language versions of your content with consistent terminology.
7. [Publishing as a website](#7-publishing-as-a-website) — building a static reading surface from your world.
8. [Power-user techniques](#8-power-user-techniques) — custom forms, model probing, the programmatic interface.
9. [Working offline or cheaply](#9-working-offline-or-cheaply) — using mock AI for iteration without API costs; the debug flag.
10. [Troubleshooting](#10-troubleshooting) — the most common failure modes and how to recover from each.

---

## 1. Get oriented

Before you run anything, it helps to know what Eidos thinks the unit of work is.

### The mental model

Everything Eidos does happens inside a **world**. A world is a directory on your filesystem that holds:

- A **canon** — the source of truth for your storyworld: characters, locations, facts, relationships, plot threads. Versioned, branchable, recoverable.
- **Pieces** — individual artifacts (a chapter, a vignette, a haiku, a comic script, an illustration, a social-media post). Pieces are the *output* of the world; the canon is the *world*.
- **Configuration** — a small set of YAML files that describe what the world is, who its target audience is, what AI models to use, and so on.

When you produce a piece, Eidos reads the canon, generates the piece, and writes back three things: the piece file itself, a **canon delta** (a record of any new entities, facts, or changes the piece introduced), and an updated bible — Eidos applies the delta to your bible immediately and the canon revision advances. Most produces are *clean* and need no further action from you.

If something goes wrong during application — a parse drop, a malformed delta, a missing reference — the canon system opens a **finding** in the audit log for your attention. You review findings via `eidos canon review`, then either *accept* one (close the audit record without further change) or *revert* it (roll the delta back). On a typical day with clean produces, the audit log is empty.

This loop — *generate piece → check for findings → only act if something flagged → next piece* — is the core rhythm of working with Eidos.

### Glossary

These are the terms used throughout the guide. Define each once, here, and use them consistently.

- **World** — your storyworld; a directory containing canon + pieces + configuration. Often the same thing as your IP at a moment in time.
- **Storyworld** — synonym for world; emphasizes the narrative dimension.
- **IP** (intellectual property) — synonym for world; emphasizes the long-term-asset dimension. Use whichever term feels natural; they refer to the same object.
- **Canon** — the world's authoritative state: every character, location, fact, relationship, and plot thread you have committed to. The story bible.
- **Piece** — a single derivative artifact you produce from the canon (e.g. one chapter, one vignette, one comic script).
- **Form** — the *kind* of piece. Built-in forms include `chapter`, `vignette`, `short-story`, `haiku`, `comic-script`, `portrait`, `social-post`, and `illustration`. You can register your own (see [§8](#8-power-user-techniques)).
- **Bible** — the structured representation of the canon, broken into characters, locations, facts, relationships, and plot threads. Browsable via `eidos bible …`.
- **Canon delta** — the record of changes a single piece introduced into the canon (new characters discovered, facts established, etc.). Stored under `data/canon_deltas/`.
- **Finding** — an audit-log entry that surfaces something exceptional during canon application. Findings are *not* opened on every produce — clean produces leave the audit log untouched. Findings are opened only when something needs your attention: `parse-drop` (the LLM emitted an entry in a malformed shape), `orphaned-reference` (a delta referenced an entity that doesn't exist), `malformed-delta` (a whole delta that didn't apply cleanly), or `conflict` (e.g. branch-merge conflicts). Every finding has a kind, an id, and an originating piece. `canon accept --finding=<id>` closes a finding (acknowledged); `canon revert --finding=<id>` undoes the delta the finding represents.
- **Snapshot** — a full point-in-time copy of the canon. Created on demand; useful as a savepoint before risky changes.
- **Branch** — an alternative line of canon evolution. Lets you explore "what if?" without disturbing the main world.
- **Glossary (of translations)** — an in-memory mapping of source-language character names to their established target-language renderings, rebuilt at every translation run by scanning the translated character files (`content/characters/<id>.<lang>.md`). Keeps multi-language content consistent without a separate file you have to maintain.

### What Eidos is *not*

Eidos is opinionated about what it doesn't do. The list below is identical in spirit to the [pitch's non-goals](pitch.md#what-eidos-is-not) — if you read that, you can skim. If you didn't, here it is again, slightly expanded:

- **Not a one-shot book generator.** You don't say "write me a novel" and walk away. You produce pieces, accept them into canon, iterate.
- **Not a chapter-only tool.** A chapter is one form among many. Many storyworlds will produce far more vignettes, comics, or social posts than chapters.
- **Not a replacement for human editing.** Treat output as raw material. The voice, the polish, the hard cuts — yours.
- **Not opinionated about your world.** Eidos doesn't know whether you're writing fantasy, comedy, horror, slice-of-life. It's a substrate for whichever world you build.
- **Not a publishing platform.** It can build a static site from your content (see [§7](#7-publishing-as-a-website)), but distribution to readers — a personal site, a newsletter, social, print — is downstream.

### Two ways to invoke Eidos

If you installed the gem (`gem install eidos`), the unified command is `eidos`. If you're working from a checkout of the monorepo, run `eidos/exe/eidos` instead. There are also per-domain shims under `eidos/bin/` (e.g. `eidos/bin/world`, `eidos/bin/produce`) that are equivalent to the corresponding `eidos <subcommand>` invocation. Use whichever you prefer; the rest of this guide says `eidos` and assumes one of these is on your `PATH` or you've substituted the appropriate path.


## 2. Create your first world

A world is just a directory. Eidos scaffolds it for you, populates it with the right YAML files, and leaves you with something the rest of the commands can drive.

> **A note on placeholders.** Throughout this guide we write `worlds/<your-world>` for the path of the world you scaffolded, `<character-id>` for a character slug from your bible, `<finding-id>` for a canon-review finding id, and so on. Substitute your own values. If you copy-paste an example below that uses `--title "Job Hunt"`, the resulting world will be at `worlds/job-hunt` and `<your-world>` is `job-hunt` in your shell.

### Set your API key first

Eidos calls out to an AI provider when generating pieces. The default scaffold uses **OpenRouter** with `google/gemini-3-flash-preview`. Set your key in the environment before running any generation:

```bash
export OPENROUTER_API_KEY=sk-or-v1-...
```

If you'd rather use a different provider (OpenAI, Anthropic, a local model), edit `data/settings.yml` after scaffolding to point at the right one and set the corresponding key (`OPENAI_API_KEY`, etc. — see the `providers:` section of `data/settings.yml` for the env-var name each provider expects).

If you skip this step, scaffolding will still work — but the moment you try to produce a piece, Eidos will tell you the key is missing. (It will not silently substitute mock output. See [§9](#9-working-offline-or-cheaply) if you want to iterate without spending tokens.)

### The interactive scaffold

The simplest way to start a new world:

```bash
eidos world new
```

You'll be asked, in this order:

1. **Title** — what your storyworld is called. Free text. ("Job Hunt", "One Review Man", "The Salt Marsh".)
2. **Author** — your name, used in metadata.
3. **Description / premise** — a one-paragraph statement of what the world is about. This drives the AI's framing on every piece you produce, so write it as if it were the elevator pitch on the back of a paperback.
4. **Languages** — which languages your world will eventually have content in. Always include English. Add others (e.g. `ru`, `es`) if you intend to translate.
5. **Default language** — usually `en`.
6. **Genre / style / setting / theme** — short phrases. Eidos uses them to keep produced pieces tonally consistent. Leave any of them blank and Eidos writes the literal value `unspecified` rather than guessing — see the note at the end of this section.

When the prompt finishes, Eidos creates a directory at `worlds/<slug-of-title>/` (or wherever you tell it to, with `-w`) containing:

- `data/world_config.yml` — the answers above, structured.
- `data/world_state.yml` — runtime state (current canon revision, etc.).
- `data/story_bible/` — empty bible storage. `characters/` and `locations/` are directories that hold one YAML file per entity once your bible is populated; `facts.yml`, `relationships.yml`, and `plot_threads.yml` are flat files that start empty.
- `data/strings.yml` — boilerplate prompt strings derived from your premise.
- `data/settings.yml` — AI provider and model settings. Defaults to OpenRouter using `google/gemini-3-flash-preview`. Edit if you want a different provider or model.
- `content/` — an empty parent directory. Subfolders (`chapters/`, `pieces/<form>/`) are created on demand the first time you produce a piece of the relevant form; an empty fresh world has no subfolders here.

### The non-interactive scaffold

If you don't want to be prompted (useful in scripts, demos, or just when you know what you want):

```bash
eidos world new --quick \
  --title "Job Hunt" \
  --author "Alex G" \
  --premise "A 40-year-old programmer hunting jobs during the AI revolution. Deadpan workplace comedy." \
  --languages en,ru
```

The same files are created. Any field you don't supply is set to the literal string `unspecified` — Eidos refuses to make up plausible-sounding defaults, so you can always tell at a glance what was intentional and what you skipped. (See `eidos world help` for the full flag list.)

### Where do worlds live?

By default, in `worlds/<slug>/` relative to your current directory. To put it somewhere else, pass `-w <path>` on the `world new` command (e.g. `-w ~/storyworlds/<your-world>`). Almost every other Eidos command also takes `-w <path>` — if you cd into the world directory, the flag becomes optional because Eidos will discover the world by walking up from your current directory.

### Confirm the scaffold

```bash
eidos world status -w worlds/<your-world>
```

Output shows the title, author, a count of pieces by form (none yet for a fresh world), and any configuration fields still set to `unspecified` (so you can fill them in later). If `world status` runs cleanly, the world is ready.

### What state are you in?

After running `world new`, your world has:

- Configuration set, premise captured.
- An empty bible (no characters, locations, or facts yet — they'll appear as you produce pieces; each piece's canon delta applies to the bible at produce time).
- An empty `content/` tree (no pieces yet).
- Canon revision `0`.

The bible being empty is not a bug — Eidos doesn't seed plausible-looking entities for you. The first piece you produce is what populates it. Move on to [§3](#3-produce-your-first-piece).


## 3. Produce your first piece

A piece is one artifact: one chapter, one vignette, one haiku, one comic script. You pick a form, give Eidos a one-line prompt, and it produces the piece using your world's canon as context.

### See which forms are available

```bash
eidos produce piece --help -w worlds/<your-world>
```

Scroll past the flag list to the "Forms registered in this world" section at the bottom. That's the authoritative list of forms your world will accept under `--form`.

Built-in forms:

- `chapter` — a long-form prose chapter. Has its own structured generation flow with title, summary, and frontmatter.
- `vignette` — a short scene, typically 200–600 words.
- `short-story` — a complete self-contained story, longer than a vignette.
- `haiku` — three lines, 5-7-5.
- `comic-script` — panel-by-panel script with dialogue and stage directions.
- `portrait` — a character illustration prompt.
- `social-post` — a short social-media post in your world's voice.
- `illustration` — a generic illustration prompt for arbitrary subjects.

Each form has a sensible default length and shape. You can override the length per invocation; you can also register your own custom forms (see [§8](#8-power-user-techniques)).

### Produce one

The general shape of the produce command:

```bash
eidos produce piece --form <form> --prompt "<one-line idea>" -w <world>
```

A concrete example, using the world from [§2](#2-create-your-first-world):

```bash
eidos produce piece --form vignette \
  --prompt "Arthur reviews his own forgotten commit from three years ago and is appalled" \
  -w worlds/<your-world>
```

Eidos reads your world's canon, builds the prompt from your premise + any existing bible entries, calls the AI, and writes the result. A successful run prints `Generated <form> piece: <id>`. Use that id with `eidos piece show <id>` (covered in [§4](#4-inspect-what-just-happened)) to see the file path and other metadata.

For chapters specifically — which have a richer frontmatter structure — you can use the chapter-specific shortcut:

```bash
eidos produce chapter -w worlds/<your-world> --auto
```

`--auto` tells Eidos to pick the next chapter number automatically.

### What just happened to your world

After a successful produce, your world has gained:

- A new piece file at `content/pieces/<form>/<id>.md` (or `content/chapters/NNN-chapter.md` for chapters). It has YAML frontmatter — `id`, `form`, `generated_date`, `canon_delta_ref`, plus form-specific fields like `title` and `summary` for chapters — followed by the body.
- A new canon delta at `data/canon_deltas/<id>.yml`. This file records every entity, fact, or change the piece introduced — and Eidos has already applied those changes to your bible. The canon revision number advances at the same time.
- *If* something went wrong during application (a parse drop, a malformed entry, an orphaned reference), an open **finding** in the audit log waiting for your review. Most produces are clean and write no finding — the audit log stays empty. See [§4](#4-inspect-what-just-happened) and [§5](#5-evolving-your-world) for what to do when a finding does appear.

The piece's `canon_delta_ref` field links to the delta file — you can always trace a piece back to the changes it made.

### Override the length

If a form's default length isn't what you want, pass `--length <words>` (for text forms) or the appropriate shape flag for image forms:

```bash
eidos produce piece --form vignette --length 400 \
  --prompt "Arthur's first day at the new job" \
  -w worlds/<your-world>
```

### Dry run

If you want to preview what `produce` would generate without writing it to disk:

```bash
eidos produce piece --form chapter --dry-run --prompt "Act 3 opener" -w worlds/<your-world>
```

Eidos generates the piece body and prints it to stdout, but no piece file or canon delta is written, and the bible isn't updated. Useful for previewing output before committing it. (To inspect the *prompt* Eidos sends to the AI — not the response — use `--debug` instead; see [§9](#9-working-offline-or-cheaply).)

### What if the API key isn't set?

Eidos halts and tells you. It does not fall back to mock output silently. If you intentionally want mock output, see [§9](#9-working-offline-or-cheaply).


## 4. Inspect what just happened

Producing a piece changed three things on disk: a piece file, a canon delta, and your bible (Eidos applied the delta immediately). If anything went wrong during application, the audit log holds an open finding — but most of the time it's empty. This section walks through reading each.

### See all pieces

```bash
eidos piece list -w worlds/<your-world>
```

Lists every piece across every form, with id, form, generated date, and a one-line summary. Filter to a single form:

```bash
eidos piece list --form vignette -w worlds/<your-world>
```

### Read one piece

```bash
eidos piece show VIGNETTE001 -w worlds/<your-world>
```

Replace `VIGNETTE001` with whatever id `produce` printed. Output is a metadata summary — id, form, category, canon status, canon version, generated date, length, and the file path. To see the actual frontmatter (including `canon_delta_ref`) and body, open the file at the printed path with your editor.

### Check for findings

The piece you just produced almost certainly introduced something new — a character, a location, or a fact that wasn't in your bible before. Eidos applied those entries to your bible at produce time. If everything applied cleanly, there's nothing more to do. If something went wrong (the LLM emitted a malformed entry, a delta couldn't be parsed, a reference is orphaned), the canon system opens a **finding** for your attention.

To see all open findings:

```bash
eidos canon review -w worlds/<your-world>
```

Most of the time, output is `0 findings.` — clean produces don't surface anything, and that's the success case. When findings *do* appear, they fall into one of these kinds: `parse-drop` (the LLM emitted an entry in a malformed shape that Eidos dropped from the delta), `orphaned-reference` (a delta referenced an entity that doesn't exist), `malformed-delta` (a whole delta that didn't apply cleanly), or `conflict` (e.g. a branch-merge conflict). Each finding has an id, a kind, the originating piece, and a summary.

If a finding is informational and needs no action (the dropped entry was OK to lose), close it:

```bash
eidos canon accept --finding=<finding-id> -w worlds/<your-world>
```

Use `--note="..."` to attach a reason. Accept doesn't change anything — it just marks the finding as reviewed.

If a finding represents a delta that should be rolled back (the AI hallucinated a character, a fact contradicts your intent), revert it:

```bash
eidos canon revert --finding=<finding-id> -w worlds/<your-world>
```

Revert *does* change the bible — it rolls back the delta the piece tried to apply. See [§5](#5-evolving-your-world) for the full canon-management flow, including how to undo a clean apply (no finding) via per-entity rollback.

### Browse the bible

Your bible has content from every produced piece (canon deltas applied at produce time). Browse it by entity type:

```bash
eidos bible list characters -w worlds/<your-world>
```

Replace `characters` with `locations`, `facts`, `relationships`, or `plot_threads` to list other entity types.

To see one entity in detail, pass a `<type>/<id>` path:

```bash
eidos bible show characters/<character-id> -w worlds/<your-world>
```

Search across the whole bible:

```bash
eidos bible search "review" -w worlds/<your-world>
```

Search is full-text; matches are returned with a snippet of context per hit.

### What state are you in now?

After a clean produce (no finding):

- The piece file is in place — under `content/pieces/<form>/<id>.md` for non-chapter forms, or `content/chapters/NNN-chapter.md` for chapters.
- The canon-delta file is recorded under `data/canon_deltas/<id>.yml` with its `applied_at` timestamp.
- The bible (under `data/story_bible/`) reflects the current canon, including the delta's entries.
- The canon revision number advanced.
- The audit log is unchanged.

If a finding *was* opened and you've accepted or reverted it, add: the audit-log entry is closed, and (if you reverted) the bible has rolled back the delta's entries.

`eidos world status -w worlds/<your-world>` will show the current title, author, and a summary of pieces by form. (To see canon revision history directly, use `eidos canon history` — see [§5](#5-evolving-your-world).)


## 5. Evolving your world

This is where Eidos earns its keep. Producing one piece is easy in any tool. Producing thirty pieces over six months while keeping a world coherent — renaming characters, retiring locations, exploring what-ifs, rolling back regretful choices — is what Eidos is built for.

This section assumes you have a world with at least one piece and a populated canon.

### Reviewing canon changes

Most produces apply cleanly: the bible gets new entries, the canon revision advances, no further action needed. But sometimes something goes wrong — the LLM emits malformed output, a delta references something that doesn't exist, a branch-merge surfaces a conflict. Those exceptional conditions become **findings** in the audit log, and you review them via:

```bash
eidos canon review -w worlds/<your-world>
```

Output lists open findings: `parse-drop`, `orphaned-reference`, `malformed-delta`, and `conflict` entries. Each has an id, a kind, the originating piece, and a summary. Filter to a specific kind with `--kind=<kind>` or to a piece with `--piece=<piece-id>`. If output is `0 findings.`, you have nothing to review — that's the most common state.

To close a finding you've reviewed and accepted as-is:

```bash
eidos canon accept --finding=<finding-id> -w worlds/<your-world>
```

Attach a note explaining your decision with `--note="..."`. Accept closes the audit record without changing the bible (the bible was already updated at produce time, possibly with the malformed entry omitted).

### Reverting a delta tied to a finding

If a finding represents a delta you don't want in the canon (e.g. the AI hallucinated a character, a fact is wrong):

```bash
eidos canon revert --finding=<finding-id> -w worlds/<your-world>
```

This rolls the delta back — the bible is updated to remove the entries it added. Pass `--also-regenerate` to kick off a replacement produce call after the revert. Pass `--dry-run` to preview the revert without touching disk.

**What about clean produces?** If a piece applied cleanly, there's no finding to revert. To undo a clean apply, use the per-entity rollback described next, or delete the piece file and re-produce after editing your premise.

### Rolling back an entity to an earlier revision

To rewind one specific entity to a prior canon revision (for example, restoring a character to how they appeared three revisions ago):

```bash
eidos canon rollback characters <character-id> 12 \
  --reason "drifted away from intended characterization" \
  -w worlds/<your-world>
```

The arguments are `<entity-type>`, `<entity-id>`, and `<target-revision-number>`. Pass `--auto` to skip the confirmation prompt.

### Branching to explore an alternative

Suppose you want to try a what-if — "what if my protagonist had taken the corporate job instead of going freelance?" — without disturbing your main canon.

```bash
eidos canon branch create corporate-timeline -w worlds/<your-world>
```

This creates a new branch named `corporate-timeline`. To switch your active branch context:

```bash
eidos canon branch checkout corporate-timeline -w worlds/<your-world>
```

Any pieces you produce, findings you accept, and changes you make while checked out happen on this branch and don't affect the main branch.

To list all branches:

```bash
eidos canon branch list -w worlds/<your-world>
```

To switch back to the main branch:

```bash
eidos canon branch checkout main -w worlds/<your-world>
```

### Comparing branches

```bash
eidos canon branch compare main corporate-timeline -w worlds/<your-world>
```

Output shows the entities, facts, and relationships that differ between the two branches.

### Merging a branch

If you decide the experimental branch is worth keeping:

```bash
eidos canon branch merge corporate-timeline main -w worlds/<your-world>
```

This brings the source branch's (`corporate-timeline`) accepted findings into the target branch (`main`). Conflicts (e.g. both branches modified the same character entry differently) are surfaced for your review — Eidos refuses to merge silently when divergence exists.

If you decide the experimental branch is *not* worth keeping, archive or delete it:

```bash
eidos canon branch archive corporate-timeline -w worlds/<your-world>
# or, to remove permanently:
eidos canon branch delete corporate-timeline -w worlds/<your-world>
```

### Snapshots — savepoints before risky changes

Before doing something you might want to undo *en masse*, take a named snapshot:

```bash
eidos canon snapshot create before-act-3 -w worlds/<your-world>
```

A snapshot is a full point-in-time copy of the canon. List them:

```bash
eidos canon snapshot list -w worlds/<your-world>
```

Inspect a snapshot's metadata:

```bash
eidos canon snapshot show before-act-3 -w worlds/<your-world>
```

Snapshots and branches serve different purposes: a **branch** is for *exploring* an alternative line of evolution; a **snapshot** is for *protecting* the current state as a labeled reference.

### What state are you in after these operations?

After accepting / reverting / rolling back / branching / merging:

- `eidos bible list` reflects the new state of the canon.
- `eidos canon history <entity-type> <entity-id>` shows the per-entity revision trail, including any rollbacks or reverts you applied.
- `eidos canon branch list` shows your current branch context (the active branch is marked).
- The pieces under `content/` are unchanged — they're historical artifacts of what the world looked like when they were produced. Their `canon_delta_ref` fields still point to the deltas that produced them, even if those deltas have been reverted.

This is intentional: pieces are immutable records. The canon is what evolves.


## 6. Translating your world

Translation in Eidos is a first-class operation: not a one-shot prompt to an LLM, but a managed process that builds and reuses a glossary so character names, location names, and stylistic choices stay consistent across every translated piece.

### Set up languages

You declared which languages your world supports when you ran `eidos world new` (or you can edit `data/world_config.yml` to add more later). Translation only works for languages listed there.

### Translate one chapter

```bash
eidos translate chapter 1 ru -w worlds/<your-world>
```

This translates chapter 1 from the world's default language (typically English) into Russian. The translated file is written alongside the original under `content/chapters/`, with a language suffix (e.g. `001-chapter.ru.md`).

### Translate a character

```bash
eidos translate character <character-id> ru -w worlds/<your-world>
```

This produces a translated character entry that the published site or a localized reader can consume.

### Translate everything

```bash
eidos translate all ru -w worlds/<your-world>
```

This translates every untranslated chapter and character in the world into Russian, in order. It can be slow (one AI call per item) and will burn tokens — start with one chapter to verify the result before running it across the whole world.

### How the glossary works

Eidos doesn't keep a separate glossary file. Before each translation it scans your already-translated character entries (under `content/characters/<id>.<lang>.md`) and builds an in-memory map of source-language names to their established target-language renderings. That map is supplied to the LLM as constraint context: "Use this name for that character; preserve these conventions."

This means: once a character has been translated — for example, "Arthur" rendered as "Артур" in `content/characters/arthur.ru.md` — every later translation will use "Артур" for "Arthur." No drift across volumes.

To lock or change a name, **edit the translated character file directly**. The next translation that runs will read the updated rendering and propagate it.

### Debug a drifting translation

If a translation came out wrong — wrong tone, an established term mistranslated, or the translation drifted away from the source — turn on debug:

```bash
eidos translate chapter 1 ru --debug -w worlds/<your-world>
```

This writes the prompt and response to `tmp/ai_debug/`. Read the prompt: did Eidos send the right name mappings (drawn from your translated character files)? Did the response respect them?

If a particular character name is consistently mistranslated, edit the corresponding `content/characters/<id>.ru.md` file to lock the right rendering, then re-run:

```bash
eidos translate chapter 1 ru -w worlds/<your-world>
```

### Re-translate after editing source

If you edited the original (English) chapter and want the Russian version regenerated, the simplest path today is to delete the existing translated file and run `translate chapter` again. Eidos will write a fresh translation using the up-to-date glossary.




## 7. Publishing as a website

Eidos can build a static reading surface — a Jekyll site — from your world's content. This is one possible distribution channel, not the only one. Once you have the site directory, you serve it however you like (a personal site, GitHub Pages, Netlify, a self-hosted server). Eidos does not host or distribute for you.

### Build the site

```bash
eidos publish jekyll -w worlds/<your-world> --dest site
```

This reads your world's pieces (chapters, vignettes, comics, illustrations — all forms that have a published representation), renders them through Jekyll templates, and writes the result to `site/`. The output is a self-contained Jekyll source tree, not the final HTML — running `bundle exec jekyll build` in `site/` produces the actual HTML.

### Serve it locally

```bash
cd site
bundle exec jekyll serve
```

Open `http://localhost:4000` and you have a browsable version of your world. Chapters, character pages, and (if you've translated content) language switchers all render automatically from the same content tree.

### Iterate

Re-run the publish step any time you want the site to reflect newly produced or accepted content:

```bash
eidos publish jekyll -w worlds/<your-world> --dest site
```

Jekyll's serve mode auto-rebuilds when files in `site/` change, so you'll see updates without needing to restart the server.

### What the site contains

By default, the Jekyll output includes:

- An index page listing your world's content — chapters, vignettes, comics, or whichever forms your world has produced.
- A page per chapter with the body content.
- Character index + per-character pages drawn from the bible.
- A language switcher if your world has translations.
- A simple stylesheet and layout — meant to be customized.

To customize the look, edit the templates in `site/_layouts/` and `site/_includes/`. Those files are part of the Jekyll source tree Eidos generates; they're yours to modify.

### What the site is *not*

The site is a static reading surface, not a content management system. You don't author content there — you author content via `eidos produce …`. The site is downstream output. If you want to edit a chapter, edit the source under `content/chapters/` (or regenerate it via produce) and re-publish.

### What state are you in after publishing?

- The `site/` directory contains a Jekyll source tree mirroring your world's content.
- The `worlds/<world>/` directory is unchanged — publishing is read-only against your world.
- Each rebuild is idempotent: running publish twice in a row produces the same output (modulo timestamps).

If you intend to deploy the site, run `bundle exec jekyll build` and ship the resulting `_site/` to your host of choice.


## 8. Power-user techniques

This section covers the things you don't need on day one but will reach for as your world grows: registering your own forms, comparing AI models, and driving Eidos programmatically from Ruby.

### Adding a custom form

The built-in forms cover most kinds of derivative content, but you can register your own. A custom form lives at `worlds/<world>/data/forms/<name>.yml` and looks like this:

```yaml
name: tweet
category: text
default_length: 280
canon_context:
  - all_characters
  - recent_events
prompt_template_path: ./tweet.prompt.txt
```

Alongside it, create the prompt template at `worlds/<world>/data/forms/tweet.prompt.txt`:

```
Write a single tweet (max 280 characters) in the voice of the world.
Subject: {USER_PROMPT}
Relevant canon: {CANON_CONTEXT}
```

Required fields:

- `name` — what users will pass to `--form`. Lowercase, hyphenated.
- `category` — `text`, `image`, or `script`. Determines which adapter Eidos uses.
- `default_length` (or `default_shape` for image forms) — the form's natural size.
- `canon_context` — which parts of the bible to inject into the prompt by default. A list, drawn from this exact enum: `all_characters`, `all_locations`, `recent_events`, `current_chapter`, `none`. Use `none` for forms that don't need any canon context. Other values (e.g. plain `characters` or `facts`) are not recognized and the form will be silently skipped at registration with a warning on stderr.
- `prompt_template_path` — relative path (from the form's YAML file) to a text file containing the prompt template. Placeholders (e.g. `{USER_PROMPT}`, `{CANON_CONTEXT}`, `{WORLD_PREMISE}`) are filled at generation time. Templates that reference an unfilled placeholder cause a generation failure rather than a silent leak.

Once the file exists, the form is registered next time you run any `eidos produce` command in that world. Confirm:

```bash
eidos produce piece --help -w worlds/<your-world>
```

The new form appears under "Forms registered in this world" at the bottom of the output. Produce one:

```bash
eidos produce piece --form tweet --prompt "Arthur posts about his interview" -w worlds/<your-world>
```

The piece is written under `content/pieces/tweet/<id>.md` with the same frontmatter shape as built-in forms.

### Trying a different model with `eidos probe`

`probe` is a cheap-as-possible smoke test for an LLM provider/model. It does NOT mutate your world; it does one tiny round-trip and reports auth, reachability, and latency.

```bash
eidos probe gpt-4o-mini
```

Output: provider, model, response time, response excerpt. Use it before switching models in `data/settings.yml` so you don't discover a typo or auth issue mid-generation.

To compare two models on the same prompt:

```bash
eidos probe gpt-4o-mini --prompt "Write a haiku about code review." > a.txt
eidos probe gpt-5-turbo --prompt "Write a haiku about code review." > b.txt
diff a.txt b.txt
```

`probe` accepts `--provider` (e.g. `openrouter`), `--api-key`, `--base-url`, `--timeout`, `--metrics` (prints token counts and timing), `--json` (machine-readable output), `--prompt`, and `--max-tokens`. Used together, you can side-by-side any two reachable models without touching your world's `settings.yml`.

### Using Eidos from Ruby

> This subsection assumes you're comfortable with Ruby. If you're not, you don't need to read it — every workflow above is achievable through the CLI. The SDK is for embedding Eidos in another Ruby application (e.g. a Rails admin panel for your storyworld).

Eidos ships with a public Ruby SDK that wraps the same engine the CLI drives. Object-oriented, immediate-persistence, convention-over-configuration.

```ruby
require 'eidos'

Eidos.configure { |c| c.worlds_path = 'worlds' }

world = Eidos::World.new('job-hunt')
world.status                     # equivalent to `eidos world status`

# Browse the bible
world.bible.characters.count
world.bible.characters.find { |c| c.name == 'Arthur' }

# Read pieces
world.chapters.count
world.chapters.first.title

# Mutations persist immediately
character = world.bible.characters.first
character.update({ archetype: 'reluctant protagonist' }, reason: 'tightened framing')
# The change is on disk now; no save() call needed.

# Canon
world.canon.current_branch
world.canon.snapshots.map(&:label)
world.canon.history(limit: 10)
```

Every mutation through the SDK takes the same path the CLI takes — the same canon-delta machinery, the same finding-review flow if you trigger one programmatically. Use the SDK when you want Eidos as a library; use the CLI when you want it as a tool.


## 9. Working offline or cheaply

Calling AI providers costs money. While iterating on your premise, your prompts, or your form configurations, you may want Eidos to use canned mock responses instead.

### Mock mode

Set the environment variable `MOCK_AI=true` before any command:

```bash
MOCK_AI=true eidos produce piece --form vignette \
  --prompt "Arthur reviews his own forgotten commit" \
  -w worlds/<your-world>
```

In mock mode, Eidos never calls the AI. It returns deterministic placeholder content read from the gem's bundled mock-responses fixture. This is exactly the same mode the test suite runs in, so it's reliable — but the output is *generic*, not tailored to your prompt or your world.

### When to prefer mock mode

- Iterating on your `world_config.yml` (genre, style, theme) and wanting to see whether the scaffolding pipeline still works.
- Practicing the canon-review / accept workflow — mock pieces still produce canon deltas, so you can rehearse the loop without spending tokens.
- Running the full produce → review → accept flow inside a CI or smoke-test script.
- Debugging a Thor command or a config-loading issue where you don't actually need the AI's output to be good.

### When mock mode is *not* enough

- Anything that depends on the LLM understanding your premise — judging tone, generating in your world's voice, deriving canon-relevant entities. Mock output is intentionally generic.
- Verifying that a translation produces sensible target-language prose.
- Checking that a custom form yields output of the right length and shape.
- Cost-estimation runs (mock mode reports zero tokens because no call is made).

For any of those, you need the real LLM with your `OPENAI_API_KEY` set.

### Verbose debug output

If something is going wrong and you want to see what Eidos is sending to the AI and what's coming back:

```bash
DEBUG_AI=1 eidos produce piece --form vignette --prompt "..." -w worlds/<your-world>
```

Or use the explicit flag:

```bash
eidos produce piece --debug --form vignette --prompt "..." -w worlds/<your-world>
```

Both routes write the full prompt and response to `tmp/ai_debug/`. Useful when a piece comes back wrong and you want to see whether the prompt was the problem (your premise drift, your strings.yml, your form config) or the response was the problem (model hallucinated, length cap, etc.).

`tmp/ai_debug/` is gitignored. Don't commit its contents — they may include API responses with quoted material from your prompts.

### Combining the two

You can stack `MOCK_AI=true` with `--debug` to see the *prompts* without making any real call. This is the cheapest way to iterate on a prompt template:

```bash
MOCK_AI=true eidos produce piece --form vignette --debug \
  --prompt "Arthur's first day at the new job" -w worlds/<your-world>
```


## 10. Troubleshooting

The most common things that go wrong on first contact, and how to fix each.

### "API key not set" / authentication errors

**Symptom**: Producing a piece halts with a message about missing `OPENAI_API_KEY` (or whichever provider).

**Fix**: Set the environment variable before running. For one shell session:

```bash
export OPENAI_API_KEY=sk-...
```

For permanence, add it to your shell rc file. If you're using a different provider (Anthropic, OpenRouter, a local model), edit `worlds/<world>/data/settings.yml` to point at the right provider, and set the corresponding env var.

### "World not found" / world directory not detected

**Symptom**: A command errors out saying it can't find a world.

**Fix**: Either pass `-w <path>` explicitly, or `cd` into the world directory (Eidos walks up from your current directory looking for `data/world_config.yml`). If you're in a parent of `worlds/`, you need `-w worlds/<name>`.

### Output looks generic, like a stock template

**Symptom**: A produced piece reads like the AI didn't really know about your world — generic prose, no character names, no premise echo.

**Possible causes**:
- You're in `MOCK_AI=true` mode without realizing it (mock output is intentionally generic). Run `echo $MOCK_AI` to check.
- Your `world_config.yml` has fields set to literal `unspecified` (genre, style, theme). Eidos uses those values verbatim in prompts; "unspecified" is a literal string, not an inference cue. Edit the file and re-run.
- Your bible is empty. The first piece into a fresh world has nothing to reference; subsequent pieces, after you accept their findings, will be richer.

### Canon-delta finding looks wrong

**Symptom**: `eidos canon review` shows a finding that mentions a character or fact you don't recognize, or one that contradicts your world.

**Fix**: Don't accept it. Either revert the underlying piece (delete it) and regenerate with a tighter prompt, or accept the finding and edit the bible directly to reshape the entry. If the same kind of malformed finding appears repeatedly, run with `--debug` and inspect the prompt — the model may be losing context.

### Translation drifted from established terminology

**Symptom**: A character's name is rendered differently across translated chapters, or an established term is mistranslated.

**Fix**: There's no separate glossary file — name mappings are read out of your translated character files (`content/characters/<id>.<lang>.md`) on every run. To lock a translation, edit the relevant translated character file to use the rendering you want, then re-run translation for the affected pieces. The next run will pick up the change.

### Piece file exists but `piece show` errors

**Symptom**: You can see the file under `content/pieces/<form>/`, but `eidos piece show <id>` says the piece doesn't exist.

**Likely cause**: The piece's frontmatter `id` doesn't match the filename slug, or the `canon_delta_ref` points to a missing delta file. Run `eidos canon review` to see if any `malformed-delta` findings are present — those usually correlate.

**Fix**: Check the frontmatter id matches what `piece list` reports. If a delta is missing, the piece is orphaned — easiest path is to delete the piece file and regenerate.

### Jekyll site won't build

**Symptom**: After `eidos publish jekyll`, running `bundle exec jekyll serve` in `site/` fails.

**Likely cause**: Missing Jekyll dependencies. Run `bundle install` from inside `site/` before serving.

### "tmp/ai_debug/" is filling up disk

**Fix**: It's gitignored, so it's safe to delete: `rm -rf tmp/ai_debug/*`. The directory rebuilds on the next `--debug` run. If you want to keep audit history, copy out the runs you care about first.

### A finding references something that no longer exists

**Symptom**: `eidos canon review` shows an `orphaned-reference` finding.

**Cause**: A previous revert or rollback removed an entity that a later piece referenced.

**Fix**: Either accept the finding (which formally records the orphan) or revert the dependent piece and regenerate. The canon system won't silently paper over the gap.

