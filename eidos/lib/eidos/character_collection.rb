# frozen_string_literal: true

require_relative 'character'

module Eidos
  # Collection of characters. Enumerable, indexable by id.
  class CharacterCollection
    include Enumerable

    def initialize(bible:)
      @bible = bible
    end

    def each(&block)
      load_all.each(&block)
    end

    def [](character_id)
      data = @bible.engine_bible.get_character(character_id)
      return nil unless data

      Character.new(data: data.merge('id' => character_id), bible: @bible)
    end

    private

    def load_all
      @bible.engine_bible.characters.map do |id, data|
        Character.new(data: data.merge('id' => id), bible: @bible)
      end
    end
  end
end
