# frozen_string_literal: true

module BookCore
  class DuplicateSnapshotError < StandardError; end
  class InvalidSnapshotNameError < StandardError; end
  class SnapshotNotFoundError < StandardError; end
  class SnapshotCorruptError < StandardError; end
  class FrozenSnapshotError < StandardError; end
end
