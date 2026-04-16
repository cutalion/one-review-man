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
require 'eidos/cli/character_cli'
require 'eidos/cli/probe_cli'

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

      desc 'character SUBCOMMAND ...ARGS', 'Character operations'
      subcommand 'character', Eidos::CLI::CharacterCli

      desc 'probe MODEL', 'Smoke-test a provider/model for reachability'
      long_desc <<~LONG
        Sends one tiny, cheap request to the named model and reports
        pass/fail plus latency.

        Credential resolution (first match wins):
          1. --api-key=KEY
          2. -w WORLD_DIR  (reads data/settings.yml providers[<provider>].api_key_env)
          3. ENV[OPENAI_API_KEY] or ENV[OPENROUTER_API_KEY]

        Exits 0 on OK, 1 on FAIL, 2 on config error (missing creds).
      LONG
      method_option :provider,    type: :string, default: 'openai',
                                  desc: 'Provider name: openai or openrouter'
      method_option :'api-key',   type: :string, desc: 'Explicit API key (overrides world settings and ENV)'
      method_option :'base-url',  type: :string, desc: 'Override provider base URL'
      method_option :'world-dir', aliases: '-w', type: :string, desc: "Use this world's settings.yml for creds"
      method_option :timeout,     type: :numeric, default: 60, desc: 'Hard timeout in seconds'
      method_option :metrics,     type: :boolean, default: false, desc: 'Show input/output token counts'
      method_option :json,        type: :boolean, default: false, desc: 'Emit a JSON object instead of human text'
      def probe(model)
        Eidos::CLI::ProbeCli.run(model, options)
      end
    end
  end
end
