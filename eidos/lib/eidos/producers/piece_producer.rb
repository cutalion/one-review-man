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
require 'eidos/world_state'

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

        # 018a (FR-001): dispatch on form schema. structured_output forms
        # (chapter) get a JSON-envelope LLM call; everything else stays on
        # the existing plain-text path with a `---CANON-DELTA---` tail.
        if form_obj.structured_output?
          begin
            structured = @llm_service.generate_chapter_structured(full_prompt, {})
          rescue StandardError => e
            # Per contracts/chapter-piece-parity.md §"Failure modes":
            # malformed envelope opens one parse-drop AuditFinding and
            # propagates the error. No piece file, no delta file, no
            # revision advance — the audit log is the user-visible signal.
            open_structured_parse_drop(e, form_obj)
            raise
          end
          # Structured-output envelope contract: title/summary/content/new_characters
          # are required. Missing fields = malformed envelope.
          unless structured.is_a?(Hash) && %w[title summary content].all? { |k| !structured[k].to_s.empty? }
            open_structured_parse_drop(
              RuntimeError.new("structured envelope missing required field(s) in #{structured.inspect}"),
              form_obj
            )
            raise Eidos::LLMService::LLMError, 'structured-output envelope missing one of {title, summary, content}'
          end
          body = structured['content'].to_s
          delta = build_delta_from_structured(structured)
          piece_extras = {
            title: structured['title'].to_s,
            summary: structured['summary'].to_s,
            chapter_number: next_chapter_number
          }
        else
          raw_output = @llm_service.generate_text(prompt: full_prompt)
          delta = CanonDelta.parse(raw_output)
          body = delta.body
          piece_extras = {}
        end

        if dry_run
          piece = build_piece(form_obj, body, piece_extras: piece_extras)
          $stdout.puts body
          # Dry-run prints both the body and the delta tail so the user can
          # eyeball what would have been applied.
          unless delta.empty?
            $stdout.puts
            $stdout.puts CanonDelta::SENTINEL
            tail_sections = {
              'new_characters' => delta.new_characters,
              'new_locations' => delta.new_locations,
              'new_facts' => delta.new_facts,
              'new_events' => delta.new_events,
              'new_relationships' => delta.new_relationships,
              'entity_updates' => delta.entity_updates
            }
            $stdout.puts tail_sections.to_yaml.sub(/^---\s*\n/, '')
          end
          return piece
        end

        # 018a: apply the delta FIRST so the revision counter advances
        # before we read it for the piece's canon_version frontmatter.
        # piece_id is generated upfront because apply_delta needs it for
        # audit-log linkage.
        piece_id = generate_piece_id(form_obj, piece_extras)
        apply_delta(delta, piece_id) if @bible && @audit_log

        piece = build_piece(form_obj, body, piece_id: piece_id, piece_extras: piece_extras)
        piece.instance_variable_set(:@canon_delta_ref, delta.id) if @bible && @audit_log
        write_piece_file(piece, body)
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

      def build_piece(form_obj, body, piece_id: nil, piece_extras: {})
        id = piece_id || generate_piece_id(form_obj, piece_extras)
        Piece.new(
          id: id,
          form: form_obj.name,
          category: form_obj.category,
          generated_date: Date.today,
          canon_version: current_canon_version,
          length_measured: measure_length(form_obj, body),
          canon_status: :applied,
          title: piece_extras[:title],
          summary: piece_extras[:summary],
          chapter_number: piece_extras[:chapter_number]
        )
      end

      # 018a (FR-002 / contract): chapter id is a hash (like every other
      # form); chapter_number is a separate integer field that drives the
      # `NNN-chapter.md` filename.
      def generate_piece_id(_form_obj, _piece_extras = {})
        generate_ulid
      end

      def open_structured_parse_drop(error, form_obj)
        return unless @audit_log
        require 'eidos/audit_finding'
        @audit_log.append(AuditFinding.open(
                            kind: 'parse-drop',
                            piece_id: '(unwritten)',
                            canon_version_before: safe_current_revision,
                            canon_version_after: safe_current_revision,
                            explanation: "#{form_obj.name} produce: malformed structured envelope (#{error.class}: #{error.message})"
                          ))
      end

      def safe_current_revision
        Eidos::WorldState.new(world_path: @world_path).current_revision
      rescue StandardError
        nil
      end

      # Synthesize a CanonDelta from the chapter form's structured-output
      # envelope. Currently only `new_characters` is mapped (matches the
      # mock LLM's generate_chapter_structured envelope); the structured
      # path leaves the other delta sections empty unless the LLM returns
      # them. Producers that want to extract more should extend this method
      # rather than adding a side-channel — the canon-delta record is the
      # canonical user-visible signal.
      def build_delta_from_structured(structured)
        sections = {
          'new_characters' => Array(structured['new_characters']).compact,
          'new_locations' => Array(structured['new_locations']).compact,
          'new_facts' => Array(structured['new_facts']).compact,
          'new_events' => Array(structured['new_events']).compact,
          'new_relationships' => Array(structured['new_relationships']).compact,
          'entity_updates' => Array(structured['entity_updates']).compact
        }
        # Bundle into the same ---CANON-DELTA--- envelope that
        # CanonDelta.parse consumes, so id-derivation, drop handling, and
        # parse_error normalization stay uniform across forms.
        body = structured['content'].to_s.rstrip
        raw = "#{body}\n\n#{CanonDelta::SENTINEL}\n#{sections.to_yaml.sub(/^---\s*\n/, '')}"
        CanonDelta.parse(raw)
      end

      def apply_delta(delta, piece_id)
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
          canon_version_after: nil, # resolved post-advance inside apply!
          piece_id: piece_id,
          world_path: @world_path
        )
      end

      # 018a: returns the next sequential chapter NUMBER (Integer). The
      # zero-padded `NNN` filename is derived from this in #target_path.
      def next_chapter_number
        dir = File.join(@world_path, 'content', 'chapters')
        return 1 unless Dir.exist?(dir)

        nums = Dir.glob(File.join(dir, '*.md')).map { |p| File.basename(p)[/^(\d{3})-chapter\.md$/, 1].to_i }
        (nums.max || 0) + 1
      end

      def generate_ulid
        # Lightweight ULID-ish id: timestamp + random, lexicographically sortable.
        SecureRandom.uuid.tr('-', '').upcase.slice(0, 26)
      end

      # FR-010: piece frontmatter `canon_version` is the integer global
      # revision (post-018a), or the snapshot label string when --snapshot
      # is pinned. The literal string 'unversioned' is never returned for
      # newly produced pieces — if WorldState raises CorruptWorldError,
      # propagate (banned-pattern: no silent degraded value).
      def current_canon_version
        if @canon.respond_to?(:current_version) && (label = safe_snapshot_label)
          return label
        end

        Eidos::WorldState.new(world_path: @world_path).current_revision
      end

      def safe_snapshot_label
        @canon.current_version
      rescue StandardError
        nil
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
          # 018a contract: chapter filename is `NNN-chapter.md` derived
          # from chapter_number, NOT from the (hash) id.
          number = piece.chapter_number || piece.id.to_i
          File.join(@world_path, 'content', 'chapters', "#{format('%03d', number)}-chapter.md")
        else
          File.join(@world_path, 'content', 'pieces', piece.form, "#{piece.id}.md")
        end
      end
    end
  end
end
