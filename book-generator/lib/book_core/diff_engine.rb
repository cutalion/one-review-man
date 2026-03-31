# frozen_string_literal: true

require_relative 'models/conflict'

module BookCore
  # Computes field-level diffs and detects conflicts between entity snapshots.
  # Works with nested hashes using dot-notation field paths.
  class DiffEngine
    # Compare two snapshots field-by-field.
    # @param snapshot_a [Hash] First snapshot
    # @param snapshot_b [Hash] Second snapshot
    # @return [Hash] field_path => { old: value, new: value }
    def diff(snapshot_a, snapshot_b)
      changes = {}
      all_keys = ((snapshot_a || {}).keys + (snapshot_b || {}).keys).uniq

      all_keys.each do |key|
        val_a = (snapshot_a || {})[key]
        val_b = (snapshot_b || {})[key]
        collect_diffs(key.to_s, val_a, val_b, changes)
      end

      changes
    end

    # Detect field-level conflicts using three-way comparison.
    # A conflict exists only when both ours and theirs modified the same field
    # relative to base.
    # @param base [Hash] Common ancestor snapshot
    # @param ours [Hash] Target branch snapshot
    # @param theirs [Hash] Source branch snapshot
    # @return [Array<Models::Conflict>] List of conflicts
    def find_conflicts(base:, ours:, theirs:)
      ours_changes = diff(base, ours)
      theirs_changes = diff(base, theirs)

      conflicts = []
      common_fields = ours_changes.keys & theirs_changes.keys

      common_fields.each do |field_path|
        ours_new = ours_changes[field_path][:new]
        theirs_new = theirs_changes[field_path][:new]

        next if ours_new == theirs_new

        conflicts << Models::Conflict.new(
          field_path: field_path,
          base_value: ours_changes[field_path][:old],
          ours_value: ours_new,
          theirs_value: theirs_new
        )
      end

      conflicts
    end

    # Three-way merge: auto-merge non-conflicting changes, return conflicts for manual resolution.
    # @param base [Hash] Common ancestor snapshot
    # @param ours [Hash] Target branch snapshot
    # @param theirs [Hash] Source branch snapshot
    # @return [Hash] { merged: Hash, conflicts: Array<Models::Conflict> }
    def three_way_merge(base:, ours:, theirs:)
      ours_changes = diff(base, ours)
      theirs_changes = diff(base, theirs)
      conflicts = find_conflicts(base: base, ours: ours, theirs: theirs)
      conflict_fields = conflicts.map(&:field_path).to_set

      merged = deep_dup(ours)

      theirs_changes.each do |field_path, change|
        next if conflict_fields.include?(field_path)

        set_nested_value(merged, field_path, change[:new])
      end

      { merged: merged, conflicts: conflicts }
    end

    private

    def collect_diffs(prefix, val_a, val_b, changes)
      if val_a.is_a?(Hash) && val_b.is_a?(Hash)
        all_keys = (val_a.keys + val_b.keys).uniq
        all_keys.each do |key|
          collect_diffs("#{prefix}.#{key}", val_a[key], val_b[key], changes)
        end
      elsif val_a != val_b
        changes[prefix] = { old: val_a, new: val_b }
      end
    end

    def set_nested_value(hash, field_path, value)
      parts = field_path.split('.')
      current = hash

      parts[0..-2].each do |part|
        current[part] ||= {}
        current = current[part]
      end

      current[parts.last] = value
    end

    def deep_dup(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
      when Array
        obj.map { |v| deep_dup(v) }
      else
        obj
      end
    end
  end
end
