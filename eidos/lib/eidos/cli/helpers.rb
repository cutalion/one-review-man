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
        target = config.get('world')&.dig('target_chapters')
        if target
          say "Progress: #{current}/#{target} chapters", :yellow
        else
          say "Progress: #{current} chapter#{current == 1 ? '' : 's'} written", :yellow
        end
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

        show_unspecified_metadata_warning(config)

        missing_fields
      end

      # Feature 015 US4: when metadata fields carry the literal sentinel
      # "unspecified", surface them to the user as an action item. Silent
      # ignores are explicitly banned (CLAUDE.md §"Banned patterns").
      UNSPECIFIED_SENTINEL = 'unspecified'
      private_constant :UNSPECIFIED_SENTINEL

      def show_unspecified_metadata_warning(config)
        unspecified = []
        unspecified << 'genre'   if config.story_genre.to_s == UNSPECIFIED_SENTINEL
        unspecified << 'style'   if config.story_style.to_s == UNSPECIFIED_SENTINEL
        unspecified << 'setting' if config.story_setting.to_s == UNSPECIFIED_SENTINEL
        unspecified << 'theme'   if config.primary_theme.to_s == UNSPECIFIED_SENTINEL
        return if unspecified.empty?

        say "  ⚠️  Unspecified fields need your attention: #{unspecified.join(', ')}.", :yellow
        say '      Edit data/world_config.yml or re-run `world new --quick --genre … --style … --setting … --theme …`.', :yellow
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
          value = case field
                  when 'themes'      then config.primary_theme
                  when 'genre'       then config.genre
                  when 'humor_style' then config.humor_style
                  when 'setting'     then config.setting
                  end

          if metadata_field_missing?(value)
            missing_fields << display_name
          else
            complete_fields << "#{display_name}: #{value}"
          end
        end

        [missing_fields, complete_fields]
      end

      # "Missing" in this renderer means *blank* — the field has no value at
      # all. The literal sentinel "unspecified" (written by `world new --quick`
      # without an explicit --genre/--style/--setting/--theme flag, feature
      # 015 US4) renders verbatim as the field value and is surfaced by
      # `show_unspecified_metadata_warning` as a separate action item. That
      # way the status output is honest ("Genre: unspecified", not "Genre:
      # Not set") and the user still gets a visible nudge to fill it in.
      def metadata_field_missing?(value)
        value.to_s.strip.empty?
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

      # Feature 015 US4: regex-based premise-inference heuristics were removed.
      # They substituted a real-looking value (e.g. "fiction", "adventure") on
      # any miss, which violates the silent-fallback ban in CLAUDE.md and
      # produced scaffolded worlds that lied about their own genre. Callers
      # that previously relied on `infer_*_from_description` now write the
      # literal sentinel "unspecified" — `world status` surfaces unspecified
      # fields as an action item for the user to fill in explicitly.
    end
  end
end
