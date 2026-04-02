# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'eidos/story_bible'

module Eidos
  # Exports Story Bible data to Jekyll-compatible format.
  # This ensures the Story Bible is the single source of truth while
  # maintaining backward compatibility with Jekyll templates.
  class StoryBibleExporter
    def initialize(project_root: Dir.pwd)
      @project_root = File.expand_path(project_root)
      @story_bible = StoryBible.new(project_root: @project_root)
    end

    # Export all Story Bible data to Jekyll-compatible files in the data directory
    def export_for_jekyll!
      puts '📚 Exporting Story Bible to Jekyll format...'

      export_characters
      export_world_data
      export_story_facts

      puts '✅ Export complete!'
    end

    # Export to a specific destination (for site generation)
    def export_to(dest_dir)
      puts "📚 Exporting Story Bible to #{dest_dir}..."

      export_characters(dest_dir)
      export_world_data(dest_dir)
      export_story_facts(dest_dir)

      puts '✅ Export complete!'
    end

    private

    def data_dir
      File.join(@project_root, 'data')
    end

    # Export characters to Jekyll format (en: { characters: { slug: data } })
    def export_characters(dest_dir = nil)
      target_dir = dest_dir || data_dir
      characters = @story_bible.characters

      return if characters.empty?

      # Build Jekyll-compatible structure
      jekyll_data = {
        'en' => {
          'characters' => characters.transform_values do |char|
            # Add slug and language fields for Jekyll
            char.merge(
              'slug' => char['id'],
              'language' => 'en'
            )
          end
        }
      }

      write_yaml_file(File.join(target_dir, 'characters.yml'), jekyll_data)
      puts "   Exported #{characters.size} characters"
    end

    # Export locations and world data
    def export_world_data(dest_dir = nil)
      target_dir = dest_dir || data_dir
      locations = @story_bible.locations

      return if locations.empty?

      # Build Jekyll-compatible structure
      jekyll_data = {
        'en' => {
          'world' => {
            'locations' => locations.transform_values do |loc|
              {
                'name' => loc['name'],
                'description' => loc['description'],
                'type' => loc['type'],
                'established_chapter' => loc['first_mentioned'] ? "Chapter #{loc['first_mentioned']}" : nil
              }.compact
            end
          }
        }
      }

      write_yaml_file(File.join(target_dir, 'world.yml'), jekyll_data)
      puts "   Exported #{locations.size} locations"
    end

    # Export facts, events, and relationships
    def export_story_facts(dest_dir = nil)
      target_dir = dest_dir || data_dir
      facts = @story_bible.facts
      relationships = @story_bible.relationships

      # Build Jekyll-compatible structure
      jekyll_data = {
        'en' => {
          'facts' => {
            'locations' => {},  # Already in world.yml
            'events' => facts['events'] || {},
            'world_rules' => facts['world_rules'] || {},
            'relationships' => relationships.each_with_index.map do |rel, i|
              key = "#{rel['character1']}_#{rel['character2']}".gsub(/[^a-z0-9_-]/i, '-')
              [key, {
                'character1' => rel['character1'],
                'character2' => rel['character2'],
                'relationship' => rel['type'],
                'status' => rel['status'] || 'established',
                'first_chapter' => rel['since_chapter']
              }]
            end.to_h
          }
        }
      }

      write_yaml_file(File.join(target_dir, 'story_facts.yml'), jekyll_data)
      puts "   Exported facts and #{relationships.size} relationships"
    end

    def write_yaml_file(path, data)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, data.to_yaml)
    end
  end
end
