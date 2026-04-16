# frozen_string_literal: true

module Eidos
  # Global SDK configuration. Set via Eidos.configure block.
  # This is separate from Eidos::Configuration which handles per-project settings merging.
  class SdkConfiguration
    attr_accessor :worlds_path, :storage_backend

    def initialize
      reset!
    end

    def reset!
      @worlds_path = './worlds'
      @storage_backend = :yaml_file
    end
  end
end
