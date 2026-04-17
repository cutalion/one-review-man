# frozen_string_literal: true

require 'yaml'
require 'date'
require 'fileutils'
require 'eidos/llm_service'
require 'eidos/prompt_provider'
require 'eidos/world_utils'
require 'eidos/prompt_utils'
require 'eidos/env_utils'
require 'eidos/validation_utils'
require 'eidos/world_config'
require 'eidos/snapshot_store'
require 'eidos/story_bible'
require 'eidos/canon_version_reference'

module Eidos
  # Main engine for generating book chapters using AI models
  class ChapterGenerator
    include WorldUtils

    def initialize(model_override = nil, snapshot: nil, **kwargs)
      @model_override = model_override
      @project_root = File.expand_path(kwargs[:project_root] || Dir.pwd)
      @snapshot_name = snapshot
      @book_data = kwargs[:book_data] || {}
      @characters = kwargs[:characters] || {}
      @generation_log = kwargs[:generation_log] || {}
      @prompt_provider = kwargs[:prompt_provider] || default_prompt_provider
      @output_adapter = kwargs[:output_adapter] || default_output_adapter

      # Initialize WorldConfig - can be injected for testing or loaded from project
      @config = kwargs[:book_config] || kwargs[:config] || begin
        Eidos::WorldConfig.load_from_project(@project_root)
      rescue Eidos::WorldConfig::NotFoundError
        Eidos::WorldConfig.new
      end

      # Initialize LLMService with injected config or load default
      if kwargs[:configuration]
        @llm_service = kwargs[:llm_service] || Eidos::LLMService.new(kwargs[:configuration])
      else
        # Fallback for legacy calls or tests not using config object
        # We need to construct a config object here if not provided, or LLMService will fail
        # But LLMService expects a hash now.
        config = Eidos::Configuration.load(@project_root, { 'llm.model' => model_override })
        @llm_service = kwargs[:llm_service] || Eidos::LLMService.new(config)
      end

      # Ensure adapter is configured with project root if provided
      return unless @output_adapter.respond_to?(:setup_project)

      @output_adapter.setup_project(@project_root)
    end

    def generate_next_chapter(auto_generate: false, extra_guidance: nil)
      next_chapter = determine_next_chapter_number
      @current_chapter_number = next_chapter

      puts "Generating Chapter #{next_chapter} using model #{@llm_service.get_model_for_task('generation')}..."

      # Determine characters for this chapter (parity with main)
      character_objects = select_characters_for_chapter(next_chapter)
      character_slugs = character_objects.map { |c| c['slug'] || slugify(c['name'].to_s) }

      chapter_data = generate_chapter_structured(next_chapter, auto_generate: auto_generate, extra_guidance: extra_guidance)

      write_chapter_file(next_chapter, chapter_data, character_slugs)
      create_new_characters(chapter_data['new_characters']) if chapter_data['new_characters'].is_a?(Array)
      extract_and_store_story_facts(chapter_data['story_facts'], next_chapter) if chapter_data['story_facts'].is_a?(Hash)

      update_book_progress(next_chapter, chapter_data)

      puts "✅ Chapter #{next_chapter} generated successfully!"

      chapter_data['content']
    end

    private

    def generate_chapter_structured(chapter_number, auto_generate: false, extra_guidance: nil)
      prompt = build_chapter_prompt(chapter_number, auto_generate: auto_generate)
      prompt = append_extra_guidance(prompt, extra_guidance)
      data = @llm_service.generate_chapter_structured(prompt, {})
      # Replace placeholders if present
      if data.is_a?(Hash)
        %w[title summary content].each do |key|
          next unless data[key]

          content = data[key].to_s
          content = content.gsub('{CHAPTER_NUMBER}', chapter_number.to_s)

          # Replace character name placeholders
          chars = load_characters_abs
          main_character_placeholders = build_main_character_placeholders(@config, chars)
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
      raise Eidos::LLMService::LLMError, 'Generated content too short' if !EnvUtils.mock_ai_enabled? && (data['content'].to_s.strip.length < 50)

      data
    end

    def build_chapter_prompt(chapter_number, auto_generate: false)
      template = load_chapter_template(chapter_number)
      placeholders = build_chapter_context(chapter_number)
      template = prefill_single_brace_placeholders(template, placeholders)

      PromptUtils.build_prompt(template, placeholders, warn_unused: false, context: "chapter #{chapter_number} generation")
    rescue PromptUtils::UnfilledPlaceholdersError => e
      handle_unfilled_placeholders(e, chapter_number, auto_generate)
    end

    # Append user-supplied guidance (from `eidos produce chapter --prompt "..."`)
    # as its own final section so the LLM treats it as an override, not decoration.
    def append_extra_guidance(prompt, extra_guidance)
      return prompt if extra_guidance.nil? || extra_guidance.to_s.strip.empty?

      "#{prompt}\n\nADDITIONAL GUIDANCE FROM USER (apply this on top of everything above):\n#{extra_guidance.strip}\n"
    end

    # Templates on disk use `{PLACEHOLDER}` (single-brace); PromptUtils only
    # recognizes `{{PLACEHOLDER}}`. Pre-substitute single-brace tokens so placeholders
    # like CHARACTER_CONTEXT actually reach the LLM.
    def prefill_single_brace_placeholders(template, placeholders)
      result = template.dup
      placeholders.each do |key, value|
        result.gsub!("{#{key}}", value.to_s)
      end
      result
    end

    def load_chapter_template(chapter_number)
      template = begin
        @prompt_provider.load('chapter_prompts.txt')
      rescue StandardError
        'Write Chapter {CHAPTER_NUMBER} of a programming comedy story'
      end
      # Fail-safe: pre-fill the chapter number in case template contains extra occurrences
      template.to_s.gsub('{CHAPTER_NUMBER}', chapter_number.to_s)
    end

    def build_chapter_context(chapter_number)
      previous_summary = build_previous_chapters_summary(chapter_number)
      chars = load_characters_abs
      selected_chars = select_characters_for_chapter(chapter_number, chars)
      character_context = build_character_context(selected_chars)
      used_devices = load_generation_log_abs['used_plot_devices'] || []
      world_ctx = Dir.chdir(@project_root) { build_world_context('en') }

      placeholders = build_chapter_placeholders(chapter_number, chars,
                                                character_context, used_devices, previous_summary)
      placeholders.merge!(world_ctx || {})
    end

    def handle_unfilled_placeholders(error, chapter_number, auto_generate)
      return handle_retry_after_collection(error, chapter_number) if attempt_interactive_metadata_collection(error.unfilled_placeholders, auto_generate: auto_generate)

      show_missing_information_error(error)
      raise Eidos::LLMService::LLMError, 'World setup incomplete - missing required metadata for chapter generation'
    end

    def handle_retry_after_collection(_original_error, chapter_number)
      # Retry with updated metadata - but only once to prevent infinite recursion

      template = load_chapter_template(chapter_number)
      placeholders = build_chapter_context(chapter_number)

      PromptUtils.build_prompt(template, placeholders, warn_unused: false, context: "chapter #{chapter_number} generation (retry)")
    rescue PromptUtils::UnfilledPlaceholdersError => e
      # If it still fails after metadata collection, fall back to error message
      show_missing_information_error(e)
      raise Eidos::LLMService::LLMError, 'World setup incomplete - missing required metadata for chapter generation'
    end

    def show_missing_information_error(error)
      puts ''
      puts '❌ Missing Information Required for Chapter Generation'
      puts ''
      puts 'Your world needs additional information before chapters can be generated.'
      puts "Missing: #{error.unfilled_placeholders.join(', ')}"
      puts ''
      show_fix_suggestions
      show_missing_information_guide(error.unfilled_placeholders)
      puts ''
      puts '🔧 For immediate help, contact support or check documentation'
      puts ''
    end

    def show_fix_suggestions
      puts '💡 To fix this issue:'
      puts '1. Update your world metadata with the missing information'
      puts "2. Or run 'world init' again in a new directory with complete setup"
      puts ''
    end

    def show_missing_information_guide(unfilled_placeholders)
      puts '📖 Missing Information Guide:'
      puts '  • BOOK_GENRE: What type of story is this? (fantasy, sci-fi, mystery, etc.)' if unfilled_placeholders.include?('BOOK_GENRE')
      puts '  • Writing Style: How should the story be told? (humorous, serious, adventurous, etc.)' if includes_style_placeholder?(unfilled_placeholders)
      puts '  • Setting: Where does your story take place? (medieval castle, space station, modern city, etc.)' if includes_setting_placeholder?(unfilled_placeholders)
      puts '  • World Details: What makes your story world unique?' if unfilled_placeholders.include?('WORLD_DETAILS')
    end

    def includes_style_placeholder?(unfilled_placeholders)
      unfilled_placeholders.include?('BOOK_STYLE') || unfilled_placeholders.include?('BOOK_HUMOR_STYLE')
    end

    def includes_setting_placeholder?(unfilled_placeholders)
      unfilled_placeholders.include?('BOOK_SETTING') || unfilled_placeholders.include?('PRIMARY_LOCATION')
    end

    public

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
          new_characters: (chapter_data['new_characters'] || []).map { |c| c['name'] }.map { |n| n.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_+|_+$/, '') },
          canon_version: resolve_canon_version
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

    def update_book_progress(chapter_number, chapter_data = {})
      @config.update_current_chapter(chapter_number).save!

      puts "📈 Updated world progress: Chapter #{chapter_number} completed"

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

      title = title_for_summary(chapter_data, chapter_number)
      puts "Title: #{title}"
      puts "Word Count: #{wc}" if wc.positive?
      difficulty = chapter_data['difficulty_level'].to_s.strip
      puts "Difficulty: #{difficulty}" unless difficulty.empty?
      puts '=' * 40
    end

    def title_for_summary(chapter_data, chapter_number)
      candidate = chapter_data.is_a?(Hash) ? chapter_data['title'].to_s.strip : ''
      candidate.empty? ? "Chapter #{chapter_number}" : candidate
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

      current_in_metadata = @config.current_chapter

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

      # Avoid nested paths like worlds/one-review-man/worlds/one-review-man/_chapters
      nested_legacy = File.join(@project_root, 'books', 'one-review-man', '_chapters')
      return nested_legacy if Dir.exist?(nested_legacy)

      # Default to content/chapters to create if missing
      content_dir
    end

    def resolve_canon_version
      bible_path = File.join(@project_root, Eidos::StoryBible::STORY_BIBLE_DIR)
      return 'unversioned' unless Dir.exist?(bible_path)

      store = SnapshotStore.new(story_bible_path: bible_path)
      CanonVersionReference.resolve(snapshot_store: store, explicit_snapshot: @snapshot_name)
    rescue SnapshotNotFoundError
      'unversioned'
    end

    def default_prompt_provider
      # Use the core prompt provider that searches the book and then core prompts
      Eidos::PromptProvider.new(book_root: @project_root)
    end

    def default_output_adapter
      # Write into book content directories by default
      require 'eidos/content_adapter'
      adapter = Eidos::ContentAdapter.new
      adapter.setup_project(@project_root)
      adapter
    end

    def create_new_characters(new_characters)
      return if new_characters.nil? || new_characters.empty?

      characters_yaml, store = load_characters_data

      new_characters.each do |c|
        character_data = process_character(c, store)
        next unless character_data

        store['characters'][character_data['slug']] = character_data
        write_character_page(character_data)
      end

      save_characters_data(characters_yaml, store)
    end

    private

    def load_characters_data
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

      [characters_yaml, store]
    end

    def process_character(character_info, store)
      name = character_info['name']
      return nil unless name

      slug = generate_unique_slug(name, store)
      return nil unless slug

      character_prompt = build_character_prompt(name, character_info['description'])
      generate_character_data(name, character_info, slug, character_prompt)
    end

    def generate_unique_slug(name, store)
      slug = ValidationUtils.slugify(name)
      if ValidationUtils.blank?(slug)
        puts "⚠️  Warning: Could not generate valid slug for character '#{name}', skipping"
        return nil
      end

      original_slug = slug
      counter = 1
      while store['characters'].key?(slug)
        slug = "#{original_slug}-#{counter}"
        counter += 1
        if counter > 100 # Prevent infinite loops
          puts "⚠️  Warning: Could not generate unique slug for character '#{name}', skipping"
          return nil
        end
      end

      puts "ℹ️  Info: Character '#{name}' slug changed from '#{original_slug}' to '#{slug}' to avoid conflict" if slug != original_slug
      slug
    end

    def build_character_prompt(name, description)
      template = load_character_template
      return "Create character profile for #{name}: #{description}" unless template

      chars = load_characters_abs
      placeholders = build_character_creation_placeholders(name, description || 'Brief mention only', chars)
      template = prefill_single_brace_placeholders(template, placeholders)
      PromptUtils.build_prompt(template, placeholders, warn_unused: false, context: "character '#{name}' creation")
    end

    def load_character_template
      @prompt_provider.load('new_character_creation_prompt.txt')
    rescue StandardError
      nil
    end

    def generate_character_data(name, character_info, slug, character_prompt)
      full = @llm_service.generate_character(character_prompt)
      build_full_character_data(name, character_info, slug, full)
    rescue StandardError => e
      puts "⚠️  Warning: Failed to generate character details for '#{name}': #{e.message}"
      puts '   Using fallback character data instead.'
      build_fallback_character_data(name, character_info, slug)
    end

    def build_full_character_data(name, character_info, slug, full)
      {
        'name' => name,
        'description' => full['description'] || character_info['description'] || '',
        'personality_traits' => full['personality_traits'] || [],
        'programming_skills' => full['programming_skills'] || 'General programming',
        'catchphrase' => full['catchphrase'],
        'backstory' => full['backstory'],
        'quirks' => full['quirks'],
        'physical_appearance' => full['physical_appearance'] || {},
        'first_appearance' => "Chapter #{@current_chapter_number}",
        'slug' => slug,
        'created_date' => Date.today.to_s,
        'language' => 'en'
      }.compact
    end

    def build_fallback_character_data(name, character_info, slug)
      {
        'name' => name,
        'description' => character_info['description'] || 'New character',
        'physical_appearance' => { 'description' => 'Not specified' },
        'first_appearance' => "Chapter #{@current_chapter_number}",
        'slug' => slug,
        'created_date' => Date.today.to_s,
        'language' => 'en'
      }
    end

    def write_character_page(character_data)
      return unless @output_adapter.respond_to?(:write_character_page)

      @output_adapter.write_character_page(character_data['slug'], character_data)
    end

    def save_characters_data(characters_yaml, store)
      chars_data_path = File.join(@project_root, 'data', 'characters.yml')
      FileUtils.mkdir_p(File.dirname(chars_data_path))

      data_to_save = characters_yaml['en'] ? characters_yaml : store
      File.write(chars_data_path, data_to_save.to_yaml)
    end

    public

    def extract_and_store_story_facts(story_facts, chapter_number)
      return if story_facts.nil? || story_facts.empty?

      %w[locations events world_rules relationships].each do |fact_type|
        next unless story_facts[fact_type].is_a?(Array) && !story_facts[fact_type].empty?

        existing = story_bible.get_facts_by_category(fact_type)

        story_facts[fact_type].each do |fact|
          next if fact.nil? || !fact.is_a?(Hash)

          fact_key = generate_fact_key(fact, fact_type)
          next if ValidationUtils.blank?(fact_key)
          next if existing.key?(fact_key)

          normalized_fact = normalize_fact(fact, fact_type, chapter_number)
          story_bible.add_fact(fact_type, fact_key, normalized_fact) if normalized_fact
        end
      end
    end

    def generate_fact_key(fact, fact_type)
      case fact_type
      when 'locations', 'events'
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
        normalize_location_fact(fact, chapter_number)
      when 'events'
        normalize_event_fact(fact, chapter_number)
      when 'world_rules'
        normalize_world_rule_fact(fact, chapter_number)
      when 'relationships'
        normalize_relationship_fact(fact, chapter_number)
      end
    end

    def normalize_location_fact(fact, chapter_number)
      {
        'name' => fact['name']&.to_s&.strip,
        'description' => fact['description']&.to_s&.strip,
        'type' => fact['type']&.to_s&.strip || 'other',
        'first_mentioned' => "Chapter #{chapter_number}",
        'status' => 'established'
      }.compact.reject { |_, v| ValidationUtils.blank?(v) }
    end

    def normalize_event_fact(fact, chapter_number)
      {
        'name' => fact['name']&.to_s&.strip,
        'description' => fact['description']&.to_s&.strip,
        'chapter' => chapter_number,
        'impact' => fact['impact']&.to_s&.strip || 'minor'
      }.compact.reject { |_, v| ValidationUtils.blank?(v) }
    end

    def normalize_world_rule_fact(fact, chapter_number)
      {
        'rule' => fact['rule']&.to_s&.strip,
        'category' => fact['category']&.to_s&.strip || 'other',
        'established' => "Chapter #{chapter_number}"
      }.compact.reject { |_, v| ValidationUtils.blank?(v) }
    end

    def normalize_relationship_fact(fact, chapter_number)
      {
        'character1' => fact['character1']&.to_s&.strip,
        'character2' => fact['character2']&.to_s&.strip,
        'relationship' => fact['relationship']&.to_s&.strip || 'other',
        'status' => fact['status']&.to_s&.strip || 'established',
        'first_chapter' => chapter_number
      }.compact.reject { |_, v| ValidationUtils.blank?(v) }
    end

    def build_story_facts_context
      facts = story_bible.facts
      return {} if facts.nil? || facts.empty?

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

    def story_bible
      @story_bible ||= Eidos::StoryBible.new(project_root: @project_root)
    end

    def build_content_rules_context(content_rules)
      return {} if content_rules.empty?

      placeholders = {}

      build_rules_placeholders(placeholders, content_rules)
      build_character_dynamics_placeholders(placeholders, content_rules)
      build_style_placeholders(placeholders, content_rules)

      placeholders
    end

    private

    def build_rules_placeholders(placeholders, content_rules)
      build_array_placeholder(placeholders, content_rules, 'world_physics', 'WORLD_PHYSICS_RULES')
      build_array_placeholder(placeholders, content_rules, 'style_guidelines', 'STYLE_GUIDELINES')
      build_array_placeholder(placeholders, content_rules, 'content_requirements', 'CONTENT_REQUIREMENTS')
    end

    def build_array_placeholder(placeholders, content_rules, key, placeholder_key)
      return unless content_rules[key].is_a?(Array)

      rules_list = content_rules[key].map { |rule| "- #{rule}" }
      placeholders[placeholder_key] = rules_list.join("\n")
    end

    def build_character_dynamics_placeholders(placeholders, content_rules)
      dynamics = content_rules['character_dynamics']
      return unless dynamics

      dynamics_text = []

      add_protagonist_addressing_rules(dynamics_text, dynamics)
      add_mentor_student_rules(dynamics_text, dynamics)
      add_colleague_dismissal_rules(dynamics_text, dynamics)
      add_underestimation_rules(dynamics_text, dynamics)

      placeholders['CHARACTER_DYNAMICS'] = dynamics_text.join("\n") unless dynamics_text.empty?
    end

    def add_protagonist_addressing_rules(dynamics_text, dynamics)
      return unless dynamics['protagonist_addressing']

      case dynamics['protagonist_addressing']
      when 'real_names_in_dialogue'
        dynamics_text << '- Characters use real names when speaking directly to the protagonist'
      when 'professional_titles'
        dynamics_text << '- Characters use professional titles when addressing the protagonist'
      end
    end

    def add_mentor_student_rules(dynamics_text, dynamics)
      return unless dynamics['mentor_student_pattern']

      case dynamics['mentor_student_pattern']
      when 'sensei_usage'
        dynamics_text << "- Student characters address mentor as 'sensei' or by real name"
      end
    end

    def add_colleague_dismissal_rules(dynamics_text, dynamics)
      return unless dynamics['colleague_dismissal_theme']

      dynamics_text << "- Colleagues consistently dismiss protagonist's abilities as luck"
    end

    def add_underestimation_rules(dynamics_text, dynamics)
      return unless dynamics['underestimation_pattern']

      case dynamics['underestimation_pattern']
      when 'consistent_dismissal'
        dynamics_text << '- Others always underestimate protagonist until proven wrong'
      end
    end

    def build_style_placeholders(placeholders, content_rules)
      placeholders['PARODY_SOURCE'] = content_rules['parody_source'] if content_rules['parody_source']
      placeholders['HUMOR_STYLE'] = content_rules['humor_style'] if content_rules['humor_style']
    end

    def build_main_character_placeholders(config, chars)
      placeholders = {}

      # Check for new-style main character configuration
      main_characters = config.main_characters
      if main_characters.is_a?(Array) && !main_characters.empty?
        # New generic approach: iterate through configured main characters
        main_characters.each do |char_config|
          display_name = char_config['display_name']
          placeholder_key = char_config['placeholder_key']

          next unless display_name && placeholder_key

          real_name = find_character_real_name(chars, display_name) || '[to be generated]'
          placeholders[placeholder_key] = real_name
        end
      elsif config.one_review_man_world?
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

    def load_characters_abs
      path = File.join(@project_root, 'data', 'characters.yml')
      data = File.exist?(path) ? (YAML.safe_load_file(path) || {}) : {}
      base = if data['en']
               data['en']
             elsif data['characters']
               data
             else
               { 'characters' => {} }
             end

      merged = (base['characters'] || {}).dup
      story_bible.characters.each do |id, char|
        next if merged.key?(id)

        merged[id] = char.is_a?(Hash) ? char.merge('slug' => char['slug'] || id) : char
      end
      base.merge('characters' => merged)
    end

    def load_generation_log_abs
      path = File.join(@project_root, 'data', 'generation_log.yml')
      File.exist?(path) ? (YAML.safe_load_file(path) || {}) : {}
    end

    def find_character_real_name(chars_data, display_name)
      values = (chars_data['characters'] || {}).values
      values.find { |c| c['name'] == display_name }&.dig('real_name')
    end

    def build_chapter_placeholders(chapter_number, chars, character_context, used_devices, previous_summary)
      placeholders = {
        'CHAPTER_NUMBER' => chapter_number.to_s,
        'TARGET_LENGTH' => @config.chapter_length_target,
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
      if @config.localized_structure?
        en_metadata = @config.en_metadata
        placeholders.merge!({
                              'BOOK_TITLE' => @config.title,
                              'BOOK_GENRE' => @config.genre,
                              'BOOK_SETTING' => determine_book_setting(en_metadata),
                              'BOOK_STYLE' => @config.humor_style,
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
      content_rules_placeholders = build_content_rules_context(@config.content_rules)
      placeholders.merge!(content_rules_placeholders) if content_rules_placeholders

      # Add main character placeholders based on book configuration
      main_character_placeholders = build_main_character_placeholders(@config, chars)
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
      main_character_placeholders = build_main_character_placeholders(@config, chars)
      placeholders.merge!(main_character_placeholders) if main_character_placeholders

      placeholders
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
      return false unless interaction_possible?(missing_placeholders, auto_generate)
      return false unless user_wants_to_provide_info?

      begin
        config, en_metadata = load_metadata_for_interaction
        updated = metadata_updated?(missing_placeholders, config)

        save_interaction_result(config, en_metadata, updated)
      rescue Interrupt
        puts "\nOperation cancelled."
        false
      rescue StandardError => e
        puts "\n❌ Error collecting information: #{e.message}"
        false
      end
    end

    def interaction_possible?(missing_placeholders, auto_generate)
      return false if auto_generate || ENV['CI'] || !$stdin.tty? || missing_placeholders.empty?

      true
    end

    def user_wants_to_provide_info?
      puts ''
      puts '🤔 I notice some information is missing for chapter generation.'
      puts 'Would you like to provide this information now? (y/n)'

      begin
        response = $stdin.gets&.chomp&.downcase
        %w[y yes].include?(response)
      rescue Interrupt
        puts "\nOperation cancelled."
        false
      end
    end

    def load_metadata_for_interaction
      puts ''
      puts "📝 Let's fill in the missing information:"
      puts ''

      # Ensure localized structure exists in config
      @config.set('localized', { 'en' => {} }) unless @config.localized_structure?

      [@config, @config.en_metadata]
    end

    def metadata_updated?(missing_placeholders, config)
      initial_dirty_state = config.dirty?

      collect_genre_info(missing_placeholders, config)
      collect_style_info(missing_placeholders, config)
      collect_setting_info(missing_placeholders, config)
      collect_theme_info(missing_placeholders, config)

      config.dirty? || !initial_dirty_state
    end

    def collect_genre_info(missing_placeholders, config)
      return unless missing_placeholders.include?('BOOK_GENRE') && config.genre.to_s.strip.empty?

      puts '📖 What genre is your world?'
      puts '   Examples: fantasy, sci-fi, mystery, thriller, comedy, romance, adventure, horror'
      print '   Genre: '
      genre = $stdin.gets&.chomp&.strip
      return if genre.empty?

      config.update_localized('en', 'genre' => genre)
    end

    def collect_style_info(missing_placeholders, config)
      style_missing = missing_placeholders.include?('BOOK_STYLE') || missing_placeholders.include?('BOOK_HUMOR_STYLE')
      return unless style_missing && config.humor_style.to_s.strip.empty?

      puts ''
      puts '✍️ What writing style should I use?'
      puts '   Examples: humorous, serious, adventurous, suspenseful, whimsical, dramatic'
      print '   Style: '
      style = $stdin.gets&.chomp&.strip
      return if style.empty?

      config.update_localized('en', 'humor_style' => style)
    end

    def collect_setting_info(missing_placeholders, config)
      setting_missing = missing_placeholders.include?('BOOK_SETTING') || missing_placeholders.include?('PRIMARY_LOCATION')
      return unless setting_missing && config.setting.to_s.strip.empty?

      puts ''
      puts '🌍 What is the main setting/location of your story?'
      puts '   Examples: medieval castle, space station, modern city, magical school, etc.'
      print '   Setting: '
      setting = $stdin.gets&.chomp&.strip
      return if setting.empty?

      config.update_localized('en', 'setting' => setting)
    end

    def collect_theme_info(missing_placeholders, config)
      theme_missing = missing_placeholders.include?('WORLD_DETAILS')
      theme_empty = config.primary_theme.to_s.strip.empty?
      return unless theme_missing && theme_empty

      puts ''
      puts '🎭 What is the primary theme of your story?'
      puts '   Examples: friendship, mystery, adventure, love, betrayal, discovery, etc.'
      print '   Primary theme: '
      theme = $stdin.gets&.chomp&.strip
      return if theme.empty?

      current_themes = config.themes
      current_themes['primary'] = theme
      config.update_localized('en', 'themes' => current_themes)
    end

    def save_interaction_result(config, _en_metadata, updated)
      if updated
        config.save!
        puts ''
        puts '✅ Information saved! Continuing with chapter generation...'
        puts ''
      else
        puts ''
        puts 'ℹ️ No information was provided. Chapter generation cannot continue.'
      end

      updated
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
