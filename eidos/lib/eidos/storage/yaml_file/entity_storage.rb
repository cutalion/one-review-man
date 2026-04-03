# frozen_string_literal: true

require 'yaml'
require 'date'
require 'fileutils'
require_relative '../entity_storage'

module Eidos
  module Storage
    module YamlFile
      # File-based entity storage using YAML files on disk.
      # Extracted from the original StoryBible private methods.
      class EntityStorage
        include Storage::EntityStorage

        STORY_BIBLE_DIR = 'data/story_bible'

        attr_reader :story_bible_path

        def initialize(project_root: Dir.pwd, story_bible_path: nil)
          @story_bible_path = story_bible_path || File.join(File.expand_path(project_root), STORY_BIBLE_DIR)
        end

        def setup
          FileUtils.mkdir_p(characters_dir)
          FileUtils.mkdir_p(locations_dir)
          touch_yaml_file(facts_path, { 'facts' => {} })
          touch_yaml_file(relationships_path, { 'relationships' => [] })
          touch_yaml_file(plot_threads_path, { 'plot_threads' => [] })
        end

        # === Characters ===

        def all_characters
          load_entities_from_dir(characters_dir)
        end

        def get_character(id)
          all_characters[id.to_s]
        end

        def save_character(id, data)
          merged = data.merge('id' => id)
          path = File.join(characters_dir, "#{id}.yml")
          write_yaml_file(path, merged)
        end

        def list_characters(appeared_in: nil)
          chars = all_characters.map do |char_id, data|
            { 'id' => char_id, 'name' => data['name'] }
          end

          if appeared_in
            chars.select! do |c|
              char_data = all_characters[c['id']]
              mentions = char_data['mentions'] || []
              mentions.include?(appeared_in)
            end
          end

          chars
        end

        # === Locations ===

        def all_locations
          load_entities_from_dir(locations_dir)
        end

        def get_location(id)
          all_locations[id.to_s]
        end

        def save_location(id, data)
          merged = data.merge('id' => id)
          path = File.join(locations_dir, "#{id}.yml")
          write_yaml_file(path, merged)
        end

        # === Facts ===

        def all_facts
          load_yaml_file(facts_path)['facts'] || {}
        end

        def get_facts_by_category(category)
          all_facts[category.to_s] || {}
        end

        def add_fact(category, id, data)
          all = load_yaml_file(facts_path)
          all['facts'] ||= {}
          all['facts'][category] ||= {}
          all['facts'][category][id] = data
          write_yaml_file(facts_path, all)
        end

        def search_facts(query)
          results = []
          query_downcase = query.downcase

          all_facts.each do |category, category_facts|
            category_facts.each do |id, data|
              searchable = [
                data['name'],
                data['description'],
                data['rule']
              ].compact.join(' ').downcase

              if searchable.include?(query_downcase)
                results << { 'category' => category, 'id' => id, 'data' => data }
              end
            end
          end

          results
        end

        # === Relationships ===

        def all_relationships
          load_yaml_file(relationships_path)['relationships'] || []
        end

        def get_relationships_for(character_id)
          all_relationships.select do |rel|
            rel['character1'] == character_id || rel['character2'] == character_id
          end
        end

        def add_relationship(data)
          all_rels = load_yaml_file(relationships_path)
          all_rels['relationships'] ||= []
          all_rels['relationships'] << data
          write_yaml_file(relationships_path, all_rels)
        end

        # === Plot Threads ===

        def all_plot_threads
          load_yaml_file(plot_threads_path)['plot_threads'] || []
        end

        def active_plot_threads
          all_plot_threads.select { |pt| pt['status'] == 'active' }
        end

        def add_plot_thread(data)
          merged = data.merge('status' => 'active')
          all_threads = load_yaml_file(plot_threads_path)
          all_threads['plot_threads'] ||= []
          all_threads['plot_threads'] << merged
          write_yaml_file(plot_threads_path, all_threads)
        end

        # === Path helpers (public for backward compatibility) ===

        def characters_dir
          File.join(@story_bible_path, 'characters')
        end

        def locations_dir
          File.join(@story_bible_path, 'locations')
        end

        def facts_path
          File.join(@story_bible_path, 'facts.yml')
        end

        def relationships_path
          File.join(@story_bible_path, 'relationships.yml')
        end

        def plot_threads_path
          File.join(@story_bible_path, 'plot_threads.yml')
        end

        private

        def load_entities_from_dir(dir)
          return {} unless Dir.exist?(dir)

          entities = {}
          Dir.glob(File.join(dir, '*.yml')).each do |file|
            data = load_yaml_file(file)
            id = data['id'] || File.basename(file, '.yml')
            entities[id] = data
          end
          entities
        end

        def load_yaml_file(path)
          return {} unless File.exist?(path)

          YAML.safe_load(File.read(path), permitted_classes: [Date, Time]) || {}
        rescue Psych::SyntaxError => e
          warn "Warning: Failed to parse #{path}: #{e.message}"
          {}
        end

        def write_yaml_file(path, data)
          FileUtils.mkdir_p(File.dirname(path))
          File.write(path, data.to_yaml)
        end

        def touch_yaml_file(path, default_content = {})
          return if File.exist?(path)

          write_yaml_file(path, default_content)
        end
      end
    end
  end
end
