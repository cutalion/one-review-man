# frozen_string_literal: true

require 'tmpdir'
require_relative '../lib/eidos/impact_analyzer'
require_relative '../lib/eidos/revision_store'

RSpec.describe Eidos::ImpactAnalyzer do
  let(:tmpdir) { Dir.mktmpdir }
  let(:content_path) { File.join(tmpdir, 'content') }
  let(:index_path) { File.join(tmpdir, 'references.yml') }
  let(:reports_path) { File.join(tmpdir, 'impact_reports') }
  let(:revisions_path) { File.join(tmpdir, 'revisions') }
  let(:store) { Eidos::RevisionStore.new(revisions_path: revisions_path) }
  let(:analyzer) do
    described_class.new(
      content_path: content_path,
      reference_index_path: index_path,
      revision_store: store,
      reports_path: reports_path
    )
  end

  before do
    FileUtils.mkdir_p(File.join(content_path, 'chapters'))
    FileUtils.mkdir_p(File.join(content_path, 'characters'))
  end

  after { FileUtils.rm_rf(tmpdir) }

  def create_chapter(name, content)
    File.write(File.join(content_path, 'chapters', name), content)
  end

  describe '#rebuild_index!' do
    it 'creates a references.yml file' do
      create_chapter('001.md', 'Kenji walked into the office.')
      analyzer.rebuild_index!
      expect(File.exist?(index_path)).to be true
    end
  end

  describe '#analyze' do
    it 'finds content referencing a changed entity' do
      create_chapter('001.md', "Kenji reviewed the code.\nHe found three bugs.")
      create_chapter('002.md', "Kai was working alone.")

      revision = store.record(
        entity_type: 'character', entity_id: 'kenji',
        snapshot: { 'name' => 'Kenji', 'role' => 'senior' },
        operation: 'update'
      )

      report = analyzer.analyze(
        entity_type: 'character', entity_id: 'kenji',
        revision: revision
      )

      expect(report).to be_a(Eidos::Models::ImpactReport)
      expect(report.affected_items.length).to eq(1)
      expect(report.affected_items[0].content_path).to eq('chapters/001.md')
      expect(report.affected_items[0].review_status).to eq('pending')
    end

    it 'classifies severity based on reference count' do
      content = "Kenji did this.\nKenji did that.\nKenji did more."
      create_chapter('001.md', content)

      revision = store.record(
        entity_type: 'character', entity_id: 'kenji',
        snapshot: { 'name' => 'Kenji' }, operation: 'update'
      )

      report = analyzer.analyze(entity_type: 'character', entity_id: 'kenji', revision: revision)
      expect(report.affected_items[0].severity).to eq('high')
    end

    it 'saves the report to disk' do
      create_chapter('001.md', 'Kenji was here.')

      revision = store.record(
        entity_type: 'character', entity_id: 'kenji',
        snapshot: {}, operation: 'update'
      )

      report = analyzer.analyze(entity_type: 'character', entity_id: 'kenji', revision: revision)
      loaded = analyzer.load_report(report.id)
      expect(loaded).not_to be_nil
      expect(loaded.id).to eq(report.id)
    end

    it 'returns empty affected_items when no content references the entity' do
      create_chapter('001.md', 'No references here.')

      revision = store.record(
        entity_type: 'character', entity_id: 'kenji',
        snapshot: {}, operation: 'update'
      )

      report = analyzer.analyze(entity_type: 'character', entity_id: 'kenji', revision: revision)
      expect(report.affected_items).to be_empty
    end
  end

  describe '#update_review_status' do
    it 'updates item status and records reviewed_at' do
      create_chapter('001.md', 'Kenji was here.')

      revision = store.record(
        entity_type: 'character', entity_id: 'kenji',
        snapshot: {}, operation: 'update'
      )

      report = analyzer.analyze(entity_type: 'character', entity_id: 'kenji', revision: revision)

      updated = analyzer.update_review_status(
        report_id: report.id, item_index: 0, status: 'reviewed'
      )

      expect(updated.affected_items[0].review_status).to eq('reviewed')
      expect(updated.affected_items[0].reviewed_at).not_to be_nil
    end

    it 'returns nil for non-existent report' do
      result = analyzer.update_review_status(report_id: 'nope', item_index: 0, status: 'reviewed')
      expect(result).to be_nil
    end
  end

  describe '#list_reports' do
    it 'lists reports for a branch' do
      create_chapter('001.md', 'Kenji was here.')

      revision = store.record(
        entity_type: 'character', entity_id: 'kenji',
        snapshot: {}, operation: 'update'
      )

      analyzer.analyze(entity_type: 'character', entity_id: 'kenji', revision: revision)
      reports = analyzer.list_reports(branch: 'main')
      expect(reports.length).to eq(1)
    end
  end
end
