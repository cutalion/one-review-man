# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'eidos/piece'

# Feature 018a — FR-012 / SC-007: pre-018a chapter files MUST remain
# readable post-018a. `Piece.from_file` synthesizes sensible defaults for
# the new keys (id, form, canon_version, canon_delta_ref) so callers like
# `eidos piece show` and `eidos piece list --form chapter` keep working
# against worlds (e.g. `worlds/one-review-man`) that haven't yet been
# migrated to the new chapter shape.
#
# 018c will migrate the legacy world; this spec guards the readability
# invariant until then so unrelated `Piece` / `PieceProducer` changes
# don't accidentally break legacy worlds.
RSpec.describe 'Legacy chapter readability (FR-012)' do
  let(:tmp_dir) { Dir.mktmpdir('legacy_chapter_readability') }
  let(:chapter_path) { File.join(tmp_dir, 'content', 'chapters', '001-chapter.md') }

  before do
    FileUtils.mkdir_p(File.join(tmp_dir, 'content', 'chapters'))
    legacy_frontmatter = {
      'layout' => 'chapter',
      'title' => 'A Pre-018a Chapter',
      'chapter_number' => 1,
      'characters' => ['arthur'],
      'summary' => 'Arthur reviews a PR.',
      'word_count' => 312,
      'permalink' => '/chapters/001-chapter/',
      'generated_date' => '2026-01-15',
      'status' => 'generated',
      'lang' => 'en',
      'new_characters' => []
    }
    File.write(chapter_path, "#{legacy_frontmatter.to_yaml}---\n\nArthur sat at his desk.\n")
  end

  after { FileUtils.rm_rf(tmp_dir) }

  it 'reads a legacy chapter file via Piece.from_file without raising' do
    expect { Eidos::Piece.from_file(chapter_path) }.not_to raise_error
  end

  it 'synthesizes sensible defaults for the new universal keys' do
    piece = Eidos::Piece.from_file(chapter_path)

    expect(piece.form).to eq('chapter')        # inferred from path
    expect(piece.canon_version).to eq('unversioned') # legacy fallback
    expect(piece.canon_status).to eq(:applied) # default
    expect(piece.id).to eq('1')                # extracted from NNN- filename
    expect(piece.length_measured).to eq(312)   # from legacy word_count key
  end

  it 'preserves the legacy chapter-specific fields in the frontmatter hash' do
    piece = Eidos::Piece.from_file(chapter_path)
    expect(piece.frontmatter['title']).to eq('A Pre-018a Chapter')
    expect(piece.frontmatter['summary']).to eq('Arthur reviews a PR.')
    expect(piece.frontmatter['chapter_number']).to eq(1)
  end
end
