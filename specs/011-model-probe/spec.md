# Feature Specification: Model Probe — cheap smoke-test for provider/model combinations

**Feature Branch**: `011-model-probe`
**Created**: 2026-04-17
**Status**: Draft
**Input**: User description: "need a simple and cheap way to test new models from supported providers"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Verify a new model is reachable and responds correctly (Priority: P1)

A content creator or developer has heard about a new model (e.g. a freshly released `gpt-5-nano`, an OpenRouter-hosted variant, or anything else their provider account gives them access to). Before they swap it into their storyworld's `settings.yml` and kick off a real chapter generation, they want a 10-second sanity check: does authentication work, is the model id recognized by the provider, and does it return a coherent response to a trivial prompt?

**Why this priority**: This is the single most common friction when evaluating new models — you pay for a mistake by watching a long generation run silently fail halfway through, then re-reading provider docs to figure out whether you typo'd the model id, used the wrong API key, or hit a region/entitlement issue. A 1-command sanity check eliminates that whole category of waste.

**Independent Test**: From a world directory, run the probe command with an explicit model id. The command performs one short round-trip to the provider and prints a pass/fail result with the model's reply. This delivers value by itself even if nothing else in this feature ships.

**Acceptance Scenarios**:

1. **Given** the user has valid credentials for a configured provider, **When** they run the probe command with a known-good model id, **Then** the command prints `OK`, the provider name, the model id, the response latency, and a one-line sample of the model's output in under 30 seconds.
2. **Given** the user supplies a model id the provider does not recognize, **When** they run the probe command, **Then** the command prints `FAIL`, the provider's error message, and exits with a non-zero status.
3. **Given** the user's API key is missing or invalid, **When** they run the probe command, **Then** the command reports the authentication failure clearly (without leaking the key) and exits with a non-zero status.

---

### User Story 2 - Confirm the model can produce Eidos's expected output format (Priority: P2)

The user wants to know if a candidate model doesn't just *respond*, but actually returns the structured output Eidos uses for its main tasks (for example, the JSON shape produced during chapter generation or translation). A model can pass a raw "hello" test and still be unsuitable because it won't reliably emit valid JSON, or because it ignores system prompts, or because it produces plain prose where structured output is required.

**Why this priority**: Catches the second most common failure mode — models that reply but don't conform to Eidos's task contracts. Important, but only useful after P1 confirms basic reachability.

**Independent Test**: Run the probe command with a `--format` (or equivalent) option that asks for a small, representative structured response. The command validates the response against the expected shape and reports whether it parsed successfully, again within ~30 seconds and with minimal token use.

**Acceptance Scenarios**:

1. **Given** a reachable model, **When** the user probes it with a structured-output check, **Then** the command reports whether the response parsed as valid structured output and, on failure, shows what was returned so the user can judge how far off the model is.
2. **Given** a model that passes the basic probe but fails structured output, **When** the user runs the structured check, **Then** the failure is clearly distinguishable from a pure reachability failure.

---

### User Story 3 - See a cost & latency preview before committing (Priority: P3)

After confirming that a model works and respects the task contract, the user wants a ballpark feel for what it will cost and how long it will take on a realistic-sized Eidos task. This lets them compare candidates without running a full chapter.

**Why this priority**: Nice-to-have. Useful for model shopping, but the first two stories already unblock most day-to-day evaluation.

**Independent Test**: Run the probe command with a preview flag. The output includes input/output token counts and the wall-clock latency of the round-trip, so the user can multiply by the pricing they already know or record the numbers for comparison.

**Acceptance Scenarios**:

1. **Given** a successful probe, **When** the user requests preview metrics, **Then** the command reports input tokens, output tokens, and total round-trip latency for the probe call.
2. **Given** several candidate models, **When** the user probes each, **Then** the numbers are presented in a format they can eyeball or pipe into their own comparison script.

---

### Edge Cases

