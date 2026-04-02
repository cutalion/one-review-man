# frozen_string_literal: true

module Eidos
  class ComicPanel
    attr_reader :sequence, :scene_description, :characters, :text_elements
    attr_accessor :image_path

    def initialize(sequence:, scene_description:, characters: [], image_path: nil, text_elements: [])
      @sequence = sequence
      @scene_description = scene_description
      @characters = characters
      @image_path = image_path
      @text_elements = text_elements
    end

    def to_h
      {
        'sequence' => sequence,
        'scene_description' => scene_description,
        'characters' => characters,
        'image_path' => image_path,
        'text_elements' => text_elements
      }
    end
  end
end
