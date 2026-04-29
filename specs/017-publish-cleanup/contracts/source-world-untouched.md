# Contract: `eidos publish jekyll` Leaves the Source World Byte-Identical

**Owner**: `eidos/lib/eidos/cli/publish.rb` (the publish command)
**Verified by**: `eidos/spec/eidos/cli/publish_spec.rb` (new RSpec file added by this feature)

## The invariant

For every file `f` under `<source-world>/` that exists before `eidos publish jekyll -w <source-world> --dest <destination>` runs, after the run completes:

1. `f` still exists at the same path.
2. `SHA-256(content of f after) == SHA-256(content of f before)`.
3. No new file exists under `<source-world>/` that did not exist before the run.
4. No file that existed under `<source-world>/` before the run has been removed.

These four conditions together comprise "byte-identical." The invariant is the central commitment of this feature (spec FR-001).

The invariant binds the `--dest` path being outside `<source-world>/`. If a user invokes publish with `--dest worlds/<source>/site/` (destination *inside* source), changes under `worlds/<source>/site/` are obviously expected. Before evaluating the invariant, the destination subtree is excluded from comparison.

## Test methodology

The regression spec (`eidos/spec/eidos/cli/publish_spec.rb`) implements the invariant as follows:

```ruby
# pseudo-shape — the actual spec is RSpec
require 'digest'
require 'tmpdir'

before do
  @source = Dir.mktmpdir('eidos-publish-source-')
  @dest   = Dir.mktmpdir('eidos-publish-dest-')
  scaffold_minimal_world(@source)  # populates data/world_config.yml, data/story_bible/, etc.
end

after do
  FileUtils.remove_entry(@source) if @source
  FileUtils.remove_entry(@dest) if @dest
end

def snapshot(root)
  Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).each_with_object({}) do |path, h|
    next if File.directory?(path)
    next if path.end_with?('/.', '/..')
    rel = path.delete_prefix(root + '/')
    h[rel] = Digest::SHA256.hexdigest(File.read(path))
  end
end

it 'leaves the source world byte-identical' do
  before = snapshot(@source)
  Eidos::CLI::Publish.start(['jekyll', '-w', @source, '--dest', @dest])
  after  = snapshot(@source)
  expect(after).to eq(before)
end

it 'is idempotent (running twice produces the same destination)' do
  Eidos::CLI::Publish.start(['jekyll', '-w', @source, '--dest', @dest])
  first = snapshot(@dest)
  Eidos::CLI::Publish.start(['jekyll', '-w', @source, '--dest', @dest])
  second = snapshot(@dest)
  expect(second).to eq(first)
end

it 'populates the destination _data block with the data templates need' do
  Eidos::CLI::Publish.start(['jekyll', '-w', @source, '--dest', @dest])
  data = File.join(@dest, '_data')
  expect(File).to exist(File.join(data, 'characters.yml'))
  expect(File).to exist(File.join(data, 'strings.yml'))
end
```

## Test running guarantees

- **`MOCK_AI=true`**: the test runs under mock mode by default (no LLM calls happen during publish anyway, but Constitution Principle I requires every spec to be green under mock).
- **No git dependency**: the test does not rely on `git status` or `git diff`. It uses content hashes directly. (The spec's SC-001 frames the invariant in terms of `git diff --quiet` because that's the user-visible check; the regression test uses a stronger hash-equality check that doesn't require the source to be a git repo.)
- **No network dependency**: the test creates everything in `Dir.mktmpdir` and tears it down via `FileUtils.remove_entry`.

## What this contract does NOT cover

- The destination is allowed to be created from scratch, partially overwritten, or fully overwritten — the `existing_site?` detection logic chooses among these. Destination behavior is governed by the existing `publish.rb` semantics; this contract scopes only the source.
- File modification times (`mtime`) are not part of the invariant. A future caller might `chown -R` or `touch` the source for reasons unrelated to publish — that's not publish's concern. We assert content equality (SHA-256), not metadata equality.
- The `tmp/` and `worlds/<name>/tmp/` subdirectories that the LLM debug machinery may write into are gitignored. The regression test's source world doesn't trigger any LLM call (publish doesn't make LLM calls), so `tmp/ai_debug/` would not be populated. If a future code path adds LLM calls under publish, the test would catch the resulting source-world write as a violation.

## How to falsify this contract

The test fails (and the contract is broken) if any of the following are true after publish:

- A new file appears under `<source-world>/` that was not present before. *(This catches the original bug: `data/world.yml`, `data/story_facts.yml`.)*
- An existing file's content has changed. *(This would catch the exporter overwriting an existing `data/characters.yml`.)*
- An existing file has been removed.

Any of these conditions indicates a regression of the source-world-untouched invariant.
