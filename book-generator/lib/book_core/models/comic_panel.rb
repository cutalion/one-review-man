# frozen_string_literal: true

module BookCore
  class ComicPanel
    attr_reader :sequence, :scene_description, :characters
    attr_accessor :image_path

    def initialize(sequence:, scene_description:, characters: [], image_path: nil)
      @sequence = sequence
      @scene_description = scene_description
      @characters = characters
      @image_path = image_path
    end

    def to_h
      {
        'sequence' => sequence,
        'scene_description' => scene_description,
        'characters' => characters,
        'image_path' => image_path
      }
    end
  end
end
