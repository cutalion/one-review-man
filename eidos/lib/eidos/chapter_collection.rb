# frozen_string_literal: true

require_relative 'chapter'

module Eidos
  # Collection of chapters in a world. Enumerable, indexable by chapter number.
  class ChapterCollection
    include Enumerable

    def initialize(world_path:)
      @chapters_dir = File.join(world_path, 'content', 'chapters')
    end

    def each(&block)
      load_all.each(&block)
    end

    # Access by chapter number (1-based)
    def [](chapter_number)
      path = chapter_path(chapter_number)
      return nil unless File.exist?(path)

      Chapter.from_file(path)
    end

    def last
      files = english_chapter_files
      return nil if files.empty?

      Chapter.from_file(files.last)
    end

    private

    def load_all
      english_chapter_files.map { |f| Chapter.from_file(f) }
    end

    def english_chapter_files
      return [] unless Dir.exist?(@chapters_dir)

      Dir.glob(File.join(@chapters_dir, '???-chapter.md')).sort
    end

    def chapter_path(number)
      File.join(@chapters_dir, format('%03d-chapter.md', number))
    end
  end
end
