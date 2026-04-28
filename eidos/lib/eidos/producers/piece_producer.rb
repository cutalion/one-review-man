# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'securerandom'
require 'yaml'
require 'eidos/form_registry'
require 'eidos/piece'
require 'eidos/prompt_utils'
require 'eidos/validation_utils'
require 'eidos/canon_delta'
require 'eidos/audit_log'

module Eidos
  module Producers
    # Generic producer for any form in the FormRegistry. Replaces the
    # book-era "one hand-coded generator per content type" pattern with
    # a single producer that reads the form's template, assembles the
    # prompt, calls the LLM, strips the optional ---CANON-DELTA--- tail,
    # and writes the piece file.
    #
    # MVP (US1) scope: text forms; tail block is recognized and stripped
    # but not yet applied to canon (US3 hooks in the CanonDelta.apply!
    # call). Image / script forms are produced identically to text forms
    # in MVP — the form category just drives the output directory.
    #
    # DI via keyword args (Principle III). Constructor defaults delegate
    # to sensible production-grade collaborators so callers that only
    # need the happy path don't have to wire anything.
    class PieceProducer
      DELTA_SENTINEL = '---CANON-DELTA---'

      attr_reader :world_path, :form_registry

      def initialize(world_path:, llm_service:, form_registry: nil, bible: nil, # rubocop:disable Metrics/ParameterLists
                     canon: nil, audit_log: nil, output_adapter: nil,
                     prompt_provider: nil, world_config: nil)
        @world_path = File.expand_path(world_path)
        @llm_service = llm_service
        @form_registry = form_registry || FormRegistry.new(world_path: @world_path)
        @bible = bible
        @canon = canon
        @audit_log = audit_log
        @output_adapter = output_adapter
        @prompt_provider = prompt_provider
        @world_config = world_config
      end

      # MVP public API.
      #
      # form   — form name (String). Must be registered.
      # prompt — user guidance passed into the template's {USER_PROMPT}.
      # length — optional override; falls back to form.default_length, then
      #          for the chapter form to world_config.chapter_length_target.
      #
      # Returns the produced Piece instance; writes its file to disk unless
      # dry_run: true (US3 — MVP always writes).
      def produce(form:, prompt:, length: nil, dry_run: false)
        form_obj = @form_registry.find(form.to_s)

        target_length = resolve_length(form_obj, length)
        canon_context_text = build_canon_context(form_obj)
        full_prompt = fill_template(form_obj, prompt, target_length, canon_context_text)

        raw_output = @llm_service.generate_text(prompt: full_prompt)
        delta = CanonDelta.parse(raw_output)
        body = delta.body

        piece = build_piece(form_obj, body)

        if dry_run
          $stdout.puts body
          $stdout.puts
          $stdout.puts raw_output.split(/^#{Regexp.escape(CanonDelta::SENTINEL)}\s*$/m, 2).last.to_s.empty? ? '' : "#{CanonDelta::SENTINEL}\n#{raw_output.split(/^#{Regexp.escape(CanonDelta::SENTINEL)}\s*$/m, 2).last}"
          return piece
        end

        piece.instance_variable_set(:@canon_delta_ref, delta.id) if @bible && @audit_log
        write_piece_file(piece, body)
        apply_delta(delta, piece)
        piece
      end

      private

      def resolve_length(form_obj, explicit)
        return explicit if explicit

        # Chapter form intentionally delegates length to world config
        # (FR-004 / SC-002: preserve pre-014 behavior).
        if form_obj.name == 'chapter' && @world_config.respond_to?(:chapter_length_target)
          target = @world_config.chapter_length_target
          return target if target
        end

        return form_obj.default_length if form_obj.default_length

        form_obj.default_shape
      end

      def build_canon_context(form_obj)
        return '' if form_obj.canon_context.include?(:none)
        return '' unless @bible

        slices = []
        form_obj.canon_context.each do |key|
          case key
          when :all_characters
            slices << characters_block
          when :all_locations
            slices << locations_block
          when :recent_events
            slices << recent_events_block
          when :current_chapter
            slices << current_chapter_block
          end
        end
        slices.reject { |s| s.nil? || s.empty? }.join("\n\n")
      end

      def characters_block
        return nil unless @bible.respond_to?(:characters)

        chars = @bible.characters.map do |c|
          "- #{c['name'] || c[:name]}: #{c['description'] || c[:description]}"
        rescue StandardError
          nil
        end.compact
        chars.empty? ? nil : "Characters:\n#{chars.join("\n")}"
      end

      def locations_block
        return nil unless @bible.respond_to?(:locations)

        locs = @bible.locations.map do |l|
          "- #{l['name'] || l[:name]}"
        rescue StandardError
          nil
        end.compact
        locs.empty? ? nil : "Locations:\n#{locs.join("\n")}"
      end

      def recent_events_block
        nil # US3 wires this up against story_bible.facts['events'].
      end

      def current_chapter_block
        nil # US2/US3: surface the latest chapter summary.
      end

      def fill_template(form_obj, user_prompt, length, canon_context_text)
        template = form_obj.prompt_template
        placeholders = {
          'USER_PROMPT' => user_prompt.to_s,
          'LENGTH_TARGET' => length.to_s,
          'CANON_CONTEXT' => canon_context_text.to_s
        }
        # Templates use single-brace {PLACEHOLDER} — plain string substitution.
        result = template.dup
        placeholders.each { |k, v| result.gsub!("{#{k}}", v) }
        result
      end

      def split_delta(raw)
        return [raw.to_s, nil] unless raw.to_s.include?(DELTA_SENTINEL)

        body, tail = raw.to_s.split(/^#{Regexp.escape(DELTA_SENTINEL)}\s*$/m, 2)
        [body.to_s.rstrip, tail]
      end

      def build_piece(form_obj, body)
        id = form_obj.name == 'chapter' ? next_chapter_id : generate_ulid
        Piece.new(
          id: id,
          form: form_obj.name,
          category: form_obj.category,
          generated_date: Date.today,
          canon_version: current_canon_version,
          length_measured: measure_length(form_obj, body),
          canon_status: :applied
        )
      end

      def apply_delta(delta, piece)
        return unless @bible && @audit_log

        engine_bible = if @bible.respond_to?(:engine_bible)
                         @bible.engine_bible
                       else
                         @bible
                       end
        before = current_canon_version
        delta.apply!(
          bible: engine_bible,
          audit_log: @audit_log,
          canon_version_before: before,
          canon_version_after: current_canon_version,
          piece_id: piece.id,
          world_path: @world_path
        )
        piece.instance_variable_set(:@canon_delta_ref, delta.id)
      end

      def next_chapter_id
        dir = File.join(@world_path, 'content', 'chapters')
        return '001' unless Dir.exist?(dir)

        nums = Dir.glob(File.join(dir, '*.md')).map { |p| File.basename(p)[/^(\d{3})-chapter\.md$/, 1].to_i }
        format('%03d', (nums.max || 0) + 1)
      end

      def generate_ulid
        # Lightweight ULID-ish id: timestamp + random, lexicographically sortable.
        SecureRandom.uuid.tr('-', '').upcase.slice(0, 26)
      end

      def current_canon_version
        return 'unversioned' unless @canon.respond_to?(:current_version)

        @canon.current_version || 'unversioned'
      rescue StandardError
        'unversioned'
      end

      def measure_length(form_obj, body)
        case form_obj.category
        when :text
          body.to_s.split(/\s+/).reject(&:empty?).length
        when :script
          body.to_s.scan(/PANEL\s+\d+/i).length
        when :image
          body.to_s.length
        else
          body.to_s.split(/\s+/).length
        end
      end

      def write_piece_file(piece, body)
        target = target_path(piece)
        FileUtils.mkdir_p(File.dirname(target))
        piece.instance_variable_set(:@content_path, target)

        front_matter = piece.to_frontmatter
        File.write(target, "#{front_matter.to_yaml}---\n\n#{body.rstrip}\n")
      end

      def target_path(piece)
        if piece.form == 'chapter'
          File.join(@world_path, 'content', 'chapters', "#{piece.id}-chapter.md")
        else
          File.join(@world_path, 'content', 'pieces', piece.form, "#{piece.id}.md")
        end
      end
    end
  end
end
