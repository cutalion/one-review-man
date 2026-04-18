# Contract: Runtime Prompt-Call Assertion

The central safety net for US1 (Clarifications Q1). Every LLM call made during the default spec run goes through this contract.

## Surface area

The harness wraps `MockLLMService` (`eidos/spec/support/mock_llm_service.rb`). Any method on that class that receives a prompt as its first positional arg or via a `prompt:` keyword runs the prompt through `Eidos::Spec::PromptAssertionHarness.assert!` before delegating to the underlying mock behavior.

**Methods covered (existing at time of writing)**:

| Method | Prompt source |
|---|---|
| `generate_text(prompt:, context:)` | `prompt:` kwarg |
| `generate_chapter_structured(prompt, *_)` | first positional |
| `improve_content(content, *_)` | `content` is the prompt-facing string |
| `translate_chapter_structured(title, summary, content, *_)` | all three are concatenated and checked (any can carry a placeholder leak) |
| `translate_character_structured(name, description, *_)` | both checked |

**New methods**: any future method added to `LLMService` / `MockLLMService` that accepts a user-prompt-shaped argument MUST route that argument through the harness. A dedicated self-test spec (`spec/prompt_assertion_harness_spec.rb`) enforces this by listing the expected-covered methods and failing if `MockLLMService.instance_methods(false)` grows without an update.

## Inputs

The harness receives three things at each call:

1. `prompt: String` — the fully-constructed prompt string as it arrives at the mock.
2. `warnings: Array<String>` — any lines that `PromptUtils` emitted while the prompt was being built. The harness captures these by temporarily redirecting `$stderr` around the system-under-test call (after a minor change in `PromptUtils` to emit warnings to `$stderr`, not `$stdout`).
3. `caller_desc: String` — a human-readable string identifying the call site; constructed from the current RSpec example's description plus the wrapped method name.

## Assertions

The harness fails the enclosing spec (by raising `PromptAssertionFailure < StandardError`) if any of the following hold:

### A. Unfilled placeholder token in the outgoing prompt

```ruby
SINGLE_BRACE_TOKEN = /\{([A-Z_][A-Z0-9_]*)\}/
DOUBLE_BRACE_TOKEN = /\{\{([A-Z_][A-Z0-9_]*)\}\}/
```

Detection walks the prompt in two passes:
1. Extract all `{{...}}` matches (double-brace placeholders `PromptUtils` uses).
2. Strip those matches from the prompt, then scan the remainder for `{...}` matches (single-brace legacy placeholders).
3. If either pass returns a non-empty list, the harness raises with category `"unfilled placeholder"`.

### B. "Unused placeholders" warning emitted during prompt construction

Any captured `$stderr` line containing the substring `"Unused placeholders"` triggers a raise with category `"unused placeholder warning"`.

### C. Required placeholder missing

Currently `PromptUtils.build_prompt` does not explicitly warn on missing-required placeholders; the `UnfilledPlaceholdersError` path covers this implicitly (unfilled tokens remain). This contract treats "missing required" as a sub-case of (A). If `PromptUtils` is later extended to emit a distinct warning, the harness matches it via the same `$stderr`-capture mechanism.

## Failure message shape

The raised `PromptAssertionFailure` produces a multi-line RSpec failure message of the form:

```
Prompt assertion failed during <caller_desc>:
  category: unfilled placeholder
  placeholders: CHAPTER_NUMBER, STORY_TITLE
  prompt (first 500 chars): "Write Chapter {CHAPTER_NUMBER} of a {STORY_GENRE} story titled..."
```

(For warning-category failures, the `placeholders:` line is replaced by the captured warning text verbatim.)

## Exemptions

None. The harness applies unconditionally to every spec, per Clarifications Q1 ("no opt-out list, no hand-maintained allowlist"). Specs that *intentionally* want to pass a prompt with a leftover placeholder (e.g. to test the `UnfilledPlaceholdersError` path itself) must call `PromptUtils.build_prompt` / `LLMService` mock boundary directly with a disabled harness — this is done via `PromptAssertionHarness.disabled { ... }` block, used in exactly one place: the harness's own self-test spec.

## Self-test spec (canary)

`spec/prompt_assertion_harness_spec.rb` verifies:

1. A prompt with `{UNFILLED}` triggers a failure with category `unfilled placeholder`.
2. A prompt that produced a captured `"Unused placeholders"` warning triggers a failure with category `unused placeholder warning`.
3. A fully-clean prompt passes unchanged.
4. `MockLLMService.instance_methods(false)` matches the expected set (guards against future additions bypassing the harness).
5. `PromptAssertionHarness.disabled { ... }` block correctly suppresses the harness.

This spec is the canary: if the harness itself regresses, this spec catches it before every downstream spec does.
