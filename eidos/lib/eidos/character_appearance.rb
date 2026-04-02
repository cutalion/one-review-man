# frozen_string_literal: true

require 'yaml'

module Eidos
  class CharacterAppearance
    attr_reader :name, :id, :age, :skin_tone, :hair, :eyes, :outfit, :distinguishing_features

    def initialize(character_data)
      @id = character_data['id']
      @name = character_data['name']

      physical = character_data['physical_appearance'] || {}
      @age = physical['age']
      @skin_tone = physical['skin_tone']
      @hair = physical['hair']
      @eyes = physical['eyes']
      @outfit = physical['outfit']
      @distinguishing_features = physical['distinguishing_features']
    end

    def to_prompt
      parts = [@name]
      details = []
      details << "#{age} years old" if age
      details << "#{skin_tone} skin" if skin_tone
      details << "#{hair} hair" if hair
      details << "#{eyes} eyes" if eyes
      details << "wearing #{outfit}" if outfit
      details << distinguishing_features.to_s if distinguishing_features

      if details.any?
        parts << ': '
        parts << details.join(', ')
      end

      parts.join
    end

    def self.extract_all(story_bible_path)
      characters_dir = File.join(story_bible_path, 'characters')
      return {} unless Dir.exist?(characters_dir)

      result = {}
      Dir.glob(File.join(characters_dir, '*.yml')).each do |file|
        data = YAML.load_file(file)
        next unless data.is_a?(Hash) && data['name']

        appearance = new(data)
        result[appearance.id] = appearance
      end
      result
    end
  end
end
