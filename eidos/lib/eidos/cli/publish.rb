# frozen_string_literal: true

require 'thor'
require 'eidos/cli/helpers'
require 'eidos/cli/unknown_command_help'
require 'eidos/env_utils'
require 'eidos/prompt_utils'
require 'eidos/story_bible_exporter'

module Eidos
  module CLI
    # CLI commands for publishing (Jekyll site generation)
    class Publish < Thor
      extend Eidos::CLI::UnknownCommandHelp
      include Eidos::CLI::Helpers

      class_option 'world-dir', aliases: ['-w'], type: :string,
                                desc: 'Path to the world directory (defaults to current directory)'

      desc 'jekyll', 'Generate Jekyll static site from world content'
      method_option :dest, aliases: '-d', type: :string,
                           desc: 'Destination directory for the Jekyll site (defaults to ./site)'
      def jekyll(dest = nil)
        world_root = resolve_project_root!(options['world-dir'])
        dest_dir = File.expand_path(dest || options[:dest] || File.join(world_root, 'site'))

        # Prefer local template bundled with this repo layout
        template_root = Eidos::EnvUtils.jekyll_template_path(File.expand_path('../../../templates/jekyll', __dir__))
        unless Dir.exist?(template_root)
          say 'Jekyll site template not found. Set JEKYLL_TEMPLATE_PATH or ensure templates exist at eidos/templates/jekyll.', :red
          exit 1
        end

        # Detect if this is an existing site with custom config BEFORE creating directory
        existing_site = existing_site?(dest_dir)

        FileUtils.mkdir_p(dest_dir)
        if existing_site
          say 'Detected existing Jekyll site - preserving custom configuration', :blue
        else
          say 'Creating new Jekyll site from templates', :green
        end

        # Export Story Bible to Jekyll-compatible format before copying
        if Dir.exist?(File.join(world_root, 'data', 'story_bible'))
          say 'Exporting Story Bible to Jekyll format...', :blue
          exporter = Eidos::StoryBibleExporter.new(project_root: world_root)
          exporter.export_for_jekyll!
        end

        # Copy template (skip content dirs which we handle separately)
        Dir.children(template_root).each do |entry|
          next if %w[_chapters _characters _data].include?(entry)

          src = File.join(template_root, entry)
          dst = File.join(dest_dir, entry)
          if File.directory?(src)
            FileUtils.mkdir_p(dst)
            Dir.glob(File.join(src, '**', '*'), File::FNM_DOTMATCH).each do |path|
              next if ['.', '..'].include?(File.basename(path))

              rel = path.delete_prefix("#{src}/")
              target = File.join(dst, rel)
              if File.directory?(path)
                FileUtils.mkdir_p(target)
              else
                copy_template_with_processing(path, target, world_root, existing_site: existing_site) unless File.exist?(target)
              end
            end
          else
            copy_template_with_processing(src, dst, world_root, existing_site: existing_site) unless File.exist?(dst)
          end
        end

        # Copy book content into site (no symlinks)
        [
          {
            dst_name: '_chapters',
            candidates: [File.join(world_root, '_chapters'), File.join(world_root, 'content', 'chapters')]
          },
          {
            dst_name: '_characters',
            candidates: [File.join(world_root, '_characters'), File.join(world_root, 'content', 'characters')]
          },
          {
            dst_name: '_data',
            candidates: [File.join(world_root, 'data')]
          },
          {
            dst_name: 'assets',
            candidates: [File.join(world_root, 'assets')]
          }
        ].each do |mapping|
          src = mapping[:candidates].find { |p| Dir.exist?(p) }
          dst = File.join(dest_dir, mapping[:dst_name])
          begin
            # Special handling for assets: merge instead of replace
            if mapping[:dst_name] == 'assets'
              FileUtils.mkdir_p(dst)
              if src
                FileUtils.cp_r(Dir.glob("#{src}/*"), dst)
              end
            else
              FileUtils.rm_rf(dst)
              if src
                FileUtils.mkdir_p(File.dirname(dst))
                FileUtils.cp_r(src, dst)
              else
                FileUtils.mkdir_p(dst)
              end
            end
          rescue StandardError => e
            say "Failed to copy #{mapping[:dst_name]}: #{e.message}", :yellow
          end
        end

        say "Jekyll site prepared at: #{dest_dir}", :green
        say 'Run `jekyll build` inside that directory to build the site.'
      end

      private

      def existing_site?(dest_dir)
        # Check for key indicators of an existing custom Jekyll site
        config_file = File.join(dest_dir, '_config.yml')
        return false unless File.exist?(config_file)

        # Check if _config.yml contains hardcoded values (not template placeholders like {{STORY_TITLE}})
        config_content = File.read(config_file)
        has_title = config_content.include?('title:')
        # Check for our specific template placeholders, not Jekyll's {{ site.* }} syntax
        has_template_placeholders = config_content.match(/\{\{[A-Z_]+\}\}/)

        has_title && !has_template_placeholders
      end

      def copy_template_with_processing(src_path, dst_path, world_root, existing_site: false)
        # For existing sites, skip template processing to preserve custom config
        if !existing_site && needs_template_processing?(src_path)
          process_and_copy_template(src_path, dst_path, world_root)
        else
          # Just copy the file without processing placeholders
          FileUtils.cp(src_path, dst_path)
        end
      end

      def needs_template_processing?(file_path)
        # Process markdown files, YAML config files, and other text files that might contain placeholders
        ext = File.extname(file_path).downcase
        filename = File.basename(file_path)
        ['.md', '.yml', '.yaml', '.html', '.txt'].include?(ext) || filename == 'CNAME'
      end

      def process_and_copy_template(src_path, dst_path, world_root)
        # Read template content
        template_content = File.read(src_path)

        # Build placeholders from book metadata
        placeholders = build_jekyll_placeholders(world_root)

        # Special handling for CNAME file - skip if SITE_DOMAIN is empty
        if File.basename(src_path) == 'CNAME'
          site_domain = placeholders['SITE_DOMAIN'].to_s.strip
          if site_domain.empty?
            say 'Skipping CNAME file - no site domain configured', :yellow
            return
          end
        end

        # Process template through PromptUtils
        processed_content = PromptUtils.build_prompt(template_content, placeholders, warn_unused: false)

        # Write processed content
        FileUtils.mkdir_p(File.dirname(dst_path))
        File.write(dst_path, processed_content)
      rescue StandardError => e
        # Fallback to direct copy if processing fails
        say "Warning: Failed to process template #{File.basename(src_path)}: #{e.message}", :yellow
        FileUtils.cp(src_path, dst_path)
      end

      def build_jekyll_placeholders(world_root)
        placeholders = {}
        book_metadata = load_jekyll_metadata(world_root)

        return placeholders unless book_metadata && book_metadata['localized']

        add_english_placeholders(placeholders, book_metadata)
        add_russian_placeholders(placeholders, book_metadata)
        add_genre_description_placeholders(placeholders, book_metadata)
        add_site_configuration_placeholders(placeholders, book_metadata)

        placeholders
      rescue StandardError => e
        say "Warning: Failed to load book metadata for Jekyll placeholders: #{e.message}", :yellow
        {}
      end

      def load_jekyll_metadata(world_root)
        config_path = File.join(world_root, 'data', 'world_config.yml')
        legacy_path = File.join(world_root, 'data', 'world_metadata.yml')
        metadata_path = File.exist?(config_path) ? config_path : legacy_path
        return nil unless File.exist?(metadata_path)

        YAML.safe_load_file(metadata_path)
      end

      def add_english_placeholders(placeholders, book_metadata)
        en_data = book_metadata.dig('localized', 'en')
        return unless en_data

        placeholders.merge!({
                              'STORY_TITLE' => en_data['story_title'] || en_data['title'] || 'Untitled Story',
                              'STORY_AUTHOR' => en_data['author'] || 'Unknown Author',
                              'STORY_GENRE' => en_data['story_genre'] || en_data['genre'] || 'Fiction',
                              'STORY_SUBTITLE' => en_data['subtitle'] || '',
                              'AUTHOR_EMAIL' => en_data['author_email'] || 'author@example.com',
                              'STORY_DESCRIPTION' => en_data['description'] || book_metadata['description'] || 'An AI-generated story'
                            })
      end

      def add_russian_placeholders(placeholders, book_metadata)
        ru_data = book_metadata.dig('localized', 'ru') || {}

        placeholders.merge!({
                              'STORY_TITLE_RU' => ru_data['story_title'] || ru_data['title'] || placeholders['STORY_TITLE'] || 'Untitled Story',
                              'STORY_AUTHOR_RU' => ru_data['author'] || placeholders['STORY_AUTHOR'] || 'Unknown Author',
                              'STORY_GENRE_RU' => ru_data['story_genre'] || ru_data['genre'] || placeholders['STORY_GENRE'] || 'Fiction',
                              'STORY_SUBTITLE_RU' => ru_data['subtitle'] || '',
                              'STORY_GENRE_DESCRIPTION_RU' => build_russian_genre_description(ru_data, placeholders)
                            })
      end

      def build_russian_genre_description(ru_data, placeholders)
        return ru_data['genre_description'] if ru_data['genre_description']
        ru_genre = ru_data['story_genre'] || ru_data['genre']
        return "#{ru_genre} истории" if ru_genre
        return "#{placeholders['STORY_GENRE']} истории" if placeholders['STORY_GENRE']

        'истории'
      end

      def add_genre_description_placeholders(placeholders, book_metadata)
        en_data = book_metadata.dig('localized', 'en')
        return unless en_data

        genre_desc = en_data['genre_description']
        en_genre = en_data['story_genre'] || en_data['genre']
        genre_desc ||= en_genre ? "#{en_genre} story" : 'story'
        placeholders['STORY_GENRE_DESCRIPTION'] = genre_desc
      end

      def add_site_configuration_placeholders(placeholders, book_metadata)
        placeholders.merge!({
                              'SITE_URL' => book_metadata['site_url'] || 'http://example.com',
                              'TWITTER_USERNAME' => book_metadata['twitter_username'] || '',
                              'GITHUB_USERNAME' => book_metadata['github_username'] || '',
                              'SITE_DOMAIN' => book_metadata['site_domain'] || ''
                            })
      end
    end
  end
end
