#!/usr/bin/env ruby
# frozen_string_literal: true

# One-shot migration script for `worlds/one-review-man` from the legacy
# pre-018a chapter shape to the post-018a unified piece shape.
#
# What it does:
#   - For each English `content/chapters/NNN-chapter.md`:
#     • Generates a hash piece id and a hash canon-delta id.
#     • Adds the universal frontmatter keys (id, form, category,
#       canon_status, canon_version: <integer>, canon_delta_ref) without
#       disturbing existing chapter-specific keys (title, chapter_number,
#       summary, characters, etc.).
#     • Writes a synthesized canon-delta record to
#       `data/canon_deltas/<delta_id>.yml` with empty section arrays
#       (the original LLM tail block was never persisted, so we cannot
#       reconstruct what entities each chapter introduced — we record an
#       applied-at timestamp matching the chapter's generated_date).
#   - Writes `canon: { revision: <chapter-count> }` into `world_state.yml`.
#   - Creates `data/canon_deltas/` if absent.
#
# What it does NOT do:
#   - Touch translated `*.ru.md` files (legacy `Piece#from_file` synthesis
#     keeps them readable; they're not "pieces" in the post-018a sense).
#   - Touch any other file in `worlds/one-review-man/`.
#   - Run twice on a chapter that already has `id` + `canon_delta_ref`
#     (idempotent: re-runs are a no-op for already-migrated chapters).
#
# Usage:
#   ruby specs/018c-orm-migration/migrate.rb               # default world path
#   ruby specs/018c-orm-migration/migrate.rb path/to/world # explicit path
#   ruby specs/018c-orm-migration/migrate.rb --dry-run     # preview only
#
# Per FR-006a: after this migration runs successfully, the temporary
# in-place migration branch in `Eidos::WorldState#current_revision` can
# be retired (replaced with a strict raise on missing canon.revision).

require 'yaml'
require 'fileutils'
require 'securerandom'
require 'date'
require 'time'

DEFAULT_WORLD_PATH = File.expand_path('../../worlds/one-review-man', __dir__)

def parse_args(argv)
  args = { dry_run: false, world_path: nil }
  argv.each do |arg|
    case arg
    when '--dry-run'   then args[:dry_run] = true
    when /^-/          then warn "unknown flag: #{arg}"; exit 2
    else
      args[:world_path] ||= File.expand_path(arg)
    end
  end
  args[:world_path] ||= DEFAULT_WORLD_PATH
  args
end

def generate_id
  # 26-char uppercase hex, ULID-shaped. Same format the post-018a
  # PieceProducer emits.
  "01#{SecureRandom.hex(12).upcase}"
end

def chapter_files(world_path)
  Dir.glob(File.join(world_path, 'content', 'chapters', '*-chapter.md'))
     .reject { |p| p.end_with?('.ru.md') }
     .sort_by { |p| File.basename(p)[/^(\d{3})/, 1].to_i }
end

def parse_frontmatter(raw)
  return [{}, raw] unless raw.start_with?("---\n")

  parts = raw.split(/^---\s*$/, 3)
  return [{}, raw] unless parts.length >= 3

  fm = YAML.safe_load(parts[1], permitted_classes: [Date, Time, Symbol]) || {}
  body = parts[2].sub(/\A\n/, '')
  [fm, body]
end

def already_migrated?(fm)
  fm.is_a?(Hash) && fm['id'].is_a?(String) && fm['canon_delta_ref'].is_a?(String) &&
    fm['form'] == 'chapter' && fm['canon_version'].is_a?(Integer)
end

def build_migrated_frontmatter(fm, piece_id:, delta_id:, revision:)
  # Drop the legacy 'canon_version: unversioned' string sentinel before
  # writing the integer (banned-fallback rule: never preserve a sentinel
  # alongside a real value).
  base = fm.reject { |k, _| k == 'canon_version' && fm['canon_version'] == 'unversioned' }
  {
    'id' => piece_id,
    'form' => 'chapter',
    'category' => 'text'
  }.merge(base).merge(
    'canon_version' => revision,
    'canon_status' => fm['canon_status'] || 'applied',
    'canon_delta_ref' => delta_id
  )
