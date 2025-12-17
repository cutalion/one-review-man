# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module BookCore
  # Migrates existing book data (characters.yml, world.yml, story_facts.yml)
  # to the new Story Bible structure.
  class StoryBibleMigrator
    def initialize(project_root: Dir.pwd)
      @project_root = File.expand_path(project_root)
      @story_bible = StoryBible.new(project_root: @project_root)
    end

    def migrate!
      puts '📚 Migrating to Story Bible format...'

      @story_bible.setup

      migrate_characters
      migrate_locations
      migrate_facts
      migrate_relationships

      puts '✅ Migration complete!'
      puts "   Story Bible location: #{@story_bible.story_bible_path}"
    end

    private

    def old_data_dir
      File.join(@project_root, 'data')
    end

    # === Characters ===

    def migrate_characters
      chars_file = File.join(old_data_dir, 'characters.yml')
      return unless File.exist?(chars_file)

      data = YAML.safe_load(File.read(chars_file), permitted_classes: [Date, Time])
      return unless data

      # Handle both flat and language-nested structures
      characters = extract_language_data(data, 'characters')
      return if characters.nil? || characters.empty?

      puts "   Migrating #{characters.keys.size} characters..."

      characters.each do |id, char_data|
        # Clean up data for new format
        migrated = {
          'id' => id,
          'name' => char_data['name'],
          'description' => char_data['description'],
          'personality_traits' => char_data['personality_traits'] || [],
          'physical_appearance' => char_data['physical_appearance'] || {},
          'programming_skills' => char_data['programming_skills'],
          'catchphrase' => char_data['catchphrase'],
          'backstory' => char_data['backstory'],
          'quirks' => char_data['quirks'],
          'first_appearance' => parse_chapter_number(char_data['first_appearance']),
          'created_date' => char_data['created_date']
        }.compact

        @story_bible.save_character(id, migrated)
      end
    end

    # === Locations ===

    def migrate_locations
      # Locations are in both world.yml and story_facts.yml
      world_file = File.join(old_data_dir, 'world.yml')
      facts_file = File.join(old_data_dir, 'story_facts.yml')

      locations = {}

      # From world.yml
      if File.exist?(world_file)
        world_data = YAML.safe_load(File.read(world_file), permitted_classes: [Date, Time])
        world = extract_language_data(world_data, 'world')

        if world && world['locations']
          world['locations'].each do |id, loc_data|
            locations[id] = {
              'id' => id,
              'name' => loc_data['name'],
              'description' => loc_data['description'],
              'type' => loc_data['type'] || 'location',
              'first_mentioned' => parse_chapter_number(loc_data['established_chapter']),
              'nearby_locations' => loc_data['nearby_locations']
            }.compact
          end
        end

        # Company as a special location
        if world && world['company']
          locations['company'] = {
            'id' => 'company',
            'name' => world['company']['name'],
            'description' => world['company']['description'],
            'type' => world['company']['type'] || 'company',
            'first_mentioned' => parse_chapter_number(world['company']['established_chapter'])
          }.compact
        end
      end

      # From story_facts.yml locations
      if File.exist?(facts_file)
        facts_data = YAML.safe_load(File.read(facts_file), permitted_classes: [Date, Time])
        facts = extract_language_data(facts_data, 'facts')

        if facts && facts['locations']
          facts['locations'].each do |id, loc_data|
            # Merge with existing or add new
            existing = locations[id] || {}
            locations[id] = existing.merge({
              'id' => id,
              'name' => loc_data['name'],
              'description' => loc_data['description'],
              'type' => loc_data['type'] || 'location',
              'first_mentioned' => parse_chapter_number(loc_data['first_mentioned']),
              'status' => loc_data['status']
            }.compact)
          end
        end
      end

      return if locations.empty?

      puts "   Migrating #{locations.size} locations..."

      locations.each do |id, loc_data|
        @story_bible.save_location(id, loc_data)
      end
    end

    # === Facts ===

    def migrate_facts
      facts_file = File.join(old_data_dir, 'story_facts.yml')
      world_file = File.join(old_data_dir, 'world.yml')

      all_facts = { 'facts' => {} }

      # From story_facts.yml
      if File.exist?(facts_file)
        data = YAML.safe_load(File.read(facts_file), permitted_classes: [Date, Time])
        facts = extract_language_data(data, 'facts')

        if facts
          # Events
          if facts['events']
            all_facts['facts']['events'] = facts['events']
            puts "   Migrating #{facts['events'].size} events..."
          end

          # World rules
          if facts['world_rules']
            all_facts['facts']['world_rules'] = facts['world_rules']
            puts "   Migrating #{facts['world_rules'].size} world rules..."
          end
        end
      end

      # Established facts from world.yml
      if File.exist?(world_file)
        data = YAML.safe_load(File.read(world_file), permitted_classes: [Date, Time])
        world = extract_language_data(data, 'world')

        if world && world['established_facts']
          all_facts['facts']['established_facts'] = world['established_facts'].each_with_index.map do |fact, i|
            ["fact_#{i + 1}", { 'description' => fact, 'established' => 'Chapter 1' }]
          end.to_h
        end

        # Culture from world.yml
        if world && world['culture']
          all_facts['facts']['culture'] = world['culture']
        end

        # Infrastructure from world.yml
        if world && world['infrastructure']
          all_facts['facts']['infrastructure'] = world['infrastructure']
        end
      end

      write_yaml_file(@story_bible.facts_path, all_facts)
    end

    # === Relationships ===

    def migrate_relationships
      facts_file = File.join(old_data_dir, 'story_facts.yml')
      return unless File.exist?(facts_file)

      data = YAML.safe_load(File.read(facts_file), permitted_classes: [Date, Time])
      facts = extract_language_data(data, 'facts')

      return unless facts && facts['relationships']

      relationships = facts['relationships'].map do |_id, rel_data|
        {
          'character1' => rel_data['character1'],
          'character2' => rel_data['character2'],
          'type' => rel_data['relationship'],
          'status' => rel_data['status'] || 'established',
          'since_chapter' => rel_data['first_chapter']
        }
      end

      puts "   Migrating #{relationships.size} relationships..."

      write_yaml_file(@story_bible.relationships_path, { 'relationships' => relationships })
    end

    # === Helpers ===

    def extract_language_data(data, key)
      return nil unless data

      # Try direct access first (new flat format)
      return data[key] if data.key?(key)

      # Try language-nested access (old format: en: { characters: ... })
      return data.dig('en', key) if data.dig('en', key)

      nil
    end

    def parse_chapter_number(value)
      return nil if value.nil?
      return value if value.is_a?(Integer)

      # Handle "Chapter 1" format
      match = value.to_s.match(/(\d+)/)
      match ? match[1].to_i : nil
    end

    def write_yaml_file(path, data)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, data.to_yaml)
    end
  end
end
