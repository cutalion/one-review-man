# frozen_string_literal: true

require 'securerandom'
require 'time'

module Eidos
  # A single post-hoc finding against applied canon. Opened by
  # CanonDelta#apply! (conflict, malformed-delta) or #revert!
  # (orphaned-reference). Closed by canon review resolution commands.
  #
  # Per contracts/audit-finding.md the finding is the unit of work for
  # `canon review`; append-only on disk, closed-in-place.
  class AuditFinding
    KINDS = %w[conflict malformed-delta orphaned-reference].freeze
    STATUSES = %w[open closed].freeze
    RESOLUTIONS = %w[revert accept patch-canon other].freeze

    attr_reader :id, :kind, :status, :piece_id, :canon_delta_id,
                :canon_version_before, :canon_version_after,
                :explanation, :severity_hint, :created_at,
                :resolved_at, :resolution

    def self.open(kind:, piece_id:, canon_version_before:, canon_version_after:, # rubocop:disable Metrics/ParameterLists
                  explanation:, canon_delta_id: nil, severity_hint: 'warn',
                  id: nil, created_at: nil)
      new(
        id: id || generate_id,
        kind: kind,
        status: 'open',
        piece_id: piece_id,
        canon_delta_id: canon_delta_id,
        canon_version_before: canon_version_before,
        canon_version_after: canon_version_after,
        explanation: explanation,
        severity_hint: severity_hint,
        created_at: created_at || Time.now.utc,
        resolved_at: nil,
        resolution: nil
      )
    end

    def self.from_hash(hash)
      h = hash.transform_keys(&:to_s)
      new(
        id: h['id'],
        kind: h['kind'],
        status: h['status'] || 'open',
        piece_id: h['piece_id'].to_s,
        canon_delta_id: h['canon_delta_id'],
        canon_version_before: h['canon_version_before'],
        canon_version_after: h['canon_version_after'],
        explanation: h['explanation'],
        severity_hint: h['severity_hint'] || 'warn',
        created_at: coerce_time(h['created_at']),
        resolved_at: coerce_time(h['resolved_at']),
        resolution: h['resolution']
      )
    end

    def self.generate_id
      "01#{SecureRandom.hex(12).upcase}"
    end

    def self.coerce_time(val)
      return nil if val.nil?
      return val if val.is_a?(Time)

      Time.parse(val.to_s)
    rescue ArgumentError
      nil
    end

    def initialize(id:, kind:, status:, piece_id:, canon_version_before:, # rubocop:disable Metrics/ParameterLists
                   canon_version_after:, explanation:, canon_delta_id: nil,
                   severity_hint: 'warn', created_at: nil,
                   resolved_at: nil, resolution: nil)
      @id = id
      @kind = kind.to_s
      @status = status.to_s
      @piece_id = piece_id.to_s
      @canon_delta_id = canon_delta_id
      @canon_version_before = canon_version_before
      @canon_version_after = canon_version_after
      @explanation = explanation.to_s
      @severity_hint = severity_hint.to_s
      @created_at = created_at || Time.now.utc
      @resolved_at = resolved_at
      @resolution = resolution
    end

    def open?
      @status == 'open'
    end

    def closed?
      @status == 'closed'
    end

    def close!(resolution:, at: Time.now.utc)
      raise ArgumentError, 'resolution is required when closing a finding' if resolution.nil? || resolution.to_s.empty?

      @resolution = resolution.to_s
      @resolved_at = at
      @status = 'closed'
      self
    end

    def to_hash
      {
        'id' => @id,
        'kind' => @kind,
        'status' => @status,
        'piece_id' => @piece_id,
        'canon_delta_id' => @canon_delta_id,
        'canon_version_before' => @canon_version_before,
        'canon_version_after' => @canon_version_after,
        'explanation' => @explanation,
        'severity_hint' => @severity_hint,
        'created_at' => @created_at,
        'resolved_at' => @resolved_at,
        'resolution' => @resolution
      }
    end

    def ==(other)
      other.is_a?(AuditFinding) && to_hash == other.to_hash
    end
  end
end