end

def build_synthesized_delta(piece_id:, delta_id:, applied_at:)
  {
    'id' => delta_id,
    'piece_id' => piece_id,
    'created_at' => applied_at,
    'applied_at' => applied_at,
    'reverted_at' => nil,
    'parse_error' => nil,
    'new_characters' => [],
    'new_locations' => [],
    'new_facts' => [],
    'new_events' => [],
    'new_relationships' => [],
    'entity_updates' => []
  }
end

def coerce_applied_at(fm)
  raw = fm['generated_date']
  case raw
  when Time then raw.utc
  when Date then Time.utc(raw.year, raw.month, raw.day)
  when String then Time.parse(raw).utc
  else Time.now.utc
  end
rescue ArgumentError
  Time.now.utc
end

def write_chapter(path, frontmatter, body, dry_run:)
  output = "#{frontmatter.to_yaml}---\n\n#{body.lstrip}"
  return if dry_run

  File.write(path, output)
end

def write_delta(world_path, delta, dry_run:)
  deltas_dir = File.join(world_path, 'data', 'canon_deltas')
  FileUtils.mkdir_p(deltas_dir) unless dry_run
  path = File.join(deltas_dir, "#{delta['id']}.yml")
  return path if dry_run

  File.write(path, delta.to_yaml)
  path
end

def update_world_state(world_path, revision, dry_run:)
  state_path = File.join(world_path, 'data', 'world_state.yml')
  data = YAML.safe_load_file(state_path, permitted_classes: [Date, Time]) || {}
  data['canon'] ||= {}
  data['canon']['revision'] = revision
  return if dry_run

  tmp = "#{state_path}.tmp"
  File.write(tmp, data.to_yaml)
  File.rename(tmp, state_path)
end

def main
  args = parse_args(ARGV)
  world_path = args[:world_path]
  dry_run = args[:dry_run]

  unless Dir.exist?(File.join(world_path, 'content', 'chapters'))
    warn "world has no content/chapters/: #{world_path}"
    exit 1
  end

  prefix = dry_run ? '[DRY RUN] ' : ''
  puts "#{prefix}Migrating #{world_path}"

  chapters = chapter_files(world_path)
  puts "#{prefix}Found #{chapters.size} English chapter file(s)"

  migrated = 0
  skipped = 0
  revision = 0

  chapters.each do |chapter_path|
    raw = File.read(chapter_path)
    fm, body = parse_frontmatter(raw)

    if already_migrated?(fm)
      revision = [revision, fm['canon_version'].to_i].max
      skipped += 1
      puts "#{prefix}  skip  #{File.basename(chapter_path)} (already migrated, canon_version=#{fm['canon_version']})"
      next
    end

    revision += 1
    piece_id = generate_id
    delta_id = generate_id
    applied_at = coerce_applied_at(fm)

    new_fm = build_migrated_frontmatter(fm, piece_id: piece_id, delta_id: delta_id, revision: revision)
    delta = build_synthesized_delta(piece_id: piece_id, delta_id: delta_id, applied_at: applied_at)

    write_chapter(chapter_path, new_fm, body, dry_run: dry_run)
    write_delta(world_path, delta, dry_run: dry_run)

    puts "#{prefix}  migrate  #{File.basename(chapter_path)} → id=#{piece_id} delta=#{delta_id} canon_version=#{revision}"
    migrated += 1
  end

  update_world_state(world_path, revision, dry_run: dry_run)
  puts "#{prefix}Wrote canon.revision = #{revision} to world_state.yml"
  puts "#{prefix}Done. migrated=#{migrated} skipped=#{skipped}"
end

main
