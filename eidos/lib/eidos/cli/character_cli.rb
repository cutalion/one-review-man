# frozen_string_literal: true

require 'thor'
require 'eidos/cli/sdk_helpers'
require 'eidos/cli/unknown_command_help'

module Eidos
  module CLI
    # SDK-based CLI for character operations.
    class CharacterCli < Thor
      extend Eidos::CLI::UnknownCommandHelp
      include SdkHelpers

      # See PieceCli for context: Thor 1.5+ `tree` command misrenders under
      # --help for `*Cli`-suffixed classes. Drop the inherited command.
      remove_command :tree

      class_option 'world-dir', aliases: ['-w'], type: :string,
                                desc: 'Path to the world directory'

      desc 'list', 'List all characters'
      def list
        world = resolve_world(options)
        chars = world.bible.characters.to_a

        if chars.empty?
          say 'No characters found.', :yellow
          return
        end

        say "Characters (#{chars.length}):", :cyan
        chars.each { |c| say "  #{c.id}: #{c.name}", :green }
      end

      desc 'show ID', 'Show character details'
      def show(id)
        world = resolve_world(options)
        character = world.bible.characters[id]

        unless character
          say "Character '#{id}' not found.", :red
          exit 1
        end

        say "Character: #{character.name}", :cyan
        character.to_h.each do |key, value|
          next if key == 'id'

          say "  #{key}: #{value}"
        end
      end

      desc 'update ID [FIELD=VALUE...]', 'Update a character'
      method_option :reason, type: :string, desc: 'Reason for the change'
      def update(id, *field_values)
        world = resolve_world(options)
        character = world.bible.characters[id]

        unless character
          say "Character '#{id}' not found.", :red
          exit 1
        end

        changes = {}
        field_values.each do |fv|
          key, value = fv.split('=', 2)
          changes[key] = value if key && value
        end

        character.update(changes, reason: options[:reason])
        say "Updated #{id}", :green
      end
    end
  end
end
