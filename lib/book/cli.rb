# frozen_string_literal: true

require 'thor'
require_relative 'cli/version'

module Book
  module CLI
    # Main command-line interface for the `book` tool.
    class Runner < Thor
      class_option :verbose, type: :boolean, desc: 'Enable verbose output'

      desc 'version', 'Print the version information'
      map %w[--version -v] => :version
      def version
        puts VERSION
      end

      def self.exit_on_failure?
        true
      end
    end
  end
end 
