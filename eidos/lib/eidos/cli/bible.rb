# frozen_string_literal: true

require 'thor'
require 'eidos/cli/helpers'
require 'eidos/cli/unknown_command_help'
require 'eidos/story_bible'

module Eidos
  module CLI
    # CLI commands for Story Bible management
    class Bible < Thor
      extend Eidos::CLI::UnknownCommandHelp
      include Eidos::CLI::Helpers

      class_option 'world-dir', aliases: ['-w'], type: :string, desc: 'Path to the world directory'

      # 018b: `bible migrate` and `bible export` removed. Migration of
      # legacy story-bible structure was a one-shot historical helper;
      # `bible export` wrote into the source world (017 reframed Jekyll
      # publishing to write into the destination via PieceProducer's
      # `eidos publish jekyll`).

      # === Authoring (feature 019) =============================================
      #
      # `bible add TYPE …` and `bible update TYPE …` are the supported way
      # to author canonical entities directly — without producing a piece.
      # Both commands write a canon revision under the hood, so the audit
      # trail (`canon history character/<id>`) reflects every change.
      #
      # Field values are parsed as strings: `shoe_size=11` is the string
      # `"11"`. For integers, lists, multi-line text, or nested hashes,
      # edit the YAML file directly after the create. (Future work may
      # add `field:=<yaml>` for raw-YAML values; for now strings only.)

      AUTHORING_TYPES = %w[character location fact relationship plot_thread].freeze

      desc 'add TYPE ID [FIELD=VALUE...]',
           "Create a new canonical entity (TYPE: #{AUTHORING_TYPES.join('|')})"
      method_option :reason, type: :string, desc: 'Reason for the change (recorded in revision history)'
      def add(type, *args)
        abs_root = resolve_project_root!(options['world-dir'])
        bible = build_story_bible_with_revisions(abs_root)

        case type
        when 'character', 'location'
          add_keyed_entity(bible, type, *args)
        when 'fact'
          add_fact_entity(bible, *args)
        when 'relationship'
          add_relationship_entity(bible, *args)
        when 'plot_thread'
          add_plot_thread_entity(bible, *args)
        else
          warn "Unknown TYPE: #{type}. Use one of: #{AUTHORING_TYPES.join(', ')}"
          exit 1
        end
      end

      desc 'update TYPE ID [FIELD=VALUE...]',
           'Update an existing canonical entity (TYPE: character|location|fact|plot_thread)'
      method_option :reason, type: :string, desc: 'Reason for the change (recorded in revision history)'
      def update(type, *args)
        abs_root = resolve_project_root!(options['world-dir'])
        bible = build_story_bible_with_revisions(abs_root)

        case type
        when 'character', 'location'
          update_keyed_entity(bible, type, *args)
        when 'fact'
          update_fact_entity(bible, *args)
        when 'plot_thread'
          update_plot_thread_entity(bible, *args)
        when 'relationship'
          warn 'Updating relationships is not supported via CLI (relationships are append-only). ' \
               'Edit data/story_bible/relationships.yml directly.'
          exit 1
        else
          warn "Unknown TYPE: #{type}. Use one of: character, location, fact, plot_thread"
          exit 1
        end
      end

      desc 'list TYPE', 'List entities (characters, locations, facts, relationships, plot_threads)'
      def list(type)
        abs_root = resolve_project_root!(options['world-dir'])
        bible = Eidos::StoryBible.new(project_root: abs_root)

        case type.downcase
        when 'characters', 'chars'
          chars = bible.characters
          if chars.empty?
            say 'No characters found.', :yellow
          else
            say "Characters (#{chars.size}):", :cyan
            chars.each { |id, data| say "  • #{id}: #{data['name']}#{seed_marker(data)}", :green }
          end
        when 'locations', 'locs'
          locs = bible.locations
          if locs.empty?
            say 'No locations found.', :yellow
          else
            say "Locations (#{locs.size}):", :cyan
            locs.each { |id, data| say "  • #{id}: #{data['name']}#{seed_marker(data)}", :green }
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

      no_commands do
        def build_story_bible_with_revisions(abs_root)
          require 'eidos/revision_store'
          revisions_path = File.join(abs_root, 'data', 'story_bible', 'revisions')
          store = Eidos::RevisionStore.new(revisions_path: revisions_path)
          Eidos::StoryBible.new(project_root: abs_root, revision_store: store)
        end

        def seed_marker(data)
          return '' unless data.is_a?(Hash) && data['origin'].to_s == 'seed'

          ' (seed)'
        end

        # === Authoring helpers (feature 019) ===============================

        # FIELD=VALUE pairs → Hash. Strings only (matches the legacy
        # `canon update` field-value parser; richer types require direct
        # YAML edit).
        def parse_field_values(field_values)
          changes = {}
          field_values.each do |fv|
            key, value = fv.split('=', 2)
            changes[key] = value if key && value
          end
          changes
        end

        def add_keyed_entity(bible, type, id = nil, *field_values)
          if id.nil? || id.empty?
            warn "Usage: bible add #{type} ID [FIELD=VALUE...]"
            exit 1
          end

          existing = type == 'character' ? bible.get_character(id) : bible.get_location(id)
          if existing
            warn "#{type}/#{id} already exists. Use 'bible update #{type} #{id} ...' to modify it."
            exit 1
          end

          changes = parse_field_values(field_values).merge('id' => id)
          if type == 'character'
            bible.save_character(id, changes, change_reason: options[:reason])
          else
            bible.save_location(id, changes, change_reason: options[:reason])
          end
          say "Added #{type}/#{id}", :green
        end

        def update_keyed_entity(bible, type, id = nil, *field_values)
          if id.nil? || id.empty?
            warn "Usage: bible update #{type} ID [FIELD=VALUE...]"
            exit 1
          end

          existing = type == 'character' ? bible.get_character(id) : bible.get_location(id)
          unless existing
            warn "#{type}/#{id} does not exist. Use 'bible add #{type} #{id} ...' to create it."
            exit 1
          end

          merged = existing.merge(parse_field_values(field_values))
          if type == 'character'
            bible.save_character(id, merged, change_reason: options[:reason])
          else
            bible.save_location(id, merged, change_reason: options[:reason])
          end
          say "Updated #{type}/#{id}", :green
        end

        def add_fact_entity(bible, slash_id = nil, *field_values)
          unless slash_id&.include?('/')
            warn "Usage: bible add fact CATEGORY/ID [FIELD=VALUE...] (e.g. 'events/standup_meeting')"
            exit 1
          end

          category, id = slash_id.split('/', 2)
          if bible.get_facts_by_category(category)[id]
            warn "fact/#{category}/#{id} already exists. Use 'bible update fact #{slash_id} ...' to modify it."
            exit 1
          end

          changes = parse_field_values(field_values).merge('id' => id)
          bible.add_fact(category, id, changes, change_reason: options[:reason])
          say "Added fact/#{category}/#{id}", :green
        end

        def update_fact_entity(bible, slash_id = nil, *field_values)
          unless slash_id&.include?('/')
            warn 'Usage: bible update fact CATEGORY/ID [FIELD=VALUE...]'
            exit 1
          end

          category, id = slash_id.split('/', 2)
          existing = bible.get_facts_by_category(category)[id]
          unless existing
            warn "fact/#{category}/#{id} does not exist. Use 'bible add fact #{slash_id} ...' to create it."
            exit 1
          end

          merged = existing.merge(parse_field_values(field_values))
          bible.add_fact(category, id, merged, change_reason: options[:reason])
          say "Updated fact/#{category}/#{id}", :green
        end

        def add_relationship_entity(bible, character1 = nil, character2 = nil, *field_values)
          if character1.nil? || character2.nil?
            warn 'Usage: bible add relationship CHARACTER1 CHARACTER2 [FIELD=VALUE...]'
            exit 1
          end

          data = parse_field_values(field_values).merge(
            'character1' => character1,
            'character2' => character2
          )
          bible.add_relationship(data, change_reason: options[:reason])
          say "Added relationship #{character1} <-> #{character2}", :green
        end

        def add_plot_thread_entity(bible, id = nil, *field_values)
          if id.nil? || id.empty?
            warn 'Usage: bible add plot_thread ID [FIELD=VALUE...]'
            exit 1
          end

          if bible.plot_threads.any? { |t| t['id'] == id }
            warn "plot_thread/#{id} already exists. Use 'bible update plot_thread #{id} ...' to modify it."
            exit 1
          end

          data = parse_field_values(field_values).merge('id' => id)
          bible.add_plot_thread(data, change_reason: options[:reason])
          say "Added plot_thread/#{id}", :green
        end

        def update_plot_thread_entity(bible, id = nil, *field_values)
          if id.nil? || id.empty?
            warn 'Usage: bible update plot_thread ID [FIELD=VALUE...]'
            exit 1
          end

          existing = bible.plot_threads.find { |t| t['id'] == id }
          unless existing
            warn "plot_thread/#{id} does not exist. Use 'bible add plot_thread #{id} ...' to create it."
            exit 1
          end

          merged = existing.merge(parse_field_values(field_values))
          bible.save_plot_thread(merged, change_reason: options[:reason])
          say "Updated plot_thread/#{id}", :green
        end
      end
    end
  end
end
