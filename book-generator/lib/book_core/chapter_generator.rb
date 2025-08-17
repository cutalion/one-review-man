# frozen_string_literal: true

require 'yaml'
require 'date'
require 'fileutils'
require 'set'
require 'book_core/llm_service'
require 'book_core/prompt_provider'
require 'book_core/world_utils'
require 'book_core/prompt_utils'
require 'book_core/env_utils'
require 'book_core/validation_utils'

module BookCore
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

      llm_config_path = File.join(@project_root, 'scripts/llm_config.yml')
      @llm_service = kwargs[:llm_service] || BookCore::LLMService.new(llm_config_path, model_override)

      # Ensure adapter is configured with project root if provided
      if @output_adapter.respond_to?(:setup_project)
         @output_adapter.setup_project(@project_root)
      end
    end

    def generate_next_chapter(auto_generate: false)
      next_chapter = determine_next_chapter_number

      puts "Generating Chapter #{next_chapter} using model #{@model_override || 'default-model'}..."

      # Determine characters for this chapter (parity with main)
      character_objects = select_characters_for_chapter(next_chapter)
      character_slugs = character_objects.map { |c| c['slug'] || slugify(c['name'].to_s) }

      chapter_data = generate_chapter_structured(next_chapter)

      write_chapter_file(next_chapter, chapter_data, character_slugs)
      create_new_characters(chapter_data['new_characters']) if chapter_data['new_characters'].is_a?(Array)

      update_book_progress(next_chapter)

      puts "✅ Chapter #{next_chapter} generated successfully!"

      chapter_data['content']
    end

    private

    def generate_chapter_structured(chapter_number)
      prompt = build_chapter_prompt(chapter_number)
      data = @llm_service.generate_chapter_structured(prompt, {})
      # Replace placeholders if present
      if data.is_a?(Hash)
        %w[title summary content].each do |key|
          data[key] = data[key].to_s.gsub('{CHAPTER_NUMBER}', chapter_number.to_s) if data[key]
        end
      end
      unless EnvUtils.mock_ai_enabled?
        raise BookCore::LLMService::LLMError, 'Generated content too short' if data['content'].to_s.strip.length < 50
      end
      data
    end

    def build_chapter_prompt(chapter_number)
      # Load template matching main branch (explicit filename)
      template = @prompt_provider.load('chapter_prompts.txt') rescue "Write Chapter {CHAPTER_NUMBER} of a programming comedy story"
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

      # Real names
      one_review_man_real = find_character_real_name(chars, 'One Review Man') || '[to be generated]'
      quantum_android_real = find_character_real_name(chars, 'Quantum Android') || '[to be generated]'

      # World context (use world utils; ensure correct CWD)
      world_ctx = Dir.chdir(@project_root) { build_world_context('en') }

      placeholders = {
        'CHAPTER_NUMBER' => chapter_number.to_s,
        'TARGET_LENGTH' => (book_metadata.dig('generation', 'chapter_length_target') || '1500-3000 words'),
        'PREVIOUS_CHAPTERS_SUMMARY' => previous_summary,
        'CHARACTER_CONTEXT' => character_context.empty? ? 'No existing characters.' : "Existing characters:\n#{character_context}",
        'USED_PLOT_DEVICES' => used_devices.join(', '),
        'SPECIAL_INSTRUCTIONS' => get_special_instructions(chapter_number),
        'ONE_REVIEW_MAN_REAL_NAME' => one_review_man_real,
        'QUANTUM_ANDROID_REAL_NAME' => quantum_android_real,
        'CHARACTER_NAME' => '',
        'CHARACTER_DESCRIPTION' => '',
        'CHARACTER_TRAITS' => '',
        'CHARACTER_CODING_LEVEL' => '',
        'CHARACTER_RELATIONSHIP' => ''
      }.merge(world_ctx || {})

      PromptUtils.build_prompt(template, placeholders, warn_unused: false)
    rescue PromptUtils::UnfilledPlaceholdersError => e
      puts "❌ Error: Template has unfilled placeholders: #{e.unfilled_placeholders.join(', ')}"
      raise
    end

    def write_chapter_file(chapter_number, chapter_data, character_slugs = [])
      if @output_adapter
        content = chapter_data['content']
        word_count = content.split(/\s+/).length
        chapter_slug = format('%03d', chapter_number) + '-chapter'
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
        chapter_slug = format('%03d', chapter_number) + '-chapter'
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
      metadata = File.exist?(metadata_path) ? (YAML.safe_load(File.read(metadata_path)) || {}) : {}
      metadata['book'] ||= {}
      metadata['book']['current_chapter'] = chapter_number
      FileUtils.mkdir_p(File.dirname(metadata_path))
      File.write(metadata_path, metadata.to_yaml)

      puts "📈 Updated book progress: Chapter #{chapter_number} completed"

      # Simple summary
      puts "\n📊 Chapter Generation Summary"
      puts "=" * 40
      # Best-effort print: read back the file and count words
      filename = File.join(preferred_chapters_dir, "#{format('%03d', chapter_number)}-chapter.md")
      wc = 0
      if File.exist?(filename)
        text = File.read(filename)
        parts = text.split(/^---\s*$/, 3)
        wc = parts.length >= 3 ? parts[2].split(/\s+/).length : 0
      end
      puts "Title: #{chapter_data_title_for_print(chapter_number)}"
      puts "Word Count: #{wc > 0 ? wc : 'Not specified'}"
      puts "Difficulty: #{'Not specified'}"
      puts "=" * 40
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
        md = YAML.safe_load(File.read(metadata_path)) || {}
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
      characters_yaml = File.exist?(chars_data_path) ? (YAML.safe_load(File.read(chars_data_path)) || {}) : {}
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
          if counter > 100  # Prevent infinite loops
            puts "⚠️  Warning: Could not generate unique slug for character '#{name}', skipping"
            next
          end
        end
        
        if slug != original_slug
          puts "ℹ️  Info: Character '#{name}' slug changed from '#{original_slug}' to '#{slug}' to avoid conflict"
        end

        # Build rich character prompt from template if available
        template = @prompt_provider.load('new_character_creation_prompt.txt') rescue nil
        character_prompt = nil
        if template
          chars = load_characters_abs
          orm = find_character_real_name(chars, 'One Review Man') || '[to be generated]'
          qa  = find_character_real_name(chars, 'Quantum Android') || '[to be generated]'
          placeholders = {
            'CHAPTER_NUMBER' => (determine_next_chapter_number - 1).to_s,
            'CHARACTER_NAME' => name,
            'CHARACTER_DESCRIPTION' => c['description'] || 'Brief mention only',
            'ONE_REVIEW_MAN_REAL_NAME' => orm,
            'QUANTUM_ANDROID_REAL_NAME' => qa
          }
          character_prompt = PromptUtils.build_prompt(template, placeholders)
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
            'first_appearance' => "Chapter #{determine_next_chapter_number - 1}",
            'slug' => slug,
            'created_date' => Date.today.to_s,
            'language' => 'en'
          }.compact
        rescue StandardError => e
          puts "⚠️  Warning: Failed to generate character details for '#{name}': #{e.message}"
          puts "   Using fallback character data instead."
          character_data = {
            'name' => name,
            'description' => c['description'] || 'New character',
            'first_appearance' => "Chapter #{determine_next_chapter_number - 1}",
            'slug' => slug,
            'created_date' => Date.today.to_s,
            'language' => 'en'
          }
        end

        store['characters'][slug] = character_data
        if @output_adapter.respond_to?(:write_character_page)
          @output_adapter.write_character_page(slug, character_data)
        end
      end

      # Persist characters.yml
      FileUtils.mkdir_p(File.dirname(chars_data_path))
      if characters_yaml['en']
        File.write(chars_data_path, characters_yaml.to_yaml)
      else
        File.write(chars_data_path, store.to_yaml)
      end
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
      File.exist?(path) ? (YAML.safe_load(File.read(path)) || {}) : {}
    end

    def load_characters_abs
      path = File.join(@project_root, 'data', 'characters.yml')
      data = File.exist?(path) ? (YAML.safe_load(File.read(path)) || {}) : {}
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
      File.exist?(path) ? (YAML.safe_load(File.read(path)) || {}) : {}
    end

    def find_character_real_name(chars_data, display_name)
      values = (chars_data['characters'] || {}).values
      values.find { |c| c['name'] == display_name }&.dig('real_name')
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
