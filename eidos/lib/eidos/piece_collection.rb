# frozen_string_literal: true

require_relative 'piece'

module Eidos
  # Collection of pieces in a world. Enumerable, filterable by form
  # and canon_status. Reads piece files under:
  #   worlds/<name>/content/chapters/???-chapter.md   (form=chapter, back-compat)
  #   worlds/<name>/content/pieces/<form>/*.md        (all other forms)
  #
  # Discovery is lazy and rescans on each access; there are small number
  # of pieces in a typical world, so no cache is needed.
  class PieceCollection
    include Enumerable

    def initialize(world_path:)
      @world_path = world_path
    end

    def each(&)
      load_all.each(&)
    end

    def [](piece_id)
      find { |p| p.id == piece_id.to_s }
    end

    def by_form(form_name)
      name = form_name.to_s
      select { |p| p.form == name }
    end

    def applied
      select(&:applied?)
    end

    def reverted
      select(&:reverted?)
    end

    private

    def load_all
      files = chapter_files + piece_files
      files.map { |f| Piece.from_file(f) }.sort_by(&:generated_date)
    end

    def chapter_files
      dir = File.join(@world_path, 'content', 'chapters')
      return [] unless Dir.exist?(dir)

      Dir.glob(File.join(dir, '???-chapter.md'))
    end

    def piece_files
      root = File.join(@world_path, 'content', 'pieces')
      return [] unless Dir.exist?(root)

      Dir.glob(File.join(root, '*', '*.md'))
    end
  end
end
