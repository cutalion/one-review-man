# frozen_string_literal: true

require_relative 'location'

module Eidos
  # Collection of locations. Enumerable, indexable by id.
  class LocationCollection
    include Enumerable

    def initialize(bible:)
      @bible = bible
    end

    def each(&block)
      load_all.each(&block)
    end

    def [](location_id)
      data = @bible.engine_bible.get_location(location_id)
      return nil unless data

      Location.new(data: data.merge('id' => location_id), bible: @bible)
    end

    private

    def load_all
      @bible.engine_bible.locations.map do |id, data|
        Location.new(data: data.merge('id' => id), bible: @bible)
      end
    end
  end
end
