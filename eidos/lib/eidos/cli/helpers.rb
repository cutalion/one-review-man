# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'yaml'

module Eidos
  module CLI
    # Shared utilities for all CLI subcommands
    module Helpers
      private

      # Non-terminating resolver: returns project root or nil
      def resolve_project_root(candidate = nil)
        candidate ||= Dir.pwd
        data_dir = File.join(candidate, 'data')
        markers = %w[world_config.yml world_metadata.yml]
        return candidate if markers.any? { |m| File.exist?(File.join(data_dir, m)) }

        nil
      end

      def resolve_project_root!(explicit_path = nil, max_attempts = 3)
        candidate = explicit_path || Dir.pwd
        data_dir = File.join(candidate, 'data')
        markers = %w[world_config.yml world_metadata.yml]
        if markers.any? { |m| File.exist?(File.join(data_dir, m)) }
          return File.expand_path(candidate)
        end

        return handle_missing_project_root(max_attempts) if explicit_path

        warn 'Not a world directory (missing data/world_config.yml or data/world_metadata.yml).'
        begin
          path = ask('Path to world directory (leave empty to abort):')
        rescue Interrupt
          warn "\nAborted by user."
          exit 1
        end
        if path && !path.strip.empty?
          path_stripped = path.strip
          unless valid_path_input?(path_stripped)
            warn 'Invalid path provided.'
            return resolve_project_root!(nil, max_attempts - 1) if max_attempts > 1
          end

          expanded_path = File.expand_path(path_stripped)
          return resolve_project_root!(expanded_path, max_attempts - 1) if max_attempts > 1
        end

        warn 'Aborted. Please run in a world directory or pass --world-dir.'
        exit 1
      end

      def handle_missing_project_root(max_attempts)
        if max_attempts <= 1
          warn 'Maximum attempts reached. Aborted.'
          exit 1
        end
        resolve_project_root!(nil, max_attempts - 1)
      end

      def valid_path_input?(path)
        return false if path.nil? || path.empty? || path.include?("\0")
        return false if path.length > 1000

        true
      end

      # Renders a concise status report for a world at the given absolute root.
      def render_status_report(abs_root)
        config = Eidos::WorldConfig.load_from_project(abs_root)
      rescue Eidos::WorldConfig::NotFoundError
        say "No world metadata found. Run 'world init' to create a new world.", :red
      else
        say "\nWorld Status Report", :cyan
        say '=' * 50, :cyan

        show_basic_info(config)
        show_progress_info(config)
        missing_fields = show_configuration_status(config)
        show_file_structure_status(abs_root)
        show_generation_readiness(missing_fields)
        show_recent_chapters(abs_root)

        say "\n#{'=' * 50}", :cyan
      end

      def load_world_metadata(abs_root)
        metadata_path = File.join(abs_root, 'data', 'world_metadata.yml')
        if File.exist?(metadata_path)
          YAML.safe_load_file(metadata_path) || {}
        else
          {}
        end
      end

      def show_basic_info(config)
        say "Title: #{config.title}", :green
        say "Author: #{config.author}", :green
      end

      def show_progress_info(config)
        current = config.current_chapter
        target = config.get('world')&.dig('target_chapters') || 'Not set'
        say "Progress: #{current}/#{target} chapters", :yellow
      end

      def show_configuration_status(config)
        say "\nConfiguration Status:", :cyan

        required_fields = {
          'genre' => 'Genre',
          'humor_style' => 'Writing Style',
          'setting' => 'Setting',
          'themes' => 'Themes'
        }

        missing_fields, complete_fields = check_required_fields_config(config, required_fields)

        complete_fields.each { |field| say "  #{field}", :green }
        missing_fields.each { |field| say "  #{field}: Not set", :red }

        missing_fields
      end

      def check_required_fields(en_metadata, required_fields)
        missing_fields = []
        complete_fields = []

        required_fields.each do |field, display_name|
          if field == 'themes'
            if en_metadata.dig('themes', 'primary').to_s.strip.empty?
              missing_fields << display_name
            else
              complete_fields << "#{display_name}: #{en_metadata.dig('themes', 'primary')}"
            end
          elsif en_metadata[field].to_s.strip.empty?
            missing_fields << display_name
          else
            complete_fields << "#{display_name}: #{en_metadata[field]}"
          end
        end

        [missing_fields, complete_fields]
      end

      def check_required_fields_config(config, required_fields)
        missing_fields = []
        complete_fields = []

        required_fields.each do |field, display_name|
          case field
          when 'themes'
            if config.primary_theme.to_s.strip.empty?
              missing_fields << display_name
            else
              complete_fields << "#{display_name}: #{config.primary_theme}"
            end
          when 'genre'
            if config.genre.to_s.strip.empty?
              missing_fields << display_name
            else
              complete_fields << "#{display_name}: #{config.genre}"
            end
          when 'humor_style'
            if config.humor_style.to_s.strip.empty?
              missing_fields << display_name
            else
              complete_fields << "#{display_name}: #{config.humor_style}"
            end
          when 'setting'
            if config.setting.to_s.strip.empty?
              missing_fields << display_name
            else
              complete_fields << "#{display_name}: #{config.setting}"
            end
          end
        end

        [missing_fields, complete_fields]
      end

      def show_file_structure_status(abs_root)
        say "\nFile Structure:", :cyan
        files_to_check = {
          'data/world_config.yml' => 'World configuration',
          'data/world_state.yml' => 'World state',
          'data/characters.yml' => 'Characters data',
          'data/generation_log.yml' => 'Generation log',
          'data/story_bible' => 'Story Bible',
          'data/strings.yml' => 'Site strings'
        }

        # Legacy check
        if File.exist?(File.join(abs_root, 'data/world_metadata.yml')) && !File.exist?(File.join(abs_root, 'data/world_config.yml'))
          files_to_check['data/world_metadata.yml'] = 'Legacy world metadata'
          files_to_check.delete('data/world_config.yml')
          files_to_check.delete('data/world_state.yml')
        end

        files_to_check.each do |file_path, description|
          full_path = File.join(abs_root, file_path)
          if File.exist?(full_path)
            say "  #{description}", :green
          else
            say "  #{description}: Missing", :red
          end
        end
      end

      def show_generation_readiness(missing_fields)
        say "\nGeneration Readiness:", :cyan
        if missing_fields.empty?
          say '  Ready for chapter generation!', :green
          say '  Run: produce chapter', :blue
        else
          say '  Missing required information for chapter generation', :red
          say '  Fix by running: world init (in new directory) or update metadata manually', :yellow
        end
      end

      def show_recent_chapters(abs_root)
        chapters_dir = File.join(abs_root, 'content', 'chapters')
        return unless Dir.exist?(chapters_dir)

        chapters = Dir.glob(File.join(chapters_dir, '*.md')).reject { |f| f.end_with?('.ru.md') }.sort
        if chapters.any?
          say "\nRecent Chapters:", :cyan
          chapters.last(3).each do |chapter_file|
            chapter_name = File.basename(chapter_file, '.md')
            say "  #{chapter_name}", :blue
          end
        else
          say "\nNo chapters generated yet", :yellow
        end
      end

      public

      def write_yaml_file(path, hash)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, hash.to_yaml)
      end

      def infer_genre_from_description(description)
        return 'fiction' if description.nil? || description.empty?

        desc_lower = description.downcase

        return 'fantasy' if desc_lower.match?(/magic|wizard|dragon|fantasy|realm|quest|enchant/i)
        return 'sci-fi' if desc_lower.match?(/space|universe|robot|future|alien|technology|cyber/i)
        return 'mystery' if desc_lower.match?(/mystery|detective|crime|investigation|murder|secret/i)
        return 'thriller' if desc_lower.match?(/thriller|suspense|danger|chase|escape|survival/i)
        return 'comedy' if desc_lower.match?(/comedy|humor|funny|hilarious|laugh|joke/i)
        return 'romance' if desc_lower.match?(/love|romance|relationship|heart|passion/i)
        return 'horror' if desc_lower.match?(/horror|scary|terror|fear|nightmare|ghost/i)
        return 'adventure' if desc_lower.match?(/adventure|journey|explore|discover|travel/i)

        'fiction'
      end

      def infer_style_from_description(description)
        return 'narrative' if description.nil? || description.empty?

        desc_lower = description.downcase

        return 'humorous' if desc_lower.match?(/funny|comedy|hilarious|humor|laugh|joke|witty/i)
        return 'suspenseful' if desc_lower.match?(/thriller|suspense|mystery|danger|intense/i)
        return 'adventurous' if desc_lower.match?(/adventure|journey|explore|discover|epic|quest/i)
        return 'whimsical' if desc_lower.match?(/magic|fantasy|whimsical|wonder|enchant/i)
        return 'dramatic' if desc_lower.match?(/drama|emotional|intense|powerful|deep/i)
        return 'serious' if desc_lower.match?(/serious|important|critical|professional/i)

        'narrative'
      end

      def infer_setting_from_description(description)
        return 'contemporary setting' if description.nil? || description.empty?

        desc_lower = description.downcase

        return 'magical realm' if desc_lower.match?(/magic|fantasy|realm|kingdom|wizard/i)
        return 'space station' if desc_lower.match?(/space|universe|station|galaxy|cosmos/i)
        return 'futuristic city' if desc_lower.match?(/future|cyber|robot|technology|digital/i)
        return 'modern detective office' if desc_lower.match?(/detective|investigation|crime|police/i)
        return 'parallel universe' if desc_lower.match?(/parallel|universe|dimension|alternate/i)
        return 'medieval world' if desc_lower.match?(/medieval|ancient|historical|past/i)
        return 'mysterious location' if desc_lower.match?(/mystery|secret|hidden|unknown/i)

        'contemporary setting'
      end

      def infer_theme_from_description(description)
        return 'adventure' if description.nil? || description.empty?

        desc_lower = description.downcase

        return 'exploration' if desc_lower.match?(/explore|discover|journey|adventure|travel/i)
        return 'mystery' if desc_lower.match?(/mystery|secret|investigation|unknown|hidden/i)
        return 'magic' if desc_lower.match?(/magic|wizard|spell|enchant|fantasy/i)
        return 'technology' if desc_lower.match?(/technology|digital|cyber|robot|future/i)
        return 'discovery' if desc_lower.match?(/discover|find|reveal|uncover|learn/i)
        return 'friendship' if desc_lower.match?(/friend|together|team|companion|bond/i)
        return 'survival' if desc_lower.match?(/survive|danger|escape|threat|peril/i)

        'adventure'
      end
    end
  end
end
