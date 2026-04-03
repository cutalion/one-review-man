# frozen_string_literal: true

module Eidos
  module Storage
    # Contract module for snapshot storage adapters.
    # All snapshot storage backends must implement these methods.
    module SnapshotStorage
      REQUIRED_METHODS = %i[
        create list get latest snapshot_data
      ].freeze

      def self.included(base)
        REQUIRED_METHODS.each do |method|
          unless base.method_defined?(method) || base.private_method_defined?(method)
            base.define_method(method) do |*_args, **_kwargs|
              raise NotImplementedError, "#{self.class}##{method} must be implemented"
            end
          end
        end
      end
    end
  end
end
