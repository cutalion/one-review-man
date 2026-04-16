# frozen_string_literal: true

require 'eidos'

module Eidos
  module CLI
    # Helpers for CLI commands that use the SDK
    module SdkHelpers
      private

      def resolve_world(options)
        world_name = options['world-dir'] || options[:world] || options['w']
        if world_name
          Eidos::World.new(world_name)
        else
          Eidos::World.new
        end
      rescue Eidos::WorldNotFoundError => e
        say e.message, :red
        exit 1
      end
    end
  end
end
