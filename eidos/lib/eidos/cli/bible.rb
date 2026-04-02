# frozen_string_literal: true

require 'thor'
require 'eidos/cli/helpers'
require 'eidos/story_bible'
require 'eidos/story_bible_migrator'
require 'eidos/story_bible_exporter'

module Eidos
  module CLI
    # CLI commands for Story Bible management
    class Bible < Thor
      include Eidos::CLI::Helpers

      class_option 'world-dir', aliases: ['-w'], type: :string, desc: 'Path to the world directory'

      desc 'migrate', 'Migrate existing data to Story Bible format'
      def migrate
        abs_root = resolve_project_root!(options['world-dir'])
        Dir.chdir(abs_root) do
          migrator = Eidos::StoryBibleMigrator.new(project_root: abs_root)
          migrator.migrate!
        end
      end

      desc 'export', 'Export Story Bible to Jekyll-compatible format (updates data/*.yml files)'
      def export
        abs_root = resolve_project_root!(options['world-dir'])
        Dir.chdir(abs_root) do
          exporter = Eidos::StoryBibleExporter.new(project_root: abs_root)
          exporter.export_for_jekyll!
        end
      end

      desc 'list TYPE', 'List entities (characters, locations, facts, relationships, plot_threads)'
      def list(type)
        abs_root = resolve_project_root!(options['world-dir'])
        bible = Eidos::StoryBible.new(project_root: abs_root)

        case type.downcase
        when 'characters', 'chars'
          chars = bible.list_characters
          if chars.empty?
            say 'No characters found.', :yellow
          else
            say "Characters (#{chars.size}):", :cyan
            chars.each { |c| say "  • #{c['id']}: #{c['name']}", :green }
          end
        when 'locations', 'locs'
          locs = bible.locations
          if locs.empty?
            say 'No locations found.', :yellow
          else
            say "Locations (#{locs.size}):", :cyan
            locs.each { |id, data| say "  • #{id}: #{data['name']}", :green }
          end
        when 'facts'
          facts = bible.facts
          if facts.empty?
            say 'No facts found.', :yellow
          else
            say "Fact categories:", :cyan
            facts.each do |category, items|
              say "  📁 #{category} (#{items.size} items)", :blue
            end
            say "\nTip: Use 'list facts/<category>' to see items (e.g., 'list facts/events')", :yellow
          end
        when /^facts\/(.+)$/
          category = Regexp.last_match(1)
          category_facts = bible.get_facts_by_category(category)
          if category_facts.empty?
            say "No facts found in category '#{category}'.", :yellow
            say "Available categories: #{bible.facts.keys.join(', ')}", :blue
          else
            say "#{category} (#{category_facts.size}):", :cyan
            category_facts.each do |id, data|
              desc = data['description'] || data['rule'] || data['name'] || '(no description)'
              say "  • #{id}: #{desc}", :green
            end
          end
        when 'relationships', 'rels'
          rels = bible.relationships
          if rels.empty?
            say 'No relationships found.', :yellow
          else
            say "Relationships (#{rels.size}):", :cyan
            rels.each do |rel|
              say "  • #{rel['character1']} <-> #{rel['character2']}: #{rel['type']}", :green
            end
          end
        when 'plot_threads', 'plots'
          threads = bible.plot_threads
          if threads.empty?
            say 'No plot threads found.', :yellow
          else
            say "Plot Threads (#{threads.size}):", :cyan
            threads.each do |pt|
              status_color = pt['status'] == 'active' ? :green : :yellow
              say "  • #{pt['id']}: #{pt['description']} [#{pt['status']}]", status_color
            end
          end
        else
          say "Unknown type: #{type}. Use: characters, locations, facts, relationships, plot_threads", :red
        end
      end

      desc 'show PATH', 'Show details of an entity (e.g., characters/kenji, locations/office, facts/events/standup)'
      def show(path)
        abs_root = resolve_project_root!(options['world-dir'])
        bible = Eidos::StoryBible.new(project_root: abs_root)

        parts = path.split('/')
        type = parts[0]&.downcase

        case type
        when 'characters', 'character', 'char'
          id = parts[1]
          data = bible.get_character(id)
          if data
            say "Character: #{data['name']}", :cyan
            say data.to_yaml
          else
            say "Character not found: #{id}", :red
          end
        when 'locations', 'location', 'loc'
          id = parts[1]
          data = bible.get_location(id)
          if data
            say "Location: #{data['name']}", :cyan
            say data.to_yaml
          else
            say "Location not found: #{id}", :red
          end
        when 'facts'
          if parts.length == 2
            # Show all facts in a category: facts/events
            category = parts[1]
            category_facts = bible.get_facts_by_category(category)
            if category_facts.empty?
              say "No facts in category '#{category}'.", :yellow
            else
              say "#{category} (#{category_facts.size}):", :cyan
              say category_facts.to_yaml
            end
          elsif parts.length >= 3
            # Show a specific fact: facts/events/standup
            category = parts[1]
            fact_id = parts[2..].join('/')
            category_facts = bible.get_facts_by_category(category)
            data = category_facts[fact_id]
            if data
              say "Fact [#{category}]: #{fact_id}", :cyan
              say data.to_yaml
            else
              say "Fact not found: #{category}/#{fact_id}", :red
            end
          else
            say "Usage: show facts/<category> or facts/<category>/<id>", :yellow
          end
        when 'relationships', 'rels'
          # Show relationships for a character
          if parts[1]
            rels = bible.get_relationships_for(parts[1])
            if rels.empty?
              say "No relationships found for '#{parts[1]}'.", :yellow
            else
              say "Relationships for #{parts[1]}:", :cyan
              say rels.to_yaml
            end
          else
            say bible.relationships.to_yaml
          end
        else
          say "Unknown type: #{type}. Use: characters/, locations/, facts/, relationships/", :red
        end
      end

      desc 'search QUERY', 'Search facts by keyword (case-insensitive)'
      def search(query)
        abs_root = resolve_project_root!(options['world-dir'])
        bible = Eidos::StoryBible.new(project_root: abs_root)

        results = bible.search_facts(query)
        if results.empty?
          say "No facts found matching '#{query}'.", :yellow
        else
          say "Found #{results.size} matching facts:", :cyan
          results.each do |r|
            say "  [#{r['category']}] #{r['id']}: #{r['data']['description'] || r['data']['rule'] || r['data']['name']}", :green
          end
        end
      end

      desc 'context CHAPTER', 'Show context for a chapter (useful for agent prompts)'
      def context(chapter)
        abs_root = resolve_project_root!(options['world-dir'])
        bible = Eidos::StoryBible.new(project_root: abs_root)

        ctx = bible.chapter_context(chapter.to_i)
        say "Chapter #{chapter} Context:", :cyan
        say ctx.to_yaml
      end
    end
  end
end
