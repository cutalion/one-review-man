# frozen_string_literal: true

require 'thor'
require 'eidos/cli/sdk_helpers'

module Eidos
  module CLI
    # SDK-based CLI for piece operations — the generic counterpart to
    # ChapterCli. `piece list` surfaces every piece in the world (chapter
    # or not); `piece show` surfaces a single piece by id.
    class PieceCli < Thor
      include SdkHelpers

      # Thor 1.5+ ships a built-in `tree` command, but its inherited basename
      # renders as "piece_cli tree" under --help for this subclass (the name
      # doesn't underscore cleanly to the registered subcommand name "piece").
      # Drop the inherited command to keep --help clean.
      remove_command :tree

      class_option 'world-dir', aliases: ['-w'], type: :string,
                                desc: 'Path to the world directory'

      desc 'list', 'List all pieces in the world (grouped by form)'
      method_option :form, type: :string, desc: 'Filter by form name'
      method_option :status, type: :string,
                             desc: 'Filter by canon_status (applied|reverted)'
      def list
        world = resolve_world(options)
        pieces = world.pieces.to_a
        pieces = pieces.select { |p| p.form == options[:form] } if options[:form]
        pieces = pieces.select { |p| p.canon_status.to_s == options[:status] } if options[:status]

        if pieces.empty?
          say 'No pieces found.', :yellow
          return
        end

        say "Pieces (#{pieces.length}):", :cyan
        say '  FORM       ID             STATUS     DATE         CANON_VERSION', :white
        pieces.each do |p|
          say format('  %<form>-10s %<id>-14s %<status>-10s %<date>-12s %<canon>s',
                     form: p.form, id: p.id, status: p.canon_status,
                     date: p.generated_date, canon: p.canon_version), :green
        end
      end

      desc 'show PIECE_ID', 'Show a piece by id'
      def show(piece_id)
        world = resolve_world(options)
        piece = world.pieces[piece_id]

        unless piece
          say "Piece '#{piece_id}' not found.", :red
          exit 1
        end

        say "Piece #{piece.id} (form=#{piece.form}, category=#{piece.category})", :cyan
        say "  status: #{piece.canon_status}"
        say "  canon_version: #{piece.canon_version}"
        say "  generated_date: #{piece.generated_date}"
        say "  length_measured: #{piece.length_measured}" if piece.length_measured
        say "  path: #{piece.content_path}" if piece.content_path
      end
    end
  end
end
