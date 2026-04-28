# frozen_string_literal: true

require 'thor'
require 'eidos/cli/sdk_helpers'
require 'eidos/cli/unknown_command_help'

module Eidos
  module CLI
    # SDK-based CLI for chapter operations.
    class ChapterCli < Thor
      extend Eidos::CLI::UnknownCommandHelp
      include SdkHelpers

      # See PieceCli for context: Thor 1.5+ `tree` command misrenders under
      # --help for `*Cli`-suffixed classes. Drop the inherited command.
      remove_command :tree

      class_option 'world-dir', aliases: ['-w'], type: :string,
                                desc: 'Path to the world directory'

      desc 'list', 'List all chapters'
      def list
        world = resolve_world(options)
        chapters = world.chapters.to_a

        if chapters.empty?
          say 'No chapters generated yet.', :yellow
          return
        end

        say "Chapters (#{chapters.length}):", :cyan
        chapters.each do |ch|
          say format('  %03d: %s', ch.chapter_number, ch.title), :green
        end
      end

      desc 'show NUMBER', 'Show chapter details'
      def show(number)
        world = resolve_world(options)
        chapter = world.chapters[number.to_i]

        unless chapter
          say "Chapter #{number} not found.", :red
          exit 1
        end

        say "Chapter #{chapter.chapter_number}: #{chapter.title}", :cyan
        say "Summary: #{chapter.summary}" if chapter.summary
        say "Characters: #{chapter.characters.join(', ')}" if chapter.characters.any?
        say "Words: #{chapter.content.split.length}"
      end
    end
  end
end
