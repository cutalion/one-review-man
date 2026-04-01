# frozen_string_literal: true

require 'base64'
require 'fileutils'
require 'book_core/producer'
require 'book_core/producer_result'
require 'book_core/character_appearance'
require 'book_core/panel_description_generator'
require 'book_core/models/panel_set'
require 'book_core/story_bible'
require 'book_core/snapshot_store'
require 'book_core/canon_version_reference'
require 'book_core/env_utils'

module BookCore
  module Producers
    class InstagramComicProducer
      include BookCore::Producer

      producer_name :instagram_comic
      producer_description 'Generate comic-style panels from narrative sources'
      default_output_path 'content/comics'

      IMAGE_FORMAT_SIZES = {
        'square' => '1024x1024',
        'portrait' => '1024x1792'
      }.freeze

      DEFAULT_ART_STYLE = 'manga'
      DEFAULT_PANEL_COUNT = 4
      DEFAULT_IMAGE_FORMAT = 'square'

      def initialize(project_root:, llm_service: nil)
        @project_root = File.expand_path(project_root)
        @llm_service = llm_service
      end

      def produce(snapshot: nil, config: {}, output: nil)
        validate!(snapshot: snapshot, config: config, output: output)

        output_dir = output || File.join(@project_root, self.class.default_output_path)
        FileUtils.mkdir_p(output_dir)

        source = config[:source] || config['source']
        art_style = config[:art_style] || config['art_style'] || DEFAULT_ART_STYLE
        panel_count = (config[:panel_count] || config['panel_count'] || DEFAULT_PANEL_COUNT).to_i
        image_format = config[:image_format] || config['image_format'] || DEFAULT_IMAGE_FORMAT
        description_only = config[:description_only] || config['description_only'] || false

        # Read narrative content
        content = read_source_content(source)

        # Extract character appearances
        bible_path = File.join(@project_root, StoryBible::STORY_BIBLE_DIR)
        characters = CharacterAppearance.extract_all(bible_path)

        # Check for existing sidecar with saved descriptions
        sidecar_path = File.join(output_dir, sidecar_filename(source))
        panels = if File.exist?(sidecar_path) && !description_only
                   load_saved_descriptions(sidecar_path)
                 else
                   generate_descriptions(content, characters, panel_count, art_style)
                 end

        # Build panel set
        canon_ver = resolve_canon_version(snapshot)
        panel_set = PanelSet.new(
          source: normalize_source(source),
          art_style: art_style,
          image_format: image_format,
          canon_version: canon_ver,
          panels: panels
        )

        artifacts = []

        # Generate images unless description-only mode
        unless description_only
          generate_images(panel_set, output_dir, source, image_format, art_style, characters)
          artifacts.concat(panels.filter_map { |p| p.image_path && File.join(output_dir, p.image_path) })
        end

        # Save sidecar
        sidecar = panel_set.save_sidecar(output_dir)
        artifacts << sidecar

        ProducerResult.new(
          success: true,
          output_path: output_dir,
          canon_version: canon_ver,
          artifacts: artifacts,
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

      def validate!(snapshot: nil, config: {}, output: nil)
        super

        source = config[:source] || config['source']
        raise ArgumentError, 'source is required' unless source

        source_type = source[:type] || source['type']
        raise ArgumentError, "invalid source type: #{source_type}" unless source_type.to_s == 'chapter'

        source_number = source[:number] || source['number']
        raise ArgumentError, 'source number is required' unless source_number

        chapter_file = find_chapter_file(source_number)
        raise ArgumentError, "source content not found: chapter #{source_number}" unless chapter_file

        panel_count = config[:panel_count] || config['panel_count']
        raise ArgumentError, 'invalid panel_count: must be positive' if panel_count && panel_count.to_i <= 0
      end

      private

      def read_source_content(source)
        number = source[:number] || source['number']
        chapter_file = find_chapter_file(number)
        content = File.read(chapter_file)

        # Strip YAML front matter if present
        if content.start_with?('---')
          parts = content.split('---', 3)
          parts.length >= 3 ? parts[2].strip : content
        else
          content
        end
      end

      def find_chapter_file(number)
        padded = format('%03d', number.to_i)
        chapters_dir = File.join(@project_root, 'content', 'chapters')
        Dir.glob(File.join(chapters_dir, "#{padded}-*.md")).first
      end

      def generate_descriptions(content, characters, panel_count, art_style)
        llm = resolve_llm_service
        generator = PanelDescriptionGenerator.new(llm)
        generator.generate(content: content, characters: characters, panel_count: panel_count, art_style: art_style)
      end

      def load_saved_descriptions(sidecar_path)
        saved = PanelSet.load_sidecar(sidecar_path)
        saved.panels
      end

      def generate_images(panel_set, output_dir, source, image_format, art_style, characters)
        llm = resolve_llm_service
        size = IMAGE_FORMAT_SIZES[image_format] || IMAGE_FORMAT_SIZES[DEFAULT_IMAGE_FORMAT]
        source_number = source[:number] || source['number']

        panel_set.panels.each do |panel|
          prompt = build_image_prompt(panel, art_style, characters)
          image_data = llm.generate_image(prompt, size: size)
          filename = format('panel_%03d_%02d.png', source_number.to_i, panel.sequence)
          save_image(image_data, output_dir, filename)
          panel.image_path = filename
        end
      end

      def build_image_prompt(panel, art_style, characters)
        parts = ["#{art_style} style comic panel."]
        parts << panel.scene_description

        # Inject character appearance for consistency
        panel.characters.each do |char_id|
          appearance = characters[char_id]
          parts << "Character: #{appearance.to_prompt}" if appearance
        end

        parts.join(' ')
      end

      def save_image(image_data, output_dir, filename)
        path = File.join(output_dir, filename)
        if EnvUtils.mock_ai_enabled?
          # Mock mode returns a URL string, write a placeholder file
          File.write(path, "mock_image:#{image_data}")
        else
          File.open(path, 'wb') { |f| f.write(Base64.decode64(image_data)) }
        end
      end

      def resolve_llm_service
        return @llm_service if @llm_service

        require 'book_core/configuration'
        config = BookCore::Configuration.load(@project_root, {})
        BookCore::LLMService.new(config)
      end

      def resolve_canon_version(snapshot_name)
        bible_path = File.join(@project_root, StoryBible::STORY_BIBLE_DIR)
        return 'unversioned' unless Dir.exist?(bible_path)

        store = SnapshotStore.new(story_bible_path: bible_path)
        CanonVersionReference.resolve(snapshot_store: store, explicit_snapshot: snapshot_name)
      rescue SnapshotNotFoundError
        'unversioned'
      end

      def sidecar_filename(source)
        number = source[:number] || source['number'] || 0
        format('panels_%03d.yml', number.to_i)
      end

      def normalize_source(source)
        {
          'type' => (source[:type] || source['type']).to_s,
          'number' => (source[:number] || source['number']).to_i
        }
      end
    end
  end
end

BookCore::Producer.register(:instagram_comic, BookCore::Producers::InstagramComicProducer)
