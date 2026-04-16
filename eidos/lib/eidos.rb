# frozen_string_literal: true

require_relative 'eidos/version'
require_relative 'eidos/sdk_configuration'

# Eidos - IP World Engine
# Main entry point for the Eidos gem
module Eidos
  class << self
    def configuration
      @configuration ||= SdkConfiguration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = SdkConfiguration.new
    end
  end
end