- **Model id typo**: The command must clearly distinguish "unknown model" from "auth failure" from "network timeout" so the user knows which knob to turn.
- **Slow model**: If a probe takes longer than a reasonable timeout (default ~60 seconds), the command should abort with a clear timeout message rather than hang.
- **Cold-start models**: Some providers queue less-common models; the command should surface provider-reported queueing / cold-start signals when available, rather than reporting them as generic slowness.
- **Provider down**: If the provider itself is unreachable (DNS / network), the command should distinguish that from an invalid model id.
- **Non-chat models**: A user might supply an image, embedding, or audio model id. The command should recognize this and report that the model kind is out of scope, rather than sending an incompatible chat request.
- **Rate limits**: A probe should not be retried silently; a rate-limit response must be surfaced so the user knows to wait or use a different key.
- **Streaming-only models**: Some models only support streaming responses. The probe must not fail if non-streaming is unavailable — it should consume the stream transparently and still report a single, summarized result.
- **World-less invocation**: The user may want to probe a model without having a world directory set up. The command should work given only provider credentials (e.g. via environment variables) and an explicit provider/model id.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a single command that probes a specified (provider, model) combination and reports pass/fail within a bounded amount of time (target: ~30 seconds for the default probe, with a hard timeout at 60 seconds).
- **FR-002**: The probe MUST use a short, fixed prompt that keeps token usage minimal (target: under ~200 input tokens and ~50 output tokens per probe invocation) so that repeated probing does not accumulate meaningful cost.
- **FR-003**: The probe MUST accept an explicit provider name and model id so the user can test any model their provider exposes without editing their world's settings first.
- **FR-004**: The probe MUST be runnable from within a world directory using that world's configured provider credentials, and MUST also be runnable without a world directory using credentials supplied via environment variables.
- **FR-005**: The probe MUST NOT mutate the world's `settings.yml`, Story Bible, chapters, or any other persistent content as a side effect of a probe run.
- **FR-006**: On success, the probe MUST report the provider, the model id, the wall-clock latency of the call, and a short excerpt of the model's response so the user can sanity-check the output.
- **FR-007**: On failure, the probe MUST clearly indicate the failure category (unknown model, authentication failure, network / timeout, rate limit, incompatible model kind, or other) and the provider's original error message when available, and MUST exit with a non-zero status so it can be scripted.
- **FR-008**: The probe MUST NEVER print secret values (API keys, tokens) in its output, including on failure.
- **FR-009**: The probe MUST support all LLM providers Eidos already knows how to talk to for text generation (currently OpenAI and OpenRouter), without requiring provider-specific flags from the user beyond provider name and model id.
- **FR-010**: The probe SHOULD offer an optional mode that validates whether the model returns the structured output shape Eidos uses in its primary tasks (e.g., JSON chapter output), reporting structured-output pass/fail separately from reachability pass/fail.
- **FR-011**: The probe SHOULD offer an optional mode that reports per-call input token count, output token count, and latency, so the user can compare models.
- **FR-012**: The probe MUST produce output that is readable by a human in a terminal by default, and MAY offer a machine-readable output option (e.g. JSON) for scripting.
- **FR-013**: The probe MUST reject and cleanly error on obvious non-text model kinds (image, audio, embedding) rather than sending an incompatible chat request.

### Key Entities *(include if feature involves data)*

- **Probe Target**: The (provider, model id) pair the user wants to test. Attributes: provider name, model id, and — if applicable — provider-specific options (e.g., a base URL override for OpenAI-compatible providers).
- **Probe Result**: The outcome of a single probe run. Attributes: status (`ok` / `fail`), failure category (if applicable), latency, input token count, output token count, short response excerpt, and any provider-reported error message.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user who has valid credentials can run the probe against a previously-untried model and get a conclusive pass/fail result in under 30 seconds, 95% of the time.
- **SC-002**: A single probe call consumes no more than ~250 total tokens (input + output combined) under default settings, so 40 probe runs cost roughly what one short generation run costs.
- **SC-003**: Of all probe failures, at least 90% are reported with a failure category that correctly distinguishes "wrong model id", "authentication", "network / timeout", and "rate limit" — verified by running the probe against deliberately-broken inputs and inspecting the messages.
- **SC-004**: After a probe run, no world file (settings, Story Bible, chapters, snapshots) has changed on disk — verified by comparing file checksums before and after.
- **SC-005**: A new user can go from "heard about a new model" to "know whether it works for my world" with one command and zero edits to existing configuration files.
- **SC-006**: No API key, token, or other credential ever appears in probe output or error messages.

## Assumptions

- "Supported providers" means the providers Eidos already supports for text generation in its current codebase: **OpenAI** and **OpenRouter**. Expanding to new providers is a separate feature and out of scope here.
- "Cheap" means "small prompts and single round-trips", not "free". A per-probe cost cap or budget flag is out of scope for v1; the small fixed-prompt design is expected to keep probe cost trivially small in practice.
- The probe is a developer / operator tool, not an end-user feature. It is invoked from a terminal (as part of the `eidos` CLI or an equivalent command), and readable terminal output is the primary interface.
- The user is comfortable supplying a model id exactly as the provider spells it (e.g. `gpt-4o-mini`, or `anthropic/claude-3.5-sonnet` for OpenRouter). The probe does not need to auto-discover the list of valid model ids.
- Credentials are supplied via the world's `settings.yml` or the same environment variables the rest of Eidos already uses (e.g. `OPENAI_API_KEY`). The probe does not introduce a new credential store.
- The probe evaluates only whether a model *works* and *conforms to Eidos's task shape*. Judging whether a model's prose *quality* is good enough for the user's storyworld is explicitly out of scope — that requires human evaluation.
- The probe runs a single call per invocation. Bulk / matrix probing (e.g. "run every configured model at once") is out of scope for v1 and can be trivially layered by the user with a shell loop.
- Reporting dollar-cost estimates is out of scope for v1, because provider pricing changes frequently and would require maintaining a pricing table. Token counts + latency are reported instead, and the user can translate those to cost using their provider's current prices.
