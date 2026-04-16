# frozen_string_literal: true

require_relative 'character_collection'
require_relative 'story_bible'

module Eidos
  # SDK facade for the Story Bible.
  # Wraps the engine's StoryBible with a clean OOP interface.
  class Bible
    attr_reader :engine_bible

    def initialize(world_path:)
      @world_path = world_path
      @engine_bible = StoryBible.new(project_root: world_path)
    end

    def characters
      @characters ||= CharacterCollection.new(bible: self)
    end

    def locations
      @engine_bible.locations
    end

    def facts
      @engine_bible.facts
    end

    def relationships
      @engine_bible.relationships
    end

    def plot_threads
      @engine_bible.plot_threads
    end

    def search(query)
      @engine_bible.search_facts(query)
    end

    def chapter_context(chapter_number)
      @engine_bible.chapter_context(chapter_number)
    end

    def save_character(id, data, change_reason: nil)
      @engine_bible.save_character(id, data, change_reason: change_reason)
    end

    def character_history(_id)
      []
    end

    def rollback_character(_id, _revision_number)
      # Wired up with Canon in Task 8
    end
  end
end
