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
        show_canon_revision(abs_root)
        pieces_by_form = enumerate_pieces_by_form(abs_root)
        show_pieces_by_form(pieces_by_form)
        missing_fields = show_configuration_status(config)
        show_file_structure_status(abs_root)
        show_next_step_hint(pieces_by_form, missing_fields)
        show_recent_pieces(abs_root, pieces_by_form)

        say "\n#{'=' * 50}", :cyan
      end

      # 018a (FR-009): show the global canon revision in `world status`.
      # Reads via Eidos::WorldState which transparently handles the
      # in-place migration for legacy worlds (FR-006).
      def show_canon_revision(abs_root)
        require 'eidos/world_state'
        revision = Eidos::WorldState.new(world_path: abs_root).current_revision
        say "Canon revision: #{revision}"
      rescue Eidos::WorldState::CorruptWorldError => e
        say "Canon revision: (unavailable — #{e.message})", :yellow
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

      # Feature 015 US6: enumerate pieces on disk by form. Chapters live
      # under content/chapters/ (legacy layout); all other forms live
      # under content/pieces/<form>/. Returns a {form => count} hash
      # sorted by form name for deterministic output.
      def enumerate_pieces_by_form(world_path)
        counts = {}

        chapter_dir = File.join(world_path, 'content', 'chapters')
        if Dir.exist?(chapter_dir)
          chapter_count = Dir.glob(File.join(chapter_dir, '*.md'))
                             .count { |f| !f.end_with?('.ru.md') }
          counts['chapter'] = chapter_count if chapter_count.positive?
        end

        pieces_root = File.join(world_path, 'content', 'pieces')
        if Dir.exist?(pieces_root)
          Dir.children(pieces_root).sort.each do |form|
            form_dir = File.join(pieces_root, form)
            next unless File.directory?(form_dir)

            form_count = Dir.glob(File.join(form_dir, '*.md')).count
            counts[form] = form_count if form_count.positive?
          end
        end

        counts.sort.to_h
      end

      def show_pieces_by_form(pieces_by_form)
        say "\n[Pieces by form]", :cyan
        if pieces_by_form.empty?
          say '  (none yet)', :yellow
          say '  Total: 0', :yellow
          return
        end

        width = pieces_by_form.keys.map(&:length).max + 1
        pieces_by_form.each do |form, count|
          label = "#{form}:".ljust(width + 1)
          say "  #{label} #{count}", :green
        end
        say "  Total: #{pieces_by_form.values.sum}", :yellow
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

      # Feature 015 US6 + contracts/cli-flags.md: the "next step" block is
      # form-agnostic. When no pieces exist we recommend `produce piece`
      # generically; when some exist we stay silent (or surface metadata
      # gaps). Chapters are never the default suggestion.
      def show_next_step_hint(pieces_by_form, missing_fields)
        say "\n[Next step]", :cyan
        if pieces_by_form.empty?
          say '  No pieces yet. Run:', :yellow
          say '    eidos produce piece --form <form> --prompt "…"', :blue
          say '  See `eidos produce --help` for available forms.', :yellow
        elsif missing_fields.any?
          say '  Metadata gaps remain — edit data/world_config.yml or re-run', :yellow
          say '    world new --quick --genre … --style … --setting … --theme …', :yellow
        else
          say '  World ready. Produce another piece or run `eidos canon review`.', :green
        end
      end

      # Feature 015 US6: show up to three most-recently-modified pieces
      # from any form. Falls back to silence when no pieces exist (the
      # [Next step] block already covers the empty case).
      def show_recent_pieces(abs_root, pieces_by_form)
        return if pieces_by_form.empty?

        files = []
        chapter_dir = File.join(abs_root, 'content', 'chapters')
        files += Dir.glob(File.join(chapter_dir, '*.md')).reject { |f| f.end_with?('.ru.md') } if Dir.exist?(chapter_dir)
        pieces_root = File.join(abs_root, 'content', 'pieces')
        files += Dir.glob(File.join(pieces_root, '*', '*.md')) if Dir.exist?(pieces_root)

        return if files.empty?

        say "\nRecent Pieces:", :cyan
        files.sort_by { |f| File.mtime(f) }.last(3).each do |file|
          rel = file.sub(%r{\A#{Regexp.escape(abs_root)}/?}, '')
          say "  #{rel}", :blue
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
