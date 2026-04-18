# frozen_string_literal: true

require 'yaml'
require 'time'
require 'fileutils'
require 'securerandom'
require_relative 'validation_utils'
require_relative 'audit_finding'

module Eidos
  # The structured bible-changes record that accompanies every produced piece.
  # See specs/014-storyworld-pivot/contracts/canon-delta.md.
  #
  # Lifecycle:
  #   [parse]─ok──► created ──apply!──► applied ──revert!──► reverted
  #          └─err─► created (parse_error set, always opens :malformed-delta)
  class CanonDelta
    SENTINEL = '---CANON-DELTA---'
    SECTIONS = %w[new_characters new_locations new_facts new_events
                  new_relationships entity_updates].freeze

    attr_reader :id, :body, :parse_error, :applied_at, :reverted_at,
                :piece_id, :new_characters, :new_locations, :new_facts,
                :new_events, :new_relationships, :entity_updates

    def self.parse(raw_text)
      raw = raw_text.to_s
      return new(body: raw.rstrip, parse_error: build_doc_parse_error('missing sentinel ---CANON-DELTA---')) unless raw.include?(SENTINEL)

      body, tail = raw.split(/^#{Regexp.escape(SENTINEL)}\s*$/m, 2)
      body = body.to_s.rstrip
      tail = tail.to_s.strip

      begin
        doc = YAML.safe_load(tail, permitted_classes: [Date, Time, Symbol])
      rescue Psych::SyntaxError => e
        return new(body: body, parse_error: build_doc_parse_error("YAML parse error: #{e.message}"))
      end

      return new(body: body, parse_error: build_doc_parse_error('delta document must be a YAML mapping')) unless doc.is_a?(Hash)

      sections = {}
      all_drops = []
      SECTIONS.each do |key|
        entries, drops = normalize_section(doc[key], key)
        sections[key] = entries
        all_drops.concat(drops)
      end

      parse_error =
        if all_drops.empty?
          nil
        else
          { 'summary' => summarize_drops(all_drops), 'drops' => all_drops }
        end

      new(body: body, parse_error: parse_error, sections: sections)
    end

    # Feature 015 US1: the on-disk `parse_error` shape is now a Hash
    # `{summary, drops}`. Legacy deltas serialized under 014 carry it as
    # a bare String — normalize those into the new shape on read so
    # downstream code only handles one schema. Data-model §1 BC rules.
    def self.normalize_parse_error(raw)
      case raw
      when nil, false then nil
      when Hash
        h = raw.transform_keys(&:to_s)
        {
          'summary' => h['summary'].to_s,
          'drops' => Array(h['drops']).map { |d| d.transform_keys(&:to_s) }
        }
      when String
        raw.empty? ? nil : { 'summary' => raw, 'drops' => [] }
      else
        { 'summary' => raw.to_s, 'drops' => [] }
      end
    end

    # Reconstruct a CanonDelta from its persisted YAML (see #to_hash).
    # Used by `eidos canon revert` to load the on-disk record.
    def self.from_hash(hash)
      h = hash.transform_keys(&:to_s)
      sections = SECTIONS.to_h { |k| [k, Array(h[k])] }
      new(
        body: h['body'].to_s,
        parse_error: h['parse_error'],
        sections: sections,
        id: h['id'],
        applied_at: h['applied_at'],
        reverted_at: h['reverted_at'],
        piece_id: h['piece_id']
      )
    end

    def self.load(world_path, id)
      path = File.join(world_path, 'data', 'canon_deltas', "#{id}.yml")
      return nil unless File.exist?(path)

      raw = YAML.safe_load_file(path, permitted_classes: [Date, Time, Symbol]) || {}
      from_hash(raw)
    end

    # Feature 015 US1: returns [normalized_entries, drops]. The caller
    # (CanonDelta.parse) aggregates all sections' drops into a single
    # parse_error record. No stderr warning is emitted — the drops are
    # the user-visible signal. See data-model.md §1.
    def self.normalize_section(value, section_name)
      return [[], []] if value.nil?
      return [[], []] unless value.is_a?(Array)

      entries = []
      drops = []
      value.each do |entry|
        unless entry.is_a?(Hash)
          drops << {
            'section' => section_name,
            'value' => entry,
            'reason' => "expected mapping, got #{entry.class}"
          }
          next
        end
        normalized = entry.transform_keys(&:to_s)
        normalized['id'] = ValidationUtils.slugify(normalized['id']) if normalized.key?('id') && normalized['id']
        # US2 (T043): derive id from name when absent so the entity actually
        # persists. If both are absent, record a drop and skip.
        if SECTIONS_WITH_NAMED_ENTITIES.include?(section_name) && (normalized['id'].nil? || normalized['id'].to_s.empty?)
          name = normalized['name']
          if name.nil? || name.to_s.strip.empty?
            drops << {
              'section' => section_name,
              'value' => entry,
              'reason' => 'missing both id and name'
            }
            next
          end
          normalized['id'] = ValidationUtils.slugify(name)
        end
        normalized['entity_id'] = ValidationUtils.slugify(normalized['entity_id']) if section_name == 'entity_updates' && normalized.key?('entity_id') && normalized['entity_id']
        entries << normalized
      end
      [entries, drops]
    end

    SECTIONS_WITH_NAMED_ENTITIES = %w[new_characters new_locations].freeze
    private_constant :SECTIONS_WITH_NAMED_ENTITIES

    def self.summarize_drops(drops)
      sections = drops.map { |d| d['section'] }.uniq
      "#{drops.size} entr#{drops.size == 1 ? 'y' : 'ies'} dropped across #{sections.join(', ')}"
    end

    def self.build_doc_parse_error(summary)
      { 'summary' => summary, 'drops' => [] }
    end

    def initialize(body:, parse_error:, sections: nil, id: nil,
                   applied_at: nil, reverted_at: nil, piece_id: nil)
      @id = id || generate_id
      @body = body.to_s
      @parse_error = self.class.normalize_parse_error(parse_error)
      @applied_at = applied_at
      @reverted_at = reverted_at
      @piece_id = piece_id
      sections ||= SECTIONS.to_h { |k| [k, []] }
      @new_characters    = sections['new_characters']
      @new_locations     = sections['new_locations']
      @new_facts         = sections['new_facts']
      @new_events        = sections['new_events']
      @new_relationships = sections['new_relationships']
      @entity_updates    = sections['entity_updates']
    end

    def empty?
      [@new_characters, @new_locations, @new_facts, @new_events,
       @new_relationships, @entity_updates].all? { |l| Array(l).empty? }
    end

    def to_hash
      {
        'id' => @id,
        'piece_id' => @piece_id,
        'created_at' => @created_at || Time.now.utc,
        'applied_at' => @applied_at,
        'reverted_at' => @reverted_at,
        'parse_error' => @parse_error,
        'new_characters' => @new_characters,
        'new_locations' => @new_locations,
        'new_facts' => @new_facts,
        'new_events' => @new_events,
        'new_relationships' => @new_relationships,
        'entity_updates' => @entity_updates
      }
    end

    # Apply the delta. Behavior by @parse_error shape (feature 015 US1):
    #   - nil                                        → apply normally
    #   - {summary, drops: [...]} with drops present → apply well-formed
    #     siblings AND open one :parse-drop finding per drop
    #   - {summary} without drops (document-level)   → open :malformed-delta
    #     and return (no entities to apply)
    # Otherwise: records changes under an in-memory rollback journal; any
    # raise reverts everything. Conflicts are recorded as findings but do
    # NOT raise (optimistic; FR-020).
    def apply!(bible:, audit_log:, canon_version_before:, canon_version_after:,
               piece_id:, world_path: nil)
      @piece_id = piece_id.to_s
      world_path ||= audit_log.respond_to?(:world_path) ? audit_log.world_path : nil

      if document_level_parse_error?
        open_malformed_finding(audit_log, canon_version_before, canon_version_after)
        return
      end

      applied_actions = []
      conflict_findings = []
      begin
        @new_characters.each do |entry|
          conflict = apply_character(bible, entry, applied_actions)
          conflict_findings << conflict if conflict
        end
        @new_locations.each do |entry|
          conflict = apply_location(bible, entry, applied_actions)
          conflict_findings << conflict if conflict
        end
        @new_facts.each do |entry|
          apply_fact(bible, entry, applied_actions)
        end
        @new_relationships.each do |entry|
          apply_relationship(bible, entry, applied_actions)
        end
        # Events are facts under category "events"
        @new_events.each do |entry|
          apply_event(bible, entry, applied_actions)
        end
        @entity_updates.each do |entry|
          conflict = apply_update(bible, entry, applied_actions)
          conflict_findings << conflict if conflict
        end
      rescue StandardError => e
        rollback!(bible, applied_actions)
        raise e
      end

      @applied_at = Time.now.utc
      conflict_findings.each do |info|
        audit_log.append(AuditFinding.open(
                           kind: 'conflict',
                           piece_id: @piece_id,
                           canon_delta_id: @id,
                           canon_version_before: canon_version_before,
                           canon_version_after: canon_version_after,
                           explanation: info
                         ))
      end

      parse_drops.each do |drop|
        audit_log.append(AuditFinding.open(
                           kind: 'parse-drop',
                           piece_id: @piece_id,
                           canon_delta_id: @id,
                           canon_version_before: canon_version_before,
                           canon_version_after: canon_version_after,
                           explanation: format_parse_drop(drop)
                         ))
      end

      persist!(world_path) if world_path
    end

    def revert!(bible:, audit_log:, finding:, world_path: nil)
      world_path ||= audit_log.respond_to?(:world_path) ? audit_log.world_path : nil
      introduced_ids = collect_entity_ids
      orphan_pieces = detect_orphans_by_refs(world_path, introduced_ids)

      @new_characters&.each { |entry| delete_entity_file(bible, 'characters', entry['id']) }
      @new_locations&.each  { |entry| delete_entity_file(bible, 'locations',  entry['id']) }

      @entity_updates.each do |entry|
        next unless entry['entity_id'] && entry['attribute']

        case entry['entity_kind'].to_s
        when 'character'
          existing = bible.get_character(entry['entity_id']) || {}
          reverted = existing.merge(entry['attribute'].to_s => entry['old_value'])
          bible.save_character(entry['entity_id'], reverted)
        when 'location'
          existing = bible.get_location(entry['entity_id']) || {}
          reverted = existing.merge(entry['attribute'].to_s => entry['old_value'])
          bible.save_location(entry['entity_id'], reverted)
        end
      end

      @reverted_at = Time.now.utc
      audit_log.close(finding.id, resolution: 'revert', at: @reverted_at)

      orphan_pieces.each do |piece_id|
        audit_log.append(AuditFinding.open(
                           kind: 'orphaned-reference',
                           piece_id: piece_id,
                           canon_delta_id: nil,
                           canon_version_before: finding.canon_version_after,
                           canon_version_after: finding.canon_version_after,
                           explanation: "Piece #{piece_id} referenced entities rolled back by revert of piece #{@piece_id}."
                         ))
      end

      persist!(world_path) if world_path
    end

    def persist!(world_path)
      dir = File.join(world_path, 'data', 'canon_deltas')
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "#{@id}.yml"), to_hash.to_yaml)
    end

    private

    # A document-level parse issue (bad YAML, missing sentinel, non-mapping
    # top-level) has a summary but NO entries could be recovered. A
    # drops-only parse_error means the doc parsed fine and well-formed
    # sibling entries should still apply.
    def document_level_parse_error?
      return false if @parse_error.nil?

      drops = Array(@parse_error['drops'])
      drops.empty? && !@parse_error['summary'].to_s.empty?
    end

    def parse_drops
      return [] if @parse_error.nil?

      Array(@parse_error['drops'])
    end

    def format_parse_drop(drop)
      section = drop['section']
      value = drop['value']
      reason = drop['reason']
      rendered = value.inspect
      "Dropped #{section} entry #{rendered} (reason: #{reason})"
    end

    def apply_character(bible, entry, journal)
      id = entry['id']
      if id.nil? || id.to_s.empty?
        raise ArgumentError, 'canon-delta new_characters entry reached apply with no id ' \
                             '(should have been dropped in normalize_section)'
      end

      existing = bible.get_character(id)
      conflict = conflict_message(existing, entry, 'character', id)

      journal << { kind: :character, id: id, prior: existing }
      merged = (existing || {}).merge(entry)
      bible.save_character(id, merged)
      conflict
    end

    def apply_location(bible, entry, journal)
      id = entry['id']
      if id.nil? || id.to_s.empty?
        raise ArgumentError, 'canon-delta new_locations entry reached apply with no id ' \
                             '(should have been dropped in normalize_section)'
      end

      existing = bible.get_location(id)
      conflict = conflict_message(existing, entry, 'location', id)

      journal << { kind: :location, id: id, prior: existing }
      merged = (existing || {}).merge(entry)
      bible.save_location(id, merged)
      conflict
    end

    def apply_fact(bible, entry, journal)
      category = entry['category'] || entry['kind'] || 'facts'
      id = entry['id'] || entry['subject'] || SecureRandom.hex(4)
      journal << { kind: :fact, category: category, id: id }
      bible.add_fact(category.to_s, id.to_s, entry)
    end

    def apply_event(bible, entry, journal)
      id = entry['id'] || "event-#{SecureRandom.hex(4)}"
      journal << { kind: :fact, category: 'events', id: id }
      bible.add_fact('events', id.to_s, entry)
    end

    def apply_relationship(bible, entry, journal)
      journal << { kind: :relationship, entry: entry }
      data = {
        'character1' => entry['subject_id'],
        'character2' => entry['object_id'],
        'type' => entry['kind']
      }
      bible.add_relationship(data)
    end

    def apply_update(bible, entry, journal)
      kind = entry['entity_kind'].to_s
      id = entry['entity_id']
      attr = entry['attribute'].to_s
      if id.nil? || id.to_s.empty?
        raise ArgumentError, 'canon-delta entity_updates entry reached apply with no entity_id ' \
                             '(should have been dropped in normalize_section)'
      end
      raise ArgumentError, 'canon-delta entity_updates entry reached apply with empty attribute' if attr.empty?

      existing = case kind
                 when 'character' then bible.get_character(id)
                 when 'location' then bible.get_location(id)
                 end
      prior_value = existing&.[](attr)
      conflict = nil
      conflict = "entity_update on #{kind}/#{id}.#{attr}: expected #{entry['old_value'].inspect}, actual #{prior_value.inspect}. Applied #{entry['new_value'].inspect}." if entry.key?('old_value') && prior_value != entry['old_value']

      journal << { kind: :update, entity_kind: kind, id: id, attribute: attr, prior: prior_value, prior_record: existing }
      updated = (existing || {}).merge(attr => entry['new_value'])
      case kind
      when 'character' then bible.save_character(id, updated)
      when 'location' then bible.save_location(id, updated)
      end
      conflict
    end

    def conflict_message(existing, entry, kind, id)
      return nil if existing.nil?

      diffs = entry.except('id').select { |k, v| existing[k] && existing[k] != v }
      return nil if diffs.empty?

      "#{kind}/#{id} collision: #{diffs.keys.join(', ')} differ from canon. Applied new values (optimistic)."
    end

    def rollback!(bible, journal)
      journal.reverse_each do |action|
        case action[:kind]
        when :character
          if action[:prior].nil?
            delete_entity_file(bible, 'characters', action[:id])
          else
            bible.save_character(action[:id], action[:prior])
          end
        when :location
          if action[:prior].nil?
            delete_entity_file(bible, 'locations', action[:id])
          else
            bible.save_location(action[:id], action[:prior])
          end
        when :update
          prior = action[:prior_record]
          next if prior.nil?

          if action[:entity_kind] == 'character'
            bible.save_character(action[:id], prior)
          elsif action[:entity_kind] == 'location'
            bible.save_location(action[:id], prior)
          end
        end
      end
    end

    def open_malformed_finding(audit_log, before, after)
      audit_log.append(AuditFinding.open(
                         kind: 'malformed-delta',
                         piece_id: @piece_id,
                         canon_delta_id: @id,
                         canon_version_before: before,
                         canon_version_after: after,
                         explanation: "Delta could not be parsed: #{@parse_error}"
                       ))
    end

    def delete_entity_file(bible, dir_name, id)
      return if id.nil? || id.to_s.empty?

      dir = case dir_name
            when 'characters' then bible.characters_dir if bible.respond_to?(:characters_dir)
            when 'locations' then bible.locations_dir if bible.respond_to?(:locations_dir)
            end
      return unless dir

      path = File.join(dir, "#{id}.yml")
      FileUtils.rm_f(path)
      bible.invalidate_cache if bible.respond_to?(:invalidate_cache)
    end

    def collect_entity_ids
      {
        characters: Array(@new_characters).map { |e| e['id'] }.compact,
        locations: Array(@new_locations).map { |e| e['id'] }.compact
      }
    end

    def detect_orphans_by_refs(world_path, introduced)
      return [] unless world_path

      deltas_dir = File.join(world_path, 'data', 'canon_deltas')
      return [] unless Dir.exist?(deltas_dir)

      Dir.glob(File.join(deltas_dir, '*.yml')).filter_map do |path|
        raw = YAML.safe_load_file(path, permitted_classes: [Date, Time]) || {}
        next nil if raw['id'] == @id
        next nil if raw['applied_at'].nil?
        next nil if @applied_at && raw['applied_at'].is_a?(Time) && raw['applied_at'] <= @applied_at

        referenced = references_any?(raw, introduced)
        referenced ? raw['piece_id'].to_s : nil
      end.uniq
    end

    def references_any?(raw_delta, introduced)
      char_ids = introduced[:characters]
      loc_ids = introduced[:locations]
      return false if char_ids.empty? && loc_ids.empty?

      Array(raw_delta['entity_updates']).any? do |u|
        kind = u['entity_kind'].to_s
        id = u['entity_id'].to_s
        (kind == 'character' && char_ids.include?(id)) ||
          (kind == 'location' && loc_ids.include?(id))
      end ||
        Array(raw_delta['new_relationships']).any? do |r|
          char_ids.include?(r['subject_id'].to_s) || char_ids.include?(r['object_id'].to_s)
        end ||
        Array(raw_delta['new_events']).any? do |e|
          Array(e['who']).any? { |w| char_ids.include?(w.to_s) }
        end
    end

    def generate_id
      "01#{SecureRandom.hex(12).upcase}"
    end
  end
end
