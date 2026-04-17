# frozen_string_literal: true

require 'eidos/producer'
require 'eidos/producer_result'
require 'eidos/configuration'
require 'eidos/chapter_generator'
require 'eidos/canon_version_reference'

module Eidos
  module Producers
    class ChapterProducer
      include Eidos::Producer

      producer_name :chapter
      producer_description 'Generate chapters from Story Bible canon'
      default_output_path 'content/chapters'

      def initialize(project_root:, llm_service: nil, **deps)
        @project_root = File.expand_path(project_root)
        @llm_service = llm_service
        @deps = deps
      end

      def produce(snapshot: nil, config: {}, output: nil)
        validate!(snapshot: snapshot, config: config, output: output)

        FileUtils.mkdir_p(output) if output && !Dir.exist?(output)

        generator = build_generator(snapshot: snapshot, config: config, output: output)
        content = generator.generate_next_chapter(auto_generate: config[:auto_generate] || config['auto_generate'])

        ProducerResult.new(
          success: true,
          output_path: output || File.join(@project_root, self.class.default_output_path),
          canon_version: resolve_canon_version(snapshot),
          artifacts: collect_artifacts(output),
          error: nil
        )
      rescue StandardError => e
        ProducerResult.new(
          success: false,
          output_path: output || File.join(@project_root, self.class.default_output_path),
          canon_version: resolve_canon_version(snapshot),
          artifacts: [],
          error: e.message
        )
      end

      private

      def build_generator(snapshot:, config:, output:)
        kwargs = {
          project_root: @project_root,
          snapshot: snapshot
        }

        kwargs[:llm_service] = @llm_service if @llm_service

        if output
          require 'eidos/content_adapter'
          adapter = Eidos::ContentAdapter.new
          adapter.setup_project(output)
          kwargs[:output_adapter] = adapter
        end

        model = config[:model] || config['model']
        if model
          kwargs[:configuration] = Eidos::Configuration.load(@project_root, { 'content.model' => model })
        else
          kwargs[:configuration] = Eidos::Configuration.load(@project_root, {})
        end

        Eidos::ChapterGenerator.new(**kwargs)
      end

      def resolve_canon_version(snapshot_name)
        bible_path = File.join(@project_root, StoryBible::STORY_BIBLE_DIR)
        return 'unversioned' unless Dir.exist?(bible_path)

        store = SnapshotStore.new(story_bible_path: bible_path)
        CanonVersionReference.resolve(snapshot_store: store, explicit_snapshot: snapshot_name)
      rescue SnapshotNotFoundError
        'unversioned'
      end

      def collect_artifacts(output)
        chapters_dir = output || File.join(@project_root, 'content', 'chapters')
        return [] unless Dir.exist?(chapters_dir)

        Dir.glob(File.join(chapters_dir, '*.md'))
      end
    end
  end
end

Eidos::Producer.register(:chapter, Eidos::Producers::ChapterProducer)
