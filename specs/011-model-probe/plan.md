# Implementation Plan: Model Probe

**Branch**: `011-model-probe`
**Created**: 2026-04-17
**Status**: Refined (post–3-critic review)

## Scope (v1)

- **P1 (reachability)** — the whole of v1. Ships as `eidos probe MODEL`.
- **P3 (`--metrics`)** — folded in as a free add-on: OpenAI already returns `usage` in the response, so reporting `input_tokens` / `output_tokens` costs nothing extra.
- **P2 (`--structured`) is deferred.** Eidos does not yet have a single canonical JSON schema to validate against; building a validator for a shape that might change is premature.
- **FR-013 (reject non-text models) is dropped for v1.** Cross-provider classification of model kinds is a moving target; instead, if a user points probe at an image/embedding model, the provider will return an "incompatible modality" error and we surface it under the `:other` category. Cheaper and equally useful.
- **Failure categories collapsed from 7 → 5**: `unknown_model` / `auth` / `network` (timeout folded in) / `rate_limit` / `other`.

## Architecture

Three new files, one registration change, zero new dependencies.

### `eidos/lib/eidos/probe_result.rb`

```ruby
Eidos::ProbeResult = Struct.new(
  :status,            # :ok or :fail
  :provider,          # "openai" | "openrouter"
  :model,             # provider model id as passed
  :latency_ms,        # Integer
  :response_excerpt,  # String (first ~80 chars, secrets-free), nil on fail
  :input_tokens,      # Integer or nil (nil when --metrics not requested or missing)
  :output_tokens,     # Integer or nil
  :failure_category,  # :unknown_model | :auth | :network | :rate_limit | :other, nil on OK
  :error_message,     # String (provider-reported), nil on OK
  keyword_init: true
) do
  def ok?   = status == :ok
  def fail? = status == :fail
  def to_h  = super.compact  # drop nil keys for JSON output
end
```

### `eidos/lib/eidos/probe.rb`

Standalone — does **not** depend on `LLMService` (its mock-AI branch, retry logic, and debug dumping are all irrelevant here). Uses `OpenAI::Client` directly so probes stay honest even when `MOCK_AI=true` is set.

Public API:

```ruby
probe = Eidos::Probe.new(
  provider: "openai" | "openrouter",
  model: "gpt-4o-mini",
  api_key: "...",          # required — raise if missing
  base_url: "...",          # optional — provider default otherwise
  timeout: 60               # seconds
)
probe.run  # => ProbeResult
```

Behaviour:

- Sends a fixed, tiny prompt to `client.chat`:
  - system: `"You are a probe. Reply with the exact text requested, nothing else."`
  - user:   `"Reply with exactly the two words: PROBE OK"`
  - `max_tokens: 20`
  - No `temperature` — many `gpt-5*` / `o3*` models reject it.
  - No `response_format` — keep it provider-agnostic.
- Measures wall-clock latency around the HTTP call.
- Pulls `usage.prompt_tokens` / `usage.completion_tokens` if present.
- On success: returns `ProbeResult(status: :ok, …)` with a ~80-char excerpt of the reply.
- On failure: classifies the error (see table below) and returns `ProbeResult(status: :fail, …)` — **never raises** for API/provider problems. Raises only for programmer errors (missing api_key).

**Failure classification table**

| Category         | Triggers                                                                            |
|------------------|-------------------------------------------------------------------------------------|
| `:unknown_model` | HTTP 404, or body matching `/(model).*(not found|does not exist|unknown)/i`          |
| `:auth`          | HTTP 401 or 403                                                                     |
| `:rate_limit`    | HTTP 429                                                                            |
| `:network`       | `Faraday::TimeoutError`, `Faraday::ConnectionFailed`, `SocketError`, explicit timeout |
| `:other`         | Everything else — including incompatible-modality errors from image/embedding models |

Matches run in that order. We explicitly keep `:other` broad — the provider's message is always surfaced, so users can see the real error even for unclassified failures. (SC-003 requires ≥90% correct classification for the four "sharp" categories, which this covers.)

### `eidos/lib/eidos/cli/probe_cli.rb`

A single Thor command, not a subcommand group. Registered on `Eidos::CLI::Main` directly as a top-level command (same shape as the existing `version` command — probe is one verb, so no nested subcommands).

