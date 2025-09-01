# frozen_string_literal: true

require 'yaml'
require 'date'
require 'fileutils'
require 'book_core/llm_service'
require 'book_core/prompt_provider'
require 'book_core/world_utils'
require 'book_core/prompt_utils'
require 'book_core/env_utils'
require 'book_core/validation_utils'

module BookCore
  # Main engine for generating book chapters using AI models
  class ChapterGenerator
    include WorldUtils

    def initialize(model_override = nil, **kwargs)
      @model_override = model_override
      @project_root = File.expand_path(kwargs[:project_root] || Dir.pwd)
      @book_data = kwargs[:book_data] || {}
      @characters = kwargs[:characters] || {}
      @generation_log = kwargs[:generation_log] || {}
      @prompt_provider = kwargs[:prompt_provider] || default_prompt_provider
      @output_adapter = kwargs[:output_adapter] || default_output_adapter

      settings_path = File.join(@project_root, 'data/settings.yml')
      @llm_service = kwargs[:llm_service] || BookCore::LLMService.new(settings_path, model_override)

      # Ensure adapter is configured with project root if provided
      return unless @output_adapter.respond_to?(:setup_project)

      @output_adapter.setup_project(@project_root)
    end

    def generate_next_chapter(auto_generate: false)
      next_chapter = determine_next_chapter_number
      @current_chapter_number = next_chapter

      # Auto-migrate world.yml to story_facts.yml if needed
      migrate_world_data_to_story_facts

      puts "Generating Chapter #{next_chapter} using model #{@llm_service.get_model_for_task('generation')}..."

      # Determine characters for this chapter (parity with main)
      character_objects = select_characters_for_chapter(next_chapter)
      character_slugs = character_objects.map { |c| c['slug'] || slugify(c['name'].to_s) }

      chapter_data = generate_chapter_structured(next_chapter, auto_generate: auto_generate)

      write_chapter_file(next_chapter, chapter_data, character_slugs)
      create_new_characters(chapter_data['new_characters']) if chapter_data['new_characters'].is_a?(Array)
      extract_and_store_story_facts(chapter_data['story_facts'], next_chapter) if chapter_data['story_facts'].is_a?(Hash)

      update_book_progress(next_chapter)

      puts "✅ Chapter #{next_chapter} generated successfully!"

      chapter_data['content']
    end

    private

    def generate_chapter_structured(chapter_number, auto_generate: false)
      prompt = build_chapter_prompt(chapter_number, auto_generate: auto_generate)
      data = @llm_service.generate_chapter_structured(prompt, {})
      # Replace placeholders if present
      if data.is_a?(Hash)
        %w[title summary content].each do |key|
          next unless data[key]

          content = data[key].to_s
          content = content.gsub('{CHAPTER_NUMBER}', chapter_number.to_s)

          # Replace character name placeholders
          book_metadata = load_book_metadata_abs
          chars = load_characters_abs
          main_character_placeholders = build_main_character_placeholders(book_metadata, chars)
          main_character_placeholders&.each do |placeholder_key, replacement_value|
            content = content.gsub("{#{placeholder_key}}", replacement_value.to_s)
          end

          # Replace world context placeholders
          world_ctx = Dir.chdir(@project_root) { build_world_context('en') }
          world_ctx&.each do |placeholder_key, replacement_value|
            content = content.gsub("{#{placeholder_key}}", replacement_value.to_s) if replacement_value
          end

          data[key] = content
        end
      end
      raise BookCore::LLMService::LLMError, 'Generated content too short' if !EnvUtils.mock_ai_enabled? && (data['content'].to_s.strip.length < 50)

      data
    end

    def build_chapter_prompt(chapter_number, auto_generate: false)
      # Load template matching main branch (explicit filename)
      template = begin
        @prompt_provider.load('chapter_prompts.txt')
      rescue StandardError
        'Write Chapter {CHAPTER_NUMBER} of a programming comedy story'
      end
      # Fail-safe: pre-fill the chapter number in case template contains extra occurrences
      template = template.to_s.gsub('{CHAPTER_NUMBER}', chapter_number.to_s)

      # Prioritized book metadata for target length
      book_metadata = load_book_metadata_abs

      # Previous chapters summary
      previous_summary = build_previous_chapters_summary(chapter_number)

      # Characters context
      chars = load_characters_abs
      selected_chars = select_characters_for_chapter(chapter_number, chars)
      character_context = build_character_context(selected_chars)

      # Used plot devices
      used_devices = load_generation_log_abs['used_plot_devices'] || []

      # World context (use world utils; ensure correct CWD)
      world_ctx = Dir.chdir(@project_root) { build_world_context('en') }

      # Build dynamic placeholders based on book metadata and prompt requirements
      placeholders = build_chapter_placeholders(chapter_number, book_metadata, chars,
                                                character_context, used_devices, previous_summary)

      # Add world context
      placeholders.merge!(world_ctx || {})

      PromptUtils.build_prompt(template, placeholders, warn_unused: false, context: "chapter #{chapter_number} generation")
    rescue PromptUtils::UnfilledPlaceholdersError => e
      # Attempt interactive collection of missing metadata
      if attempt_interactive_metadata_collection(e.unfilled_placeholders, auto_generate: auto_generate)
        # Retry with updated metadata - but only once to prevent infinite recursion
        begin
          template = begin
            @prompt_provider.load('chapter_prompts.txt')
          rescue StandardError
            'Write Chapter {CHAPTER_NUMBER} of a programming comedy story'
          end
          template = template.to_s.gsub('{CHAPTER_NUMBER}', chapter_number.to_s)

          # Rebuild placeholders with fresh data
          book_metadata = load_book_metadata_abs
          previous_summary = build_previous_chapters_summary(chapter_number)
          chars = load_characters_abs
          selected_chars = select_characters_for_chapter(chapter_number, chars)
          character_context = build_character_context(selected_chars)
          used_devices = load_generation_log_abs['used_plot_devices'] || []
          world_ctx = Dir.chdir(@project_root) { build_world_context('en') }
          placeholders = build_chapter_placeholders(chapter_number, book_metadata, chars,
                                                    character_context, used_devices, previous_summary)
          placeholders.merge!(world_ctx || {})

          return PromptUtils.build_prompt(template, placeholders, warn_unused: false, context: "chapter #{chapter_number} generation (retry)")
        rescue PromptUtils::UnfilledPlaceholdersError => retry_error
          # If it still fails after metadata collection, fall back to error message
          e = retry_error # Use the new error for the error message below
        end
      end
      # Fall back to detailed error message
      puts ''
      puts '❌ Missing Information Required for Chapter Generation'
      puts ''
      puts 'Your book needs additional information before chapters can be generated.'
      puts "Missing: #{e.unfilled_placeholders.join(', ')}"
      puts ''
      puts '💡 To fix this issue:'
      puts '1. Update your book metadata with the missing information'
      puts "2. Or run 'book init' again in a new directory with complete setup"
      puts ''
      puts '📖 Missing Information Guide:'
      puts '  • BOOK_GENRE: What type of story is this? (fantasy, sci-fi, mystery, etc.)' if e.unfilled_placeholders.include?('BOOK_GENRE')
      puts '  • Writing Style: How should the story be told? (humorous, serious, adventurous, etc.)' if e.unfilled_placeholders.include?('BOOK_STYLE') || e.unfilled_placeholders.include?('BOOK_HUMOR_STYLE')
      puts '  • Setting: Where does your story take place? (medieval castle, space station, modern city, etc.)' if e.unfilled_placeholders.include?('BOOK_SETTING') || e.unfilled_placeholders.include?('PRIMARY_LOCATION')
      puts '  • World Details: What makes your story world unique?' if e.unfilled_placeholders.include?('WORLD_DETAILS')
      puts ''
      puts '🔧 For immediate help, contact support or check documentation'
      puts ''
      raise BookCore::LLMService::LLMError, 'Book setup incomplete - missing required metadata for chapter generation'
    end

    def write_chapter_file(chapter_number, chapter_data, character_slugs = [])
      if @output_adapter
        content = chapter_data['content']
        word_count = content.split(/\s+/).length
        chapter_slug = "#{format('%03d', chapter_number)}-chapter"
        permalink = "/chapters/#{chapter_slug}/"
        metadata = {
          title: chapter_data['title'] || "Chapter #{chapter_number}",
          chapter_number: chapter_number,
          characters: character_slugs,
          summary: chapter_data['summary'],
          programming_themes: chapter_data['programming_themes'] || [],
          comedy_elements: chapter_data['comedy_elements'] || [],
          word_count: word_count,
          difficulty_level: chapter_data['difficulty_level'],
          one_punch_man_references: chapter_data['one_punch_man_references'] || [],
          permalink: permalink,
          generated_date: Date.today.to_s,
          status: 'generated',
          lang: 'en',
          new_characters: (chapter_data['new_characters'] || []).map { |c| c['name'] }.map { |n| n.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_+|_+$/, '') }
        }
        @output_adapter.write_chapter(chapter_number, content, metadata)
      else
        # Fallback: write directly to filesystem (book content, not site)
        chapters_dir = preferred_chapters_dir
        FileUtils.mkdir_p(chapters_dir)
        filename = File.join(chapters_dir, "#{format('%03d', chapter_number)}-chapter.md")
        content = chapter_data['content']
        word_count = content.split(/\s+/).length
        chapter_slug = "#{format('%03d', chapter_number)}-chapter"
        permalink = "/chapters/#{chapter_slug}/"
        front_matter_hash = {
          'layout' => 'chapter',
          'title' => chapter_data['title'] || "Chapter #{chapter_number}",
          'chapter_number' => chapter_number,
          'characters' => character_slugs,
          'summary' => chapter_data['summary'],
          'programming_themes' => chapter_data['programming_themes'] || [],
          'comedy_elements' => chapter_data['comedy_elements'] || [],
          'word_count' => word_count,
          'difficulty_level' => chapter_data['difficulty_level'],
          'one_punch_man_references' => chapter_data['one_punch_man_references'] || [],
          'permalink' => permalink,
          'generated_date' => Date.today.to_s,
          'status' => 'generated',
          'lang' => 'en'
        }
        front_matter = front_matter_hash.to_yaml
        full_content = "#{front_matter}---\n\n#{content}"
        File.write(filename, full_content)
      end
    end

    def update_book_progress(chapter_number)
      metadata_path = File.join(@project_root, 'data', 'book_metadata.yml')
      metadata = File.exist?(metadata_path) ? (YAML.safe_load_file(metadata_path) || {}) : {}
      metadata['book'] ||= {}
      metadata['book']['current_chapter'] = chapter_number
      FileUtils.mkdir_p(File.dirname(metadata_path))
      File.write(metadata_path, metadata.to_yaml)

      puts "📈 Updated book progress: Chapter #{chapter_number} completed"

      # Simple summary
      puts "\n📊 Chapter Generation Summary"
      puts '=' * 40
      # Best-effort print: read back the file and count words
      filename = File.join(preferred_chapters_dir, "#{format('%03d', chapter_number)}-chapter.md")
      wc = 0
      if File.exist?(filename)
        text = File.read(filename)
        parts = text.split(/^---\s*$/, 3)
        wc = parts.length >= 3 ? parts[2].split(/\s+/).length : 0
      end
      puts "Title: #{chapter_data_title_for_print(chapter_number)}"
      puts "Word Count: #{wc.positive? ? wc : 'Not specified'}"
      puts 'Difficulty: Not specified'
      puts '=' * 40
    end

    def chapter_data_title_for_print(chapter_number)
      "Chapter #{chapter_number}"
    end

    def determine_next_chapter_number
      chapters_dir = preferred_chapters_dir
      max_from_files = 0
      if Dir.exist?(chapters_dir)
        Dir.glob(File.join(chapters_dir, '*.md')).each do |path|
          basename = File.basename(path)
          # Match NNN-chapter.md only (no language suffix)
          if basename =~ /^(\d{3})-chapter\.md$/
            num = Regexp.last_match(1).to_i
            max_from_files = [max_from_files, num].max
          end
        end
      end

      metadata_path = File.join(@project_root, 'data', 'book_metadata.yml')
      current_in_metadata = 0
      if File.exist?(metadata_path)
        md = YAML.safe_load_file(metadata_path) || {}
        current_in_metadata = md.dig('book', 'current_chapter').to_i if md.dig('book', 'current_chapter')
      end

      next_num = [max_from_files, current_in_metadata].max + 1
      puts "[debug] Chapters dir: #{chapters_dir} | highest: #{max_from_files} | metadata: #{current_in_metadata} | next: #{next_num}"
      next_num
    end

    def preferred_chapters_dir
      # Prefer content/chapters
      content_dir = File.join(@project_root, 'content', 'chapters')
      return content_dir if Dir.exist?(content_dir)

      # Then root-level _chapters
      legacy_dir = File.join(@project_root, '_chapters')
      return legacy_dir if Dir.exist?(legacy_dir)

      # Avoid nested paths like books/one-review-man/books/one-review-man/_chapters
      nested_legacy = File.join(@project_root, 'books', 'one-review-man', '_chapters')
      return nested_legacy if Dir.exist?(nested_legacy)

      # Default to content/chapters to create if missing
      content_dir
    end

    def default_prompt_provider
      # Use the core prompt provider that searches the book and then core prompts
      BookCore::PromptProvider.new(book_root: @project_root)
    end

    def default_output_adapter
      # Write into book content directories by default
      require 'book_core/book_content_adapter'
      adapter = BookCore::BookContentAdapter.new
      adapter.setup_project(@project_root)
      adapter
    end

    def create_new_characters(new_characters)
      return if new_characters.nil? || new_characters.empty?

      chars_data_path = File.join(@project_root, 'data', 'characters.yml')
      characters_yaml = File.exist?(chars_data_path) ? (YAML.safe_load_file(chars_data_path) || {}) : {}
      # Normalize to structure with 'characters' nested under 'en' if present
      if characters_yaml['en']
        characters_yaml['en']['characters'] ||= {}
        store = characters_yaml['en']
      else
        characters_yaml['characters'] ||= {}
        store = characters_yaml
      end

      new_characters.each do |c|
        name = c['name'] || next
        slug = ValidationUtils.slugify(name)
        if ValidationUtils.blank?(slug)
          puts "⚠️  Warning: Could not generate valid slug for character '#{name}', skipping"
          next
        end

        # Check for slug uniqueness and generate alternative if needed
        original_slug = slug
        counter = 1
        while store['characters'].key?(slug)
          slug = "#{original_slug}-#{counter}"
          counter += 1
          if counter > 100 # Prevent infinite loops
            puts "⚠️  Warning: Could not generate unique slug for character '#{name}', skipping"
            next
          end
        end

        puts "ℹ️  Info: Character '#{name}' slug changed from '#{original_slug}' to '#{slug}' to avoid conflict" if slug != original_slug

        # Build rich character prompt from template if available
        template = begin
          @prompt_provider.load('new_character_creation_prompt.txt')
        rescue StandardError
          nil
        end
        character_prompt = nil
        if template
          chars = load_characters_abs
          placeholders = build_character_creation_placeholders(name, c['description'] || 'Brief mention only', chars)
          character_prompt = PromptUtils.build_prompt(template, placeholders, context: "character '#{name}' creation")
        else
          character_prompt = "Create character profile for #{name}: #{c['description']}"
        end

        begin
          full = @llm_service.generate_character(character_prompt)
          character_data = {
            'name' => name,
            'description' => full['description'] || c['description'] || '',
            'personality_traits' => full['personality_traits'] || [],
            'programming_skills' => full['programming_skills'] || 'General programming',
            'catchphrase' => full['catchphrase'],
            'backstory' => full['backstory'],
            'quirks' => full['quirks'],
            'first_appearance' => "Chapter #{@current_chapter_number}",
            'slug' => slug,
            'created_date' => Date.today.to_s,
            'language' => 'en'
          }.compact
        rescue StandardError => e
          puts "⚠️  Warning: Failed to generate character details for '#{name}': #{e.message}"
          puts '   Using fallback character data instead.'
          character_data = {
            'name' => name,
            'description' => c['description'] || 'New character',
            'first_appearance' => "Chapter #{@current_chapter_number}",
            'slug' => slug,
            'created_date' => Date.today.to_s,
            'language' => 'en'
          }
        end

        store['characters'][slug] = character_data
        @output_adapter.write_character_page(slug, character_data) if @output_adapter.respond_to?(:write_character_page)
      end

      # Persist characters.yml
      FileUtils.mkdir_p(File.dirname(chars_data_path))
      if characters_yaml['en']
        File.write(chars_data_path, characters_yaml.to_yaml)
      else
        File.write(chars_data_path, store.to_yaml)
      end
    end

    def extract_and_store_story_facts(story_facts, chapter_number)
      return if story_facts.nil? || story_facts.empty?

      facts_path = File.join(@project_root, 'data', 'story_facts.yml')
      facts_data = File.exist?(facts_path) ? (YAML.safe_load_file(facts_path) || {}) : {}

      # Ensure structure
      facts_data['en'] ||= {}
      facts_data['en']['facts'] ||= {}
      store = facts_data['en']['facts']

      # Process each fact type
      %w[locations events world_rules relationships].each do |fact_type|
        next unless story_facts[fact_type].is_a?(Array) && !story_facts[fact_type].empty?

        store[fact_type] ||= {}
        story_facts[fact_type].each do |fact|
          next if fact.nil? || !fact.is_a?(Hash)

          fact_key = generate_fact_key(fact, fact_type)
          next if ValidationUtils.blank?(fact_key)

          # Avoid duplicates - check if fact already exists
          unless store[fact_type].key?(fact_key)
            normalized_fact = normalize_fact(fact, fact_type, chapter_number)
            store[fact_type][fact_key] = normalized_fact if normalized_fact
          end
        end
      end

      # Persist story_facts.yml
      FileUtils.mkdir_p(File.dirname(facts_path))
      File.write(facts_path, facts_data.to_yaml)
    end

    def generate_fact_key(fact, fact_type)
      case fact_type
      when 'locations'
        name = fact['name']&.to_s&.strip
        return nil if ValidationUtils.blank?(name)

        ValidationUtils.slugify(name)
      when 'events'
        name = fact['name']&.to_s&.strip
        return nil if ValidationUtils.blank?(name)

        ValidationUtils.slugify(name)
      when 'world_rules'
        rule = fact['rule']&.to_s&.strip
        return nil if ValidationUtils.blank?(rule)

        # Create a short slug from the first few words of the rule
        rule_words = rule.split.first(3).join(' ')
        ValidationUtils.slugify(rule_words)
      when 'relationships'
        char1 = fact['character1']&.to_s&.strip
        char2 = fact['character2']&.to_s&.strip
        return nil if ValidationUtils.blank?(char1) || ValidationUtils.blank?(char2)

        # Create a consistent key regardless of order
        names = [ValidationUtils.slugify(char1), ValidationUtils.slugify(char2)].sort
        "#{names[0]}_#{names[1]}"
      end
    end

    def normalize_fact(fact, fact_type, chapter_number)
      case fact_type
      when 'locations'
        {
          'name' => fact['name']&.to_s&.strip,
          'description' => fact['description']&.to_s&.strip,
          'type' => fact['type']&.to_s&.strip || 'other',
          'first_mentioned' => "Chapter #{chapter_number}",
          'status' => 'established'
        }.compact.reject { |_, v| ValidationUtils.blank?(v) }
      when 'events'
        {
          'name' => fact['name']&.to_s&.strip,
          'description' => fact['description']&.to_s&.strip,
          'chapter' => chapter_number,
          'impact' => fact['impact']&.to_s&.strip || 'minor'
        }.compact.reject { |_, v| ValidationUtils.blank?(v) }
      when 'world_rules'
        {
          'rule' => fact['rule']&.to_s&.strip,
          'category' => fact['category']&.to_s&.strip || 'other',
          'established' => "Chapter #{chapter_number}"
        }.compact.reject { |_, v| ValidationUtils.blank?(v) }
      when 'relationships'
        {
          'character1' => fact['character1']&.to_s&.strip,
          'character2' => fact['character2']&.to_s&.strip,
          'relationship' => fact['relationship']&.to_s&.strip || 'other',
          'status' => fact['status']&.to_s&.strip || 'established',
          'first_chapter' => chapter_number
        }.compact.reject { |_, v| ValidationUtils.blank?(v) }
      end
    end

    def build_story_facts_context
      story_facts = load_story_facts
      return {} unless story_facts&.dig('en', 'facts')

      facts = story_facts['en']['facts']
      placeholders = {}

      # Build locations context
      if facts['locations'] && !facts['locations'].empty?
        location_list = facts['locations'].map do |_key, location|
          "- #{location['name']}: #{location['description']} (#{location['type']})"
        end
        placeholders['ESTABLISHED_LOCATIONS'] = location_list.join("\n")
      end

      # Build events context
      if facts['events'] && !facts['events'].empty?
        event_list = facts['events'].map do |_key, event|
          "- #{event['name']} (Chapter #{event['chapter']}): #{event['description']}"
        end
        placeholders['ESTABLISHED_EVENTS'] = event_list.join("\n")
      end

      # Build world rules context
      if facts['world_rules'] && !facts['world_rules'].empty?
        rules_list = facts['world_rules'].map do |_key, rule|
          "- #{rule['rule']} (#{rule['category']})"
        end
        placeholders['WORLD_RULES'] = rules_list.join("\n")
      end

      # Build relationships context
      if facts['relationships'] && !facts['relationships'].empty?
        relationship_list = facts['relationships'].map do |_key, rel|
          "- #{rel['character1']} and #{rel['character2']}: #{rel['relationship']}"
        end
        placeholders['CHARACTER_RELATIONSHIPS'] = relationship_list.join("\n")
      end

      placeholders
    end

    def load_story_facts
      facts_path = File.join(@project_root, 'data', 'story_facts.yml')
      return {} unless File.exist?(facts_path)

      YAML.safe_load_file(facts_path) || {}
    rescue StandardError => e
      puts "⚠️  Warning: Failed to load story facts: #{e.message}"
      {}
    end

    def build_content_rules_context(book_metadata)
      return {} unless book_metadata

      content_rules = book_metadata.dig('generation', 'content_rules')
      return {} unless content_rules

      placeholders = {}

      # World physics rules
      if content_rules['world_physics'].is_a?(Array)
        physics_list = content_rules['world_physics'].map { |rule| "- #{rule}" }
        placeholders['WORLD_PHYSICS_RULES'] = physics_list.join("\n")
      end

      # Style guidelines
      if content_rules['style_guidelines'].is_a?(Array)
        style_list = content_rules['style_guidelines'].map { |rule| "- #{rule}" }
        placeholders['STYLE_GUIDELINES'] = style_list.join("\n")
      end

      # Content requirements
      if content_rules['content_requirements'].is_a?(Array)
        requirements_list = content_rules['content_requirements'].map { |rule| "- #{rule}" }
        placeholders['CONTENT_REQUIREMENTS'] = requirements_list.join("\n")
      end

      # Character dynamics
      if content_rules['character_dynamics']
        dynamics = content_rules['character_dynamics']
        dynamics_text = []

        if dynamics['protagonist_addressing']
          case dynamics['protagonist_addressing']
          when 'real_names_in_dialogue'
            dynamics_text << '- Characters use real names when speaking directly to the protagonist'
          when 'professional_titles'
            dynamics_text << '- Characters use professional titles when addressing the protagonist'
          end
        end

        if dynamics['mentor_student_pattern']
          case dynamics['mentor_student_pattern']
          when 'sensei_usage'
            dynamics_text << "- Student characters address mentor as 'sensei' or by real name"
          end
        end

        dynamics_text << "- Colleagues consistently dismiss protagonist's abilities as luck" if dynamics['colleague_dismissal_theme']

        if dynamics['underestimation_pattern']
          case dynamics['underestimation_pattern']
          when 'consistent_dismissal'
            dynamics_text << '- Others always underestimate protagonist until proven wrong'
          end
        end

        placeholders['CHARACTER_DYNAMICS'] = dynamics_text.join("\n") unless dynamics_text.empty?
      end

      # Parody and humor style
      placeholders['PARODY_SOURCE'] = content_rules['parody_source'] if content_rules['parody_source']

      placeholders['HUMOR_STYLE'] = content_rules['humor_style'] if content_rules['humor_style']

      placeholders
    end

    def migrate_world_data_to_story_facts
      world_path = File.join(@project_root, 'data', 'world.yml')
      facts_path = File.join(@project_root, 'data', 'story_facts.yml')

      # Skip if no world.yml or story_facts.yml already exists
      return false unless File.exist?(world_path)
      return false if File.exist?(facts_path)

      begin
        world_data = YAML.safe_load_file(world_path)
        return false unless world_data&.dig('en', 'world')

        world = world_data['en']['world']
        story_facts = { 'en' => { 'facts' => {} } }
        facts = story_facts['en']['facts']

        # Migrate locations
        if world['locations']
          facts['locations'] = {}
          world['locations'].each do |key, location|
            facts['locations'][key] = {
              'name' => location['name'],
              'description' => location['description'],
              'type' => location['type'] || 'location',
              'first_mentioned' => location['established_chapter'] || 'Chapter 1',
              'status' => 'established'
            }.compact
          end
        end

        # Migrate company info as a location
        if world['company']
          facts['locations'] ||= {}
          facts['locations']['company_office'] = {
            'name' => world['company']['name'],
            'description' => world['company']['description'],
            'type' => world['company']['type'] || 'office',
            'first_mentioned' => world['company']['established_chapter'] || 'Chapter 1',
            'status' => 'established'
          }.compact
        end

        # Migrate meetings as events
        if world['meetings']
          facts['events'] ||= {}
          world['meetings'].each do |key, meeting|
            facts['events'][key] = {
              'name' => meeting['name'],
              'description' => meeting['description'],
              'chapter' => 1, # Default to chapter 1 for recurring meetings
              'impact' => 'minor'
            }.compact
          end
        end

        # Migrate infrastructure as world rules
        if world['infrastructure']
          facts['world_rules'] ||= {}
          world['infrastructure'].each do |key, infra|
            facts['world_rules'][key] = {
              'rule' => "#{infra['name']}: #{infra['description']}",
              'category' => 'technology',
              'established' => infra['established_chapter'] || 'Chapter 1'
            }.compact
          end
        end

        # Migrate culture as world rules
        if world['culture']
          facts['world_rules'] ||= {}
          world['culture'].each do |key, culture|
            facts['world_rules']["culture_#{key}"] = {
              'rule' => culture['description'],
              'category' => 'culture',
              'established' => culture['established_chapter'] || 'Chapter 1'
            }.compact
          end
        end

        # Migrate established_facts as world rules
        if world['established_facts'].is_a?(Array)
          facts['world_rules'] ||= {}
          world['established_facts'].each_with_index do |fact, index|
            facts['world_rules']["established_fact_#{index + 1}"] = {
              'rule' => fact,
              'category' => 'culture',
              'established' => 'Chapter 1'
            }
          end
        end

        # Write new story_facts.yml
        FileUtils.mkdir_p(File.dirname(facts_path))
        File.write(facts_path, story_facts.to_yaml)

        puts '✅ Migrated world.yml to story_facts.yml'
        puts "   Locations: #{facts['locations']&.size || 0}"
        puts "   Events: #{facts['events']&.size || 0}"
        puts "   World Rules: #{facts['world_rules']&.size || 0}"

        true
      rescue StandardError => e
        puts "⚠️  Warning: Failed to migrate world.yml: #{e.message}"
        false
      end
    end

    def build_main_character_placeholders(book_metadata, chars)
      return {} unless book_metadata

      placeholders = {}

      # Check for new-style main character configuration
      main_characters = book_metadata.dig('generation', 'main_characters')
      if main_characters.is_a?(Array)
        # New generic approach: iterate through configured main characters
        main_characters.each do |char_config|
          display_name = char_config['display_name']
          placeholder_key = char_config['placeholder_key']

          next unless display_name && placeholder_key

          real_name = find_character_real_name(chars, display_name) || '[to be generated]'
          placeholders[placeholder_key] = real_name
        end
      elsif one_review_man_book?(book_metadata)
        # Fallback: backward compatibility for OneReviewMan book
        one_review_man_real = find_character_real_name(chars, 'One Review Man') || '[to be generated]'
        quantum_android_real = find_character_real_name(chars, 'Quantum Android') || '[to be generated]'
        placeholders.merge!({
                              'ONE_REVIEW_MAN_REAL_NAME' => one_review_man_real,
                              'QUANTUM_ANDROID_REAL_NAME' => quantum_android_real
                            })
      end

      placeholders
    end

    # --- Helpers ported to mirror main branch behaviour ---

    def select_characters_for_chapter(chapter_num, characters_data = nil)
      characters_hash = characters_data || load_characters_abs
      all_characters = (characters_hash['characters'] || {}).values
      return [] if all_characters.empty?

      if chapter_num == 1
        all_characters.take(2)
      elsif chapter_num <= 3
        all_characters.take([chapter_num + 1, all_characters.size].min)
      else
        all_characters.sample([3, all_characters.size].min)
      end
    end

    def build_previous_chapters_summary(chapter_num)
      prev = []
      Dir.glob(File.join(preferred_chapters_dir, '*.md')).each do |path|
        basename = File.basename(path)
        next unless basename =~ /^(\d{3})-chapter\.md$/

        num = Regexp.last_match(1).to_i
        next unless num < chapter_num

        fm = extract_front_matter(path)
        title = (fm['title'] || "Chapter #{num}").to_s.gsub('{CHAPTER_NUMBER}', num.to_s)
        summary = (fm['summary'] || 'Summary not available').to_s.gsub('{CHAPTER_NUMBER}', num.to_s)
        prev << "Chapter #{num}: #{title} - #{summary}"
      end
      return 'This is the first chapter.' if prev.empty?

      prev.sort_by { |line| line[/Chapter\s+(\d+)/, 1].to_i }.join("\n")
    end

    def build_character_context(chars)
      ValidationUtils.safe_array(chars).map do |char|
        traits = ValidationUtils.safe_array(char['personality_traits']).join(', ')
        skills = ValidationUtils.presence_or(char['programming_skills'], 'General programming')
        name = ValidationUtils.presence_or(char['name'] || char['slug'], 'Unknown')
        description = ValidationUtils.safe_string(char['description'])
        traits_text = ValidationUtils.present?(traits) ? traits : 'None specified'
        "#{name}: #{description} (Traits: #{traits_text}, Skills: #{skills})"
      end.join("\n")
    end

    def load_book_metadata_abs
      path = File.join(@project_root, 'data', 'book_metadata.yml')
      File.exist?(path) ? (YAML.safe_load_file(path) || {}) : {}
    end

    def load_characters_abs
      path = File.join(@project_root, 'data', 'characters.yml')
      data = File.exist?(path) ? (YAML.safe_load_file(path) || {}) : {}
      if data['en']
        data['en']
      elsif data['characters']
        data
      else
        { 'characters' => {} }
      end
    end

    def load_generation_log_abs
      path = File.join(@project_root, 'data', 'generation_log.yml')
      File.exist?(path) ? (YAML.safe_load_file(path) || {}) : {}
    end

    def find_character_real_name(chars_data, display_name)
      values = (chars_data['characters'] || {}).values
      values.find { |c| c['name'] == display_name }&.dig('real_name')
    end

    def build_chapter_placeholders(chapter_number, book_metadata, chars, character_context, used_devices, previous_summary)
      placeholders = {
        'CHAPTER_NUMBER' => chapter_number.to_s,
        'TARGET_LENGTH' => book_metadata.dig('generation', 'chapter_length_target') || '1500-3000 words',
        'PREVIOUS_CHAPTERS_SUMMARY' => previous_summary,
        'CHARACTER_CONTEXT' => character_context.empty? ? 'No existing characters.' : "Existing characters:\n#{character_context}",
        'USED_PLOT_DEVICES' => used_devices.join(', '),
        'SPECIAL_INSTRUCTIONS' => get_special_instructions(chapter_number),
        'CHARACTER_NAME' => '',
        'CHARACTER_DESCRIPTION' => '',
        'CHARACTER_TRAITS' => '',
        'CHARACTER_CODING_LEVEL' => '',
        'CHARACTER_RELATIONSHIP' => ''
      }

      # Add generic book metadata placeholders
      if book_metadata && book_metadata['localized'] && book_metadata['localized']['en']
        en_metadata = book_metadata['localized']['en']
        placeholders.merge!({
                              'BOOK_TITLE' => en_metadata['title'] || 'Untitled Book',
                              'BOOK_GENRE' => en_metadata['genre'] || 'Fiction',
                              'BOOK_SETTING' => determine_book_setting(en_metadata),
                              'BOOK_STYLE' => en_metadata['humor_style'] || 'narrative',
                              'PRIMARY_LOCATION' => extract_primary_location(en_metadata),
                              'WORLD_DETAILS' => build_world_details_summary(en_metadata),
                              'CHARACTER_GUIDELINES' => build_character_guidelines(en_metadata),
                              'GENRE_GUIDELINES' => build_genre_guidelines(en_metadata)
                            })
      end

      # Add story facts context to placeholders
      story_facts_placeholders = build_story_facts_context
      placeholders.merge!(story_facts_placeholders) if story_facts_placeholders

      # Add content generation rules to placeholders
      content_rules_placeholders = build_content_rules_context(book_metadata)
      placeholders.merge!(content_rules_placeholders) if content_rules_placeholders

      # Add main character placeholders based on book configuration
      main_character_placeholders = build_main_character_placeholders(book_metadata, chars)
      placeholders.merge!(main_character_placeholders) if main_character_placeholders

      placeholders
    end

    def build_character_creation_placeholders(character_name, character_description, chars)
      placeholders = {
        'CHAPTER_NUMBER' => @current_chapter_number.to_s,
        'CHARACTER_NAME' => character_name,
        'CHARACTER_DESCRIPTION' => character_description
      }

      # Add only the main character placeholders that are actually used in the template
      book_metadata = load_book_metadata_abs
      main_character_placeholders = build_main_character_placeholders(book_metadata, chars)
      placeholders.merge!(main_character_placeholders) if main_character_placeholders

      placeholders
    end

    def one_review_man_book?(book_metadata)
      return false unless book_metadata

      title = book_metadata.dig('localized', 'en', 'title')
      title&.include?('One Review Man') || title&.include?('Ванревьюмэн')
    end

    def determine_book_setting(en_metadata)
      themes = en_metadata['themes']
      return 'Modern tech company/startup environment' if themes&.dig('primary') == 'workplace comedy'
      return 'Contemporary setting' if en_metadata['genre']&.downcase&.include?('comedy')

      'Generic setting'
    end

    def extract_primary_location(en_metadata)
      themes = en_metadata['themes']
      return 'Corporate office' if themes&.dig('primary') == 'workplace comedy'

      'Main setting'
    end

    def build_world_details_summary(en_metadata)
      details = []
      details << "Genre: #{en_metadata['genre']}" if en_metadata['genre']
      details << "Style: #{en_metadata['humor_style']}" if en_metadata['humor_style']
      if (themes = en_metadata['themes'])
        details << "Primary theme: #{themes['primary']}" if themes['primary']
        details << "Secondary themes: #{themes['secondary']&.join(', ')}" if themes['secondary']&.any?
      end
      details.join('; ')
    end

    def build_character_guidelines(en_metadata)
      return 'Characters should fit the genre and established world' unless en_metadata

      guidelines = []
      if en_metadata['genre']&.downcase&.include?('comedy')
        guidelines << 'Characters should have comedic elements and quirks'
        guidelines << 'Dialogue should be humorous and character-appropriate'
      end

      if en_metadata.dig('themes', 'primary') == 'workplace comedy'
        guidelines << 'Characters should fit a professional workplace environment'
        guidelines << 'Include workplace-appropriate personalities and roles'
      end

      guidelines.empty? ? 'Characters should serve the story and be well-developed' : guidelines.join('; ')
    end

    def build_genre_guidelines(en_metadata)
      return 'Follow general fiction conventions' unless en_metadata

      genre = en_metadata['genre']&.downcase
      return 'Focus on humor, character comedy, and amusing situations' if genre&.include?('comedy')
      return 'Build suspense and include mystery elements' if genre&.include?('mystery')
      return 'Include fantastical elements and world-building' if genre&.include?('fantasy')

      'Follow conventions appropriate to the established genre and style'
    end

    def attempt_interactive_metadata_collection(missing_placeholders, auto_generate: false)
      # Check if we're in auto mode or if STDIN is not available for interaction
      return false if auto_generate || ENV['CI'] || !$stdin.tty? || missing_placeholders.empty?

      puts ''
      puts '🤔 I notice some information is missing for chapter generation.'
      puts 'Would you like to provide this information now? (y/n)'

      begin
        response = $stdin.gets&.chomp&.downcase
        return false unless %w[y yes].include?(response)
      rescue Interrupt
        puts "\nOperation cancelled."
        return false
      end

      puts ''
      puts "📝 Let's fill in the missing information:"
      puts ''

      # Load current metadata
      metadata_path = File.join(@project_root, 'data', 'book_metadata.yml')
      metadata = if File.exist?(metadata_path)
                   YAML.safe_load_file(metadata_path) || {}
                 else
                   {}
                 end

      # Ensure localized structure exists
      metadata['localized'] ||= {}
      metadata['localized']['en'] ||= {}
      en_metadata = metadata['localized']['en']

      # Collect missing information
      updated = false

      if missing_placeholders.include?('BOOK_GENRE') && en_metadata['genre'].to_s.strip.empty?
        puts '📖 What genre is your book?'
        puts '   Examples: fantasy, sci-fi, mystery, thriller, comedy, romance, adventure, horror'
        print '   Genre: '
        genre = $stdin.gets&.chomp&.strip
        unless genre.empty?
          en_metadata['genre'] = genre
          updated = true
        end
      end

      if (missing_placeholders.include?('BOOK_STYLE') || missing_placeholders.include?('BOOK_HUMOR_STYLE')) &&
         en_metadata['humor_style'].to_s.strip.empty?
        puts ''
        puts '✍️ What writing style should I use?'
        puts '   Examples: humorous, serious, adventurous, suspenseful, whimsical, dramatic'
        print '   Style: '
        style = $stdin.gets&.chomp&.strip
        unless style.empty?
          en_metadata['humor_style'] = style
          updated = true
        end
      end

      if (missing_placeholders.include?('BOOK_SETTING') || missing_placeholders.include?('PRIMARY_LOCATION')) &&
         en_metadata['setting'].to_s.strip.empty?
        puts ''
        puts '🌍 What is the main setting/location of your story?'
        puts '   Examples: medieval castle, space station, modern city, magical school, etc.'
        print '   Setting: '
        setting = $stdin.gets&.chomp&.strip
        unless setting.empty?
          en_metadata['setting'] = setting
          updated = true
        end
      end

      if missing_placeholders.include?('WORLD_DETAILS') &&
         (en_metadata['themes'].nil? || en_metadata['themes']['primary'].to_s.strip.empty?)
        puts ''
        puts '🎭 What is the primary theme of your story?'
        puts '   Examples: friendship, mystery, adventure, love, betrayal, discovery, etc.'
        print '   Primary theme: '
        theme = $stdin.gets&.chomp&.strip
        unless theme.empty?
          en_metadata['themes'] ||= {}
          en_metadata['themes']['primary'] = theme
          updated = true
        end
      end

      if updated
        # Save updated metadata
        File.write(metadata_path, metadata.to_yaml)

        # Also update world.yml if it exists
        world_path = File.join(@project_root, 'data', 'world.yml')
        if File.exist?(world_path) && en_metadata['setting']
          world_data = YAML.safe_load_file(world_path) || {}
          world_data['en'] ||= {}
          world_data['en']['world'] ||= {}
          world_data['en']['world']['main_setting'] ||= {}
          world_data['en']['world']['main_setting']['name'] = en_metadata['setting']
          world_data['en']['world']['main_setting']['description'] = 'The primary location where the story unfolds'
          world_data['en']['world']['established_facts'] ||= []

          # Update facts with new information
          facts = world_data['en']['world']['established_facts']
          facts.clear # Remove old facts
          facts << "Story takes place in #{en_metadata['setting']}" if en_metadata['setting']
          facts << "Genre focuses on #{en_metadata['genre']} elements" if en_metadata['genre']
          facts << "Primary theme is #{en_metadata.dig('themes', 'primary')}" if en_metadata.dig('themes', 'primary')
          facts << "Writing style is #{en_metadata['humor_style']}" if en_metadata['humor_style']

          File.write(world_path, world_data.to_yaml)
        end

        puts ''
        puts '✅ Information saved! Continuing with chapter generation...'
        puts ''
        true
      else
        puts ''
        puts 'ℹ️ No information was provided. Chapter generation cannot continue.'
        false
      end
    rescue Interrupt
      puts "\nOperation cancelled."
      false
    rescue StandardError => e
      puts "\n❌ Error collecting information: #{e.message}"
      false
    end

    def extract_front_matter(file_path)
      content = File.read(file_path)
      if (m = content.match(/\A---\s*\n(.*?)\n---/m))
        YAML.safe_load(m[1]) || {}
      else
        {}
      end
    end

    def get_special_instructions(chapter_num)
      if chapter_num == 1
        'This is the first chapter - introduce the main character and establish the workplace setting.'
      elsif chapter_num <= 3
        'This is an early chapter - continue building the world and introducing characters.'
      else
        'Build on established relationships and escalate the comedy.'
      end
    end
  end
end
