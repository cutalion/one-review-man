# frozen_string_literal: true

module Eidos
  # SDK domain object for a location in the Story Bible.
  class Location
    attr_reader :id, :data

    def initialize(data:, bible: nil)
      @data = data
      @id = data['id']
      @bible = bible
    end

    def name
      @data['name']
    end

    def [](key)
      @data[key.to_s]
    end

    def to_h
      @data.dup
    end

    def update(changes, reason: nil)
      changes.each { |k, v| @data[k.to_s] = v }
      @bible&.save_location(@id, @data, change_reason: reason)
      self
    end

    def respond_to_missing?(method_name, include_private = false)
      @data.key?(method_name.to_s) || super
    end

    def method_missing(method_name, *args)
      key = method_name.to_s
      return @data[key] if args.empty? && @data.key?(key)

      super
    end
  end
end
