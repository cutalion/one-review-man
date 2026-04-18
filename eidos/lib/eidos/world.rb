# frozen_string_literal: true

require_relative 'world_config'
require_relative 'chapter_collection'
require_relative 'piece_collection'
require_relative 'form_registry'
require_relative 'bible'
require_relative 'canon'
require_relative 'audit_log'

module Eidos
  class WorldNotFoundError < StandardError; end

  # Root SDK object. Entry point for all world operations.
  # Wraps the existing engine classes behind a clean public API.
  class World
    attr_reader :path, :name

    def initialize(name_or_path = nil)
      @path = resolve_path(name_or_path)
      @name = File.basename(@path)
      @world_config = WorldConfig.load_from_project(@path)
    end

    def status
      chapters_dir = File.join(@path, 'content', 'chapters')
      chapter_count = if Dir.exist?(chapters_dir)
                        Dir.glob(File.join(chapters_dir, '???-chapter.md')).length
                      else
                        0
                      end

      {
        title: @world_config.title,
        author: @world_config.author,
        genre: @world_config.genre,
        chapters: chapter_count,
        current_chapter: @world_config.current_chapter
      }
    end

    def chapters
      @chapters ||= ChapterCollection.new(world_path: @path)
    end

    def pieces
      @pieces ||= PieceCollection.new(world_path: @path)
    end

    def forms
      @forms ||= FormRegistry.new(world_path: @path)
    end

    def bible
      @bible ||= Bible.new(world_path: @path)
    end

    def canon
      @canon ||= Canon.new(world_path: @path)
    end

    def audit_log
      @audit_log ||= AuditLog.new(world_path: @path)
    end

    private

    def resolve_path(name_or_path)
      return detect_from_cwd if name_or_path.nil?

      expanded = File.expand_path(name_or_path)
      return expanded if world_dir?(expanded)

      search_paths = [
        File.expand_path(File.join(Eidos.configuration.worlds_path, name_or_path)),
        File.expand_path(File.join('~/.eidos/worlds', name_or_path))
      ]

      found = search_paths.find { |p| world_dir?(p) }
      return found if found

      raise WorldNotFoundError, "World '#{name_or_path}' not found. Searched: #{search_paths.join(', ')}"
    end

    def detect_from_cwd
      dir = Dir.pwd
      return dir if world_dir?(dir)

      raise WorldNotFoundError,
            'Not in a world directory (missing data/world_config.yml). Pass a world name or path.'
    end

    def world_dir?(dir)
      return false unless Dir.exist?(dir)

      %w[world_config.yml world_metadata.yml].any? do |marker|
        File.exist?(File.join(dir, 'data', marker))
      end
    end
  end
end
