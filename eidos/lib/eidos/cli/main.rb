# frozen_string_literal: true

require 'thor'
require 'eidos/version'

module Eidos
  module CLI
    # Top-level CLI router for the unified `eidos` command.
    # Delegates to subcommand classes.
    class Main < Thor
      def self.exit_on_failure?
        true
      end

      desc 'version', 'Show version'
      def version
        puts "eidos #{Eidos::VERSION}"
      end

      map %w[--version -v] => :version
    end
  end
end

# Load and register subcommands.
# During transition, these are the existing CLI classes.
# They will be replaced one by one with SDK-based versions.
require 'eidos/cli/world'
require 'eidos/cli/bible'
require 'eidos/cli/canon'
require 'eidos/cli/produce'
require 'eidos/cli/translate'
require 'eidos/cli/publish'
require 'eidos/cli/chapter_cli'

module Eidos
  module CLI
    class Main
      desc 'world SUBCOMMAND ...ARGS', 'Manage worlds'
      subcommand 'world', Eidos::CLI::World

      desc 'bible SUBCOMMAND ...ARGS', 'Manage the Story Bible'
      subcommand 'bible', Eidos::CLI::Bible

      desc 'canon SUBCOMMAND ...ARGS', 'Manage canon versioning'
      subcommand 'canon', Eidos::CLI::Canon

      desc 'produce SUBCOMMAND ...ARGS', 'Generate content'
      subcommand 'produce', Eidos::CLI::Produce

      desc 'translate SUBCOMMAND ...ARGS', 'Translate content'
      subcommand 'translate', Eidos::CLI::Translate

      desc 'publish SUBCOMMAND ...ARGS', 'Publish content'
      subcommand 'publish', Eidos::CLI::Publish

      # New SDK-based subcommands
      desc 'chapter SUBCOMMAND ...ARGS', 'Chapter operations'
      subcommand 'chapter', Eidos::CLI::ChapterCli
    end
  end
end