```
eidos probe MODEL [options]

  MODEL                         The provider model id, e.g. gpt-4o-mini or anthropic/claude-3.5-sonnet

Options:
  --provider=PROVIDER   openai | openrouter (default: openai, or from world settings)
  --api-key=KEY         Explicit API key (overrides world settings and ENV)
  --base-url=URL        Override provider base URL (for OpenAI-compatible endpoints)
  -w, --world-dir=DIR   Use this world's settings.yml for provider credentials
  --timeout=N           Hard timeout in seconds (default: 60)
  --metrics             Include token counts in output
  --json                Emit a single-line JSON object instead of human text
```

**Credential precedence** (documented in `--help`):

1. `--api-key=...` flag (explicit wins)
2. `-w WORLD_DIR` → read `data/settings.yml` → `providers[<provider>].api_key_env` → `ENV[that_var]`
3. Conventional fallback: `ENV["OPENAI_API_KEY"]` / `ENV["OPENROUTER_API_KEY"]`

Same cascade for `base_url` (flag → settings → provider default).

If no API key found after all three steps: print a clear error listing the variables checked, exit code **2** (config error).

**Output**

Human (default):
```
OK openai gpt-4o-mini (842ms): "PROBE OK"
FAIL openai gpt-foo [unknown_model]: The model `gpt-foo` does not exist
```

With `--metrics`:
```
OK openai gpt-4o-mini (842ms, 23 in / 4 out tokens): "PROBE OK"
```

JSON (`--json`):
```json
{"status":"ok","provider":"openai","model":"gpt-4o-mini","latency_ms":842,"response_excerpt":"PROBE OK"}
```

**Exit codes**: `0` OK, `1` FAIL, `2` config error (missing creds / unknown provider).

### Registration

In `eidos/lib/eidos/cli/main.rb`, add:

```ruby
require 'eidos/cli/probe_cli'

desc 'probe MODEL', 'Smoke-test a provider/model for reachability'
# delegate to ProbeCli
def probe(model)
  Eidos::CLI::ProbeCli.new([model], options).run
end
```

(Or, equivalently, register `ProbeCli` as a Thor command via `register`. Whichever keeps the `-w` inheritance from class_options cleanest — decide at implementation time.)

## Tests

### `spec/eidos/probe_spec.rb` (primary)

Stub `OpenAI::Client#chat` with a double. Covers:

- Happy path: returns `ProbeResult(:ok)` with provider, model, latency_ms > 0, response excerpt, and (when usage present) tokens.
- Unknown model: HTTP 404 body → `:unknown_model`.
- Auth failure: HTTP 401 → `:auth`.
- Rate limit: HTTP 429 → `:rate_limit`.
- Timeout: raises `Faraday::TimeoutError` → `:network`.
- Connection refused: `Faraday::ConnectionFailed` → `:network`.
- Other error: HTTP 500 → `:other` (provider message preserved).
- No api_key given: raises `Eidos::Probe::MissingCredentialError` (not a fail-result — programmer error).
- Secrets: response excerpt & error message must not contain the api_key (even if a bogus API echoes it back).
- OpenRouter: uses `uri_base: 'https://openrouter.ai/api/v1'` when no explicit base_url given.

### `spec/eidos/cli/probe_cli_spec.rb` (light smoke)

- Resolves credentials from flag > world settings > ENV (test each layer).
- `--json` emits valid JSON; `--metrics` adds tokens block.
- Exit code: 0 on OK, 1 on FAIL, 2 on missing creds.

All tests stub `OpenAI::Client#chat`; none hit the network.

## Doc updates (part of commit)

- `eidos/README.md` → new row in CLI block for `eidos probe MODEL`.
- Root `README.md` → same.
- `CLAUDE.md` / `AGENTS.md` → note the new verb in the CLI overview.

## Out of scope for v1 (explicit)

- Structured-output mode (P2)
- Bulk / matrix probing
- Cost-in-dollars reporting
- Cross-provider model-kind detection
- New provider support (Anthropic direct, Ollama, etc.) — this rides on existing OpenAI + OpenRouter support

## Risk register

- **OpenRouter returns OpenAI-style errors but with provider-prefixed upstream messages.** We classify off HTTP status first, message regex second, so this should be fine. Logged for vigilance.
- **Some gateways don't return `usage`**. `input_tokens` / `output_tokens` become `nil` — already modelled.
- **`base_url` from settings can point at an OpenAI-compatible endpoint (e.g. self-hosted).** `openai` provider + custom `--base-url` already covers this, no extra code.
- **`MOCK_AI=true` in the user's shell must NOT silence the probe.** Probe uses `OpenAI::Client` directly; it never checks `EnvUtils.mock_ai_enabled?`. Verified in tests.
