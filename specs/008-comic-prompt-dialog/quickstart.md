# Quickstart: Comic Prompt Dialog

## Verify dialog appears in text_elements

```bash
cd book-generator
MOCK_AI=true bundle exec rspec spec/book_core/panel_description_generator_spec.rb
```

## Manual verification (real LLM)

```bash
book-generator/bin/book generate comic --chapter 1 --describe-only -b books/one-review-man
```

Then inspect the sidecar:
```bash
cat books/one-review-man/content/comics/panels_001.yml
```

Check that:
1. Panels with dialog have `text_elements` entries with `type: speech_bubble`
2. `scene_description` fields contain only visual direction — no quoted dialog
