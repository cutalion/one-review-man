# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'digest'
require 'eidos/cli/publish'

# Feature 017 regression: `eidos publish jekyll` MUST NOT write into the
# source world's `data/` directory. The publish path used to call
# `Eidos::StoryBibleExporter#export_for_jekyll!` (which writes into the
# source) before copying content to the destination. The fix relocates
# those writes to the destination via `export_to(<dest>/_data)`.
#
# Contract: specs/017-publish-cleanup/contracts/source-world-untouched.md
RSpec.describe Eidos::CLI::Publish do
  let(:source) { Dir.mktmpdir('eidos-publish-source-') }
  let(:dest)   { Dir.mktmpdir('eidos-publish-dest-') }

  before do
    # Minimal source world: just enough YAML for publish to do real work.
    # `data/story_bible/` must exist for the exporter to run (publish.rb:44).
    FileUtils.mkdir_p(File.join(source, 'data', 'story_bible'))
    FileUtils.mkdir_p(File.join(source, 'content'))

    File.write(
      File.join(source, 'data', 'world_config.yml'),
      <<~YAML
        ---
        title: Test World
        author: Test Author
        languages:
          - en
        default_language: en
        localized:
          en:
            story_title: Test World
            author: Test Author
            story_genre: Fiction
      YAML
    )
    File.write(
      File.join(source, 'data', 'strings.yml'),
      <<~YAML
        ---
        en:
          test_key: test value
      YAML
    )

    # Suppress Thor stdout during the test (otherwise it spams the spec output).
    allow($stdout).to receive(:puts)
    allow($stdout).to receive(:write)
  end

  after do
    FileUtils.remove_entry(source) if source && File.exist?(source)
    FileUtils.remove_entry(dest) if dest && File.exist?(dest)
  end

  # Hash every regular file under `root`, keyed by its path relative to root.
  def snapshot(root)
    Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).each_with_object({}) do |path, h|
      next if File.directory?(path)
      next if path.end_with?('/.', '/..')

      rel = path.delete_prefix("#{root}/")
      h[rel] = Digest::SHA256.hexdigest(File.read(path))
    end
  end

  it 'leaves the source world byte-identical after publish (no new, modified, or removed files)' do
    before_snapshot = snapshot(source)
    described_class.start(['jekyll', '-w', source, '--dest', dest])
    after_snapshot = snapshot(source)

    expect(after_snapshot).to eq(before_snapshot),
                              "Source world was modified by publish.\n" \
                              "Added/modified: #{(after_snapshot.to_a - before_snapshot.to_a).map(&:first).inspect}\n" \
                              "Removed: #{(before_snapshot.to_a - after_snapshot.to_a).map(&:first).inspect}"
  end

  it 'is source-idempotent — three successive publishes leave the source byte-identical' do
    before_snapshot = snapshot(source)

    3.times do
      described_class.start(['jekyll', '-w', source, '--dest', dest])
    end

    after_snapshot = snapshot(source)
    expect(after_snapshot).to eq(before_snapshot),
                              'Source world drifted across multiple publish runs — feature 017 idempotence violated.'
  end

  it 'populates the destination _data block with files Jekyll templates need' do
    described_class.start(['jekyll', '-w', source, '--dest', dest])

    expect(File).to exist(File.join(dest, '_data', 'strings.yml'))
  end
end
