# frozen_string_literal: true

require_relative '../entity_storage'

module Eidos
  module Storage
    module Memory
      # In-memory entity storage using plain Ruby hashes.
      # Suitable for testing — fast, isolated, no filesystem I/O.
      class EntityStorage
        include Storage::EntityStorage

        attr_reader :story_bible_path

        def initialize(**_opts)
          @story_bible_path = '(memory)'
          @characters = {}
          @locations = {}
          @facts = {}
          @relationships = []
          @plot_threads = []
        end

        def setup
          # No-op for memory storage
        end

        # === Characters ===

        def all_characters
          deep_copy(@characters)
        end

        def get_character(id)
          data = @characters[id.to_s]
          data ? deep_copy(data) : nil
        end

        def save_character(id, data)
          @characters[id.to_s] = data.merge('id' => id)
        end

        def list_characters(appeared_in: nil)
          chars = @characters.map { |char_id, data| { 'id' => char_id, 'name' => data['name'] } }

          if appeared_in
            chars.select! do |c|
              mentions = @characters[c['id']]['mentions'] || []
              mentions.include?(appeared_in)
            end
          end

          chars
        end

        # === Locations ===

        def all_locations
          deep_copy(@locations)
        end

        def get_location(id)
          data = @locations[id.to_s]
          data ? deep_copy(data) : nil
        end

        def save_location(id, data)
          @locations[id.to_s] = data.merge('id' => id)
        end

        # === Facts ===

        def all_facts
          deep_copy(@facts)
        end

        def get_facts_by_category(category)
          deep_copy(@facts[category.to_s] || {})
        end

        def add_fact(category, id, data)
          @facts[category] ||= {}
          @facts[category][id] = data
        end

        def search_facts(query)
          results = []
          query_downcase = query.downcase

          @facts.each do |category, category_facts|
            category_facts.each do |id, data|
              searchable = [data['name'], data['description'], data['rule']].compact.join(' ').downcase
              if searchable.include?(query_downcase)
                results << { 'category' => category, 'id' => id, 'data' => data }
              end
            end
          end

          results
        end

        # === Relationships ===

        def all_relationships
          deep_copy(@relationships)
        end

        def get_relationships_for(character_id)
          @relationships.select do |rel|
            rel['character1'] == character_id || rel['character2'] == character_id
          end
        end

        def add_relationship(data)
          @relationships << data
        end

        # === Plot Threads ===

        def all_plot_threads
          deep_copy(@plot_threads)
        end

        def active_plot_threads
          @plot_threads.select { |pt| pt['status'] == 'active' }
        end

        def add_plot_thread(data)
          @plot_threads << data.merge('status' => 'active')
        end

        # Upsert a plot thread by id, preserving the caller's `status`.
        # Returns the operation performed: 'create' if appended, 'update'
        # if an existing thread with the same id was replaced.
        def save_plot_thread(data)
          id = data['id']
          idx = id ? @plot_threads.index { |t| t['id'] == id } : nil
          if idx
            @plot_threads[idx] = data
            'update'
          else
            @plot_threads << data
            'create'
          end
        end

        # Path helpers (return placeholder values for compatibility)
        def characters_dir = '(memory)/characters'
        def locations_dir = '(memory)/locations'
        def facts_path = '(memory)/facts.yml'
        def relationships_path = '(memory)/relationships.yml'
        def plot_threads_path = '(memory)/plot_threads.yml'

        private

        def deep_copy(obj)
          Marshal.load(Marshal.dump(obj))
        end
      end
    end
  end
end
