# frozen_string_literal: true

require 'yaml'

module Eidos
  # Represents a single chapter in a world.
  # Read from markdown files with YAML front matter.
  class Chapter
    attr_reader :chapter_number, :title, :content, :summary, :characters, :path

    def initialize(chapter_number:, title:, content:, summary: nil, characters: [], path: nil)
      @chapter_number = chapter_number
      @title = title
      @content = content
      @summary = summary
      @characters = characters
      @path = path
    end

    # Parse a chapter from a markdown file with YAML front matter.
    def self.from_file(file_path)
      raw = File.read(file_path)
      front_matter, body = parse_front_matter(raw)

      new(
        chapter_number: front_matter['chapter_number'] || extract_number_from_path(file_path),
        title: front_matter['title'] || 'Untitled',
        content: body,
        summary: front_matter['summary'],
        characters: front_matter['characters'] || [],
        path: file_path
      )
    end

    def self.parse_front_matter(raw)
      if raw.start_with?("---\n")
        parts = raw.split("---\n", 3)
        if parts.length >= 3
          front_matter = YAML.safe_load(parts[1]) || {}
          body = parts[2].strip
          return [front_matter, body]
        end
      end
      [{}, raw.strip]
    end

    def self.extract_number_from_path(path)
      basename = File.basename(path)
      match = basename.match(/^(\d{3})-chapter/)
      match ? match[1].to_i : 0
    end

    def translations
      @translations ||= {}
    end
  end
end
