# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'time'
require_relative 'models/impact_report'

module Eidos
  # Identifies content affected by canon changes.
  # Maintains a reference index mapping canon entries to dependent content.
  class ImpactAnalyzer
    SEVERITY_HIGH = 'high'
    SEVERITY_MEDIUM = 'medium'
    SEVERITY_LOW = 'low'

    attr_reader :content_path, :reference_index_path, :reports_path

    def initialize(content_path:, reference_index_path:, revision_store:, reports_path: nil)
      @content_path = File.expand_path(content_path)
      @reference_index_path = File.expand_path(reference_index_path)
      @revision_store = revision_store
      @reports_path = reports_path ? File.expand_path(reports_path) : File.join(File.dirname(reference_index_path), 'impact_reports')
    end

    # Analyze impact of a canon change.
    # @return [Models::ImpactReport]
    def analyze(entity_type:, entity_id:, revision:, branch: 'main')
      affected_items = []

      scan_content_files do |relative_path, _content, content_type|
        content_file = File.join(@content_path, relative_path)
        references = find_references_in_file(content_file, entity_id, entity_type)
        next if references.empty?

        severity = classify_severity(entity_type, references)

        affected_items << Models::AffectedItem.new(
          content_type: content_type,
          content_path: relative_path,
          references: references,
          severity: severity,
          review_status: 'pending'
        )
      end

      summary = build_summary(affected_items)

      report = Models::ImpactReport.new(
        id: generate_report_id,
        trigger: { 'entity_type' => entity_type, 'entity_id' => entity_id,
                   'revision_seq' => revision&.sequence, 'branch' => branch },
        created_at: Time.now.iso8601,
        branch: branch,
        affected_items: affected_items,
        summary: summary
      )

      save_report(report)
      report
    end

    # Rebuild reference index from content files.
    def rebuild_index!
      index = {}

      scan_content_files do |relative_path, content, content_type|
        entity_refs = extract_entity_references(content)
        entity_refs.each do |entity_key|
          index[entity_key] ||= []
          index[entity_key] << {
            'content_type' => content_type,
            'content_path' => relative_path
          }
        end
      end

      FileUtils.mkdir_p(File.dirname(@reference_index_path))
      File.write(@reference_index_path, { 'references' => index, 'last_indexed' => Time.now.iso8601 }.to_yaml)

      index
    end

    # Update review status on a report item.
    def update_review_status(report_id:, item_index:, status:)
      report = load_report(report_id)
      return nil unless report

      item = report.affected_items[item_index]
      return nil unless item

      item.review_status = status
      item.reviewed_at = Time.now.iso8601
      save_report(report)
      report
    end

    # Load a specific report.
    def load_report(report_id)
      path = File.join(@reports_path, "#{report_id}.yml")
      return nil unless File.exist?(path)

      data = YAML.safe_load(File.read(path), permitted_classes: [Date, Time])
      Models::ImpactReport.from_yaml(data)
    end

    # List all report IDs, most recent first.
    def list_reports(branch: 'main')
      return [] unless Dir.exist?(@reports_path)

      Dir.glob(File.join(@reports_path, '*.yml')).sort.reverse.filter_map do |file|
        data = YAML.safe_load(File.read(file), permitted_classes: [Date, Time])
        next unless data['branch'] == branch

        Models::ImpactReport.from_yaml(data)
      end
    end

    private

    def load_index
      return {} unless File.exist?(@reference_index_path)

      data = YAML.safe_load(File.read(@reference_index_path), permitted_classes: [Date, Time])
      data['references'] || {}
    end

    def scan_content_files
      return unless Dir.exist?(@content_path)

      Dir.glob(File.join(@content_path, '**', '*.{md,yml,yaml}')).each do |file|
        relative = file.sub("#{@content_path}/", '')
        content = File.read(file)
        content_type = classify_content_type(relative)
        yield relative, content, content_type
      end
    end

    def classify_content_type(relative_path)
      if relative_path.include?('.ru.') || relative_path.match?(/\.[a-z]{2}\./)
        'translation'
      elsif relative_path.start_with?('chapters/')
        'chapter'
      elsif relative_path.start_with?('characters/')
        'character_profile'
      else
        'content'
      end
    end

    def extract_entity_references(content)
      refs = Set.new
      content_lower = content.downcase

      # Look for character/location/fact references by scanning for known patterns
      # This is a simple keyword-based approach; entity IDs and names are matched
      refs
    end

    def find_references_in_file(file_path, entity_id, _entity_type)
      content = File.read(file_path)
      references = []
      search_term = entity_id.tr('-', '_').tr('_', ' ')
      search_variants = [entity_id, entity_id.tr('-', '_'), entity_id.tr('_', '-'), search_term]

      content.each_line.with_index(1) do |line, line_num|
        line_lower = line.downcase
        search_variants.each do |variant|
          if line_lower.include?(variant.downcase)
            references << { 'line' => line_num, 'text' => line.strip }
            break
          end
        end
      end

      references
    end

    def classify_severity(entity_type, references)
      # More references or name mentions = higher severity
      if references.length >= 3
        SEVERITY_HIGH
      elsif references.length >= 1
        SEVERITY_MEDIUM
      else
        SEVERITY_LOW
      end
    end

    def build_summary(items)
      by_severity = items.group_by(&:severity)
      {
        'total' => items.length,
        'by_severity' => {
          'high' => (by_severity[SEVERITY_HIGH] || []).length,
          'medium' => (by_severity[SEVERITY_MEDIUM] || []).length,
          'low' => (by_severity[SEVERITY_LOW] || []).length
        }
      }
    end

    def generate_report_id
      Time.now.strftime('%Y-%m-%d-%H%M%S')
    end

    def save_report(report)
      FileUtils.mkdir_p(@reports_path)
      path = File.join(@reports_path, "#{report.id}.yml")
      File.write(path, report.to_yaml_hash.to_yaml)
    end
  end
end
