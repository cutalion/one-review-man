# frozen_string_literal: true

module Eidos
  module Storage
    # Contract module for entity storage adapters.
    # All entity storage backends must implement these methods.
    module EntityStorage
      REQUIRED_METHODS = %i[
        all_characters get_character save_character list_characters
        all_locations get_location save_location
        all_facts get_facts_by_category add_fact search_facts
        all_relationships get_relationships_for add_relationship
        all_plot_threads active_plot_threads add_plot_thread
        setup
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
