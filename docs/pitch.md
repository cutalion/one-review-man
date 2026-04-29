# Eidos

A toolkit for creators who are building a *world* — not a single book, comic, or campaign, but an evolving fictional universe with its own canon, characters, locations, and lore — that they want to keep coherent as they generate many pieces of content from it over time.

## What Eidos is

Eidos is an engine for creating and evolving an intellectual property (IP) — a storyworld with versioned canon — and producing pieces of derivative content (chapters, vignettes, comics, haikus, illustrations, social posts, and more) that stay consistent with that canon as it grows.

## Who Eidos is for

Eidos is for the **creator of a fictional world** — a writer, comic author, narrative designer, or IP owner who wants to build something larger than a single artifact. You're not trying to ship one finished novel; you're trying to grow a universe.

If you have an idea for a world — a setting, a cast, a tone, a few core conflicts — and you want to explore it by producing many small pieces of content over weeks or months, Eidos is for you. If you want one large finished work and never come back to it, Eidos is overkill.

## How to think about Eidos

Eidos has four core ideas. They're worth understanding before you do anything else.

**A world** is your storyworld — an IP, a fictional universe, a setting plus its rules. Everything Eidos does happens *inside* a world.

**A piece** is a single artifact you produce from a world: one chapter, one vignette, one haiku, one comic page, one illustration, one social-media post. Pieces come in many *forms*; Eidos ships a default set, and you can register your own. Pieces are not the *unit* of the world — the unit of the world is the world. Pieces are the *output* of the world at a moment in time.

**The canon** is the world's source of truth: characters, locations, facts, relationships, plot threads, reference images, style notes. The canon is *versioned*, like source code. Every piece you produce records exactly which canon version it was built from. If you change a character's name in the canon, you can see which pieces are now stale and decide whether to regenerate them.

**Evolution** is what Eidos is built around. The interesting question is not "what happens when I generate one chapter?" but "what happens when my world has been alive for six months, has thirty pieces in it across four forms and two languages, and I want to retire a character or split a faction or branch a what-if timeline?" That's the workflow Eidos is designed to make tractable.

## What Eidos enables

A few things that, taken together, are unusual:

- **Many forms from one canon.** Once your world has a populated canon, producing a haiku, a vignette, and a comic script from it is a single instruction per form. The canon stays the same; the form changes.
- **Versioned canon, branchable.** You can snapshot the world before a major change, branch it to explore an alternative, compare branches, and merge or discard. Your IP becomes a thing you can iterate on without losing earlier states.
- **Translation as a first-class operation.** A world can have content in multiple languages. Translations build on a glossary of prior translations so character names and tone stay consistent across volumes.
- **Pluggable output forms.** The default forms cover a lot of ground, but if your world wants tweets or recipe cards or radio-drama scripts, you register a form and it joins the list.
- **Auditable output.** Every piece records the canon version it was built from, the context that produced it, and any deltas it introduced back into the canon. You can always trace why a piece looks the way it does.
- **Yours, not rented.** Whichever interface you reach Eidos through, your world is your data — exportable, portable, never locked into a vendor.

## How you reach Eidos

Eidos is the engine; the way you reach it is up to you and what you're doing. The data model is the same across interfaces, so a world authored through one is a world the others can read.

- **Command-line tool** *(today)* — the canonical interface. Scaffold a world, produce pieces, manage canon, all from a terminal. Documented in the [usage guide](usage-guide.md).
- **Ruby SDK** *(today)* — embed Eidos as a library in a Ruby application (e.g., a Rails admin panel for your storyworld). Domain objects mirror the CLI's vocabulary.
- **Hosted service** *(planned)* — a web application that lets you and your collaborators reach the same world from a browser, without managing a local toolchain. Built on the same engine and data model.
- **Mobile app** *(planned)* — a thin client over the hosted service for reading, light editing, and review on the go.

Today's interfaces are the CLI and the SDK. The roadmap interfaces are not yet shipped, but the engine is designed so they can be built without changing your world's representation.

## What Eidos is *not*

Equally important is what Eidos *isn't*. Mistaking the tool for any of these will cost you time.

- **Not a one-shot book generator.** Eidos doesn't produce a finished novel from a prompt. The unit of work is the *piece*, and pieces accumulate inside a world that you steward over time. If you want a tool that gives you a 70,000-word manuscript on demand, look elsewhere.
- **Not a chapter-only tool.** Chapters are one form among many. A storyworld may produce many chapters; it may equally produce zero chapters and a thousand vignettes, comic pages, and social posts. The framing is *world → many pieces*, not *book → many chapters*.
- **Not a replacement for human editing.** Eidos produces pieces from the canon. It does not replace the work of curating, rewriting, and shaping that produces a polished final artifact. Treat its output as raw material.
- **Not opinionated about your world.** Eidos doesn't know whether you're building epic fantasy, deadpan workplace comedy, slice-of-life cozy fiction, or absurdist horror. It's a substrate. The voice and the choices are yours.
- **Not a publishing platform.** Eidos can produce content and build a static site from it, but distribution to readers is downstream — you take the output and ship it through whatever channel makes sense (a personal site, a newsletter, social media, a printed zine).

If you've read this far and the tool sounds like the thing you've been wanting, pick the interface that fits what you're doing. Today, that's the CLI (covered end-to-end in the [usage guide](usage-guide.md)) or the Ruby SDK (covered in [§8 of the same guide](usage-guide.md#8-power-user-techniques)). Start with "Create your first world" and see how far you get in fifteen minutes.
