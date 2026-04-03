# frozen_string_literal: true

module Eidos
  module Storage
    # Contract module for revision storage adapters.
    # All revision storage backends must implement these methods.
    module RevisionStorage
      REQUIRED_METHODS = %i[
        record history get latest
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
