# frozen_string_literal: true

require 'fileutils'
require 'yaml'
require 'tempfile'
require_relative 'audit_finding'

module Eidos
  # Per-world append-only store for AuditFindings.
  # File: worlds/<name>/data/audit_log/findings.yml (YAML array).
  # Single-process CLI assumed; atomic write via tempfile + rename.
  class AuditLog
    attr_reader :world_path

    def initialize(world_path:)
      @world_path = File.expand_path(world_path)
    end

    def path
      File.join(@world_path, 'data', 'audit_log', 'findings.yml')
    end

    def append(finding)
      data = load_raw
      data << finding.to_hash
      write_raw(data)
      finding
    end

    def all
      load_raw.filter_map { |h| safe_from_hash(h) }
    end

    def open
      all.select(&:open?)
    end

    def closed
      all.select(&:closed?)
    end

    def by_piece(piece_id)
      all.select { |f| f.piece_id == piece_id.to_s }
    end

    def find(id)
      all.find { |f| f.id == id }
    end

    # Close a finding in place. If already closed with the same resolution,
    # no-op. Other transitions are not allowed (open → closed only).
    def close(id, resolution:, at: Time.now.utc)
      data = load_raw
      idx = data.find_index { |h| (h['id'] || h[:id]) == id }
      raise ArgumentError, "No finding with id #{id.inspect}" unless idx

      entry = data[idx].transform_keys(&:to_s)
      return AuditFinding.from_hash(entry) if entry['status'] == 'closed' && entry['resolution'] == resolution.to_s

      finding = AuditFinding.from_hash(entry)
      finding.close!(resolution: resolution, at: at)
      data[idx] = finding.to_hash
      write_raw(data)
      finding
    end

    private

    def load_raw
      return [] unless File.exist?(path)

      YAML.safe_load_file(path, permitted_classes: [Date, Time]) || []
    rescue Psych::SyntaxError => e
      warn "⚠️  Audit log at #{path} is malformed: #{e.message}"
      []
    end

    def write_raw(data)
      FileUtils.mkdir_p(File.dirname(path))
      Tempfile.create(['findings', '.yml'], File.dirname(path)) do |tmp|
        tmp.write(data.to_yaml)
        tmp.flush
        File.rename(tmp.path, path)
      end
    end

    def safe_from_hash(raw)
      h = raw.transform_keys(&:to_s)
      return nil unless AuditFinding::KINDS.include?(h['kind'])

      AuditFinding.from_hash(h)
    rescue StandardError => e
      warn "⚠️  Skipping malformed audit entry: #{e.message}"
      nil
    end
  end
end
