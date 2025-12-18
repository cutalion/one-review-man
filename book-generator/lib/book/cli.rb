# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'yaml'
require 'book/cli/version'
require 'book/translator'
require 'book_core/reset'
require 'book_core/chapter_generator'
require 'book_core/env_utils'
require 'book_core/book_config'
require 'book_core/illustration_generator'
require 'book_core/configuration'
require 'book_core/story_bible'
require 'book_core/story_bible_migrator'
require 'book_core/story_bible_exporter'
require 'book_core/writer_agent'

module Book
  module CLI
    # Utilities shared by subcommands
    module Helpers
      private

      # Non-terminating resolver: returns project root or nil
      def resolve_project_root(candidate = nil)
        candidate ||= Dir.pwd
        data_dir = File.join(candidate, 'data')
        # Check for either new config or legacy metadata
        return candidate if File.exist?(File.join(data_dir, 'book_config.yml')) || File.exist?(File.join(data_dir, 'book_metadata.yml'))

        nil
      end

      def resolve_project_root!(explicit_path = nil, max_attempts = 3)
        candidate = explicit_path || Dir.pwd
        data_dir = File.join(candidate, 'data')
        # Check for either new config or legacy metadata
        if File.exist?(File.join(data_dir, 'book_config.yml')) || File.exist?(File.join(data_dir, 'book_metadata.yml'))
          return File.expand_path(candidate)
        end

        return handle_missing_project_root(max_attempts) if explicit_path

        warn 'Not a book directory (missing data/book_config.yml or data/book_metadata.yml).'
        begin
          path = ask('Path to book directory (leave empty to abort):')
        rescue Interrupt
          warn "\nAborted by user."
          exit 1
        end
        if path && !path.strip.empty?
          # Validate the path before expanding
          path_stripped = path.strip
          unless valid_path_input?(path_stripped)
            warn 'Invalid path provided.'
            return resolve_project_root!(nil, max_attempts - 1) if max_attempts > 1
          end

          expanded_path = File.expand_path(path_stripped)
          return resolve_project_root!(expanded_path, max_attempts - 1) if max_attempts > 1
        end

        warn 'Aborted. Please run in a book directory or pass --book-dir.'
        exit 1
      end

      def handle_missing_project_root(max_attempts)
        if max_attempts <= 1
          warn 'Maximum attempts reached. Aborted.'
          exit 1
        end
        resolve_project_root!(nil, max_attempts - 1)
      end

      def valid_path_input?(path)
        # Basic validation: not empty, doesn't contain null bytes, reasonable length
        return false if path.nil? || path.empty? || path.include?("\0")
        return false if path.length > 1000 # Reasonable path length limit

        true
      end

      # Renders a concise status report for a book at the given absolute root.
      def render_status_report(abs_root)
        begin
          config = BookCore::BookConfig.load_from_project(abs_root)
        rescue BookCore::BookConfig::NotFoundError
          say "❌ No book metadata found. Run 'book init' to create a new book.", :red
          return
        end

        say "\n📚 Book Status Report", :cyan
        say '=' * 50, :cyan

        show_basic_info(config)
        show_progress_info(config)
        missing_fields = show_configuration_status(config)
        show_file_structure_status(abs_root)
        show_generation_readiness(missing_fields)
        show_recent_chapters(abs_root)

        say "\n#{'=' * 50}", :cyan
      end

      def load_book_metadata(abs_root)
        metadata_path = File.join(abs_root, 'data', 'book_metadata.yml')
        if File.exist?(metadata_path)
          YAML.safe_load_file(metadata_path) || {}
        else
          {}
        end
      end

      def show_basic_info(config)
        say "📖 Title: #{config.title}", :green
        say "✍️  Author: #{config.author}", :green
      end

      def show_progress_info(config)
        current = config.current_chapter
        target = config.get('book')&.dig('target_chapters') || 'Not set'
        say "📊 Progress: #{current}/#{target} chapters", :yellow
      end

      def show_configuration_status(config)
        say "\n🔧 Configuration Status:", :cyan

        required_fields = {
          'genre' => '📖 Genre',
          'humor_style' => '✍️ Writing Style',
          'setting' => '🌍 Setting',
          'themes' => '🎭 Themes'
        }

        missing_fields, complete_fields = check_required_fields_config(config, required_fields)

        complete_fields.each { |field| say "  ✅ #{field}", :green }
        missing_fields.each { |field| say "  ❌ #{field}: Not set", :red }

        missing_fields
      end

      def check_required_fields(en_metadata, required_fields)
        missing_fields = []
        complete_fields = []

        required_fields.each do |field, display_name|
          if field == 'themes'
            if en_metadata.dig('themes', 'primary').to_s.strip.empty?
              missing_fields << display_name
            else
              complete_fields << "#{display_name}: #{en_metadata.dig('themes', 'primary')}"
            end
          elsif en_metadata[field].to_s.strip.empty?
            missing_fields << display_name
          else
            complete_fields << "#{display_name}: #{en_metadata[field]}"
          end
        end

        [missing_fields, complete_fields]
      end

      def check_required_fields_config(config, required_fields)
        missing_fields = []
        complete_fields = []

        required_fields.each do |field, display_name|
          case field
          when 'themes'
            if config.primary_theme.to_s.strip.empty?
              missing_fields << display_name
            else
              complete_fields << "#{display_name}: #{config.primary_theme}"
            end
          when 'genre'
            if config.genre.to_s.strip.empty?
              missing_fields << display_name
            else
              complete_fields << "#{display_name}: #{config.genre}"
            end
          when 'humor_style'
            if config.humor_style.to_s.strip.empty?
              missing_fields << display_name
            else
              complete_fields << "#{display_name}: #{config.humor_style}"
            end
          when 'setting'
            if config.setting.to_s.strip.empty?
              missing_fields << display_name
            else
              complete_fields << "#{display_name}: #{config.setting}"
            end
          end
        end

        [missing_fields, complete_fields]
      end

      def show_file_structure_status(abs_root)
        say "\n📁 File Structure:", :cyan
        files_to_check = {
          'data/book_config.yml' => 'Book configuration',
          'data/book_state.yml' => 'Book state',
          'data/characters.yml' => 'Characters data',
          'data/generation_log.yml' => 'Generation log',
          'data/world.yml' => 'World data',
          'data/strings.yml' => 'Site strings'
        }

        # Legacy check
        if File.exist?(File.join(abs_root, 'data/book_metadata.yml')) && !File.exist?(File.join(abs_root, 'data/book_config.yml'))
           files_to_check['data/book_metadata.yml'] = 'Legacy Book metadata'
           files_to_check.delete('data/book_config.yml')
           files_to_check.delete('data/book_state.yml')
        end

        files_to_check.each do |file_path, description|
          full_path = File.join(abs_root, file_path)
          if File.exist?(full_path)
            say "  ✅ #{description}", :green
          else
            say "  ❌ #{description}: Missing", :red
          end
        end
      end

      def show_generation_readiness(missing_fields)
        say "\n🚀 Generation Readiness:", :cyan
        if missing_fields.empty?
          say '  ✅ Ready for chapter generation!', :green
          say '  Run: book generate chapter', :blue
        else
          say '  ❌ Missing required information for chapter generation', :red
          say '  Fix by running: book init (in new directory) or update metadata manually', :yellow
        end
      end

      def show_recent_chapters(abs_root)
        chapters_dir = File.join(abs_root, 'content', 'chapters')
        return unless Dir.exist?(chapters_dir)

        chapters = Dir.glob(File.join(chapters_dir, '*.md')).reject { |f| f.end_with?('.ru.md') }.sort
        if chapters.any?
          say "\n📝 Recent Chapters:", :cyan
          chapters.last(3).each do |chapter_file|
            chapter_name = File.basename(chapter_file, '.md')
            say "  📄 #{chapter_name}", :blue
          end
        else
          say "\n📝 No chapters generated yet", :yellow
        end
      end

      public

      def write_yaml_file(path, hash)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, hash.to_yaml)
      end

      def infer_genre_from_description(description)
        return 'fiction' if description.nil? || description.empty?

        desc_lower = description.downcase

        # Look for genre keywords in description
        return 'fantasy' if desc_lower.match?(/magic|wizard|dragon|fantasy|realm|quest|enchant/i)
        return 'sci-fi' if desc_lower.match?(/space|universe|robot|future|alien|technology|cyber/i)
        return 'mystery' if desc_lower.match?(/mystery|detective|crime|investigation|murder|secret/i)
        return 'thriller' if desc_lower.match?(/thriller|suspense|danger|chase|escape|survival/i)
        return 'comedy' if desc_lower.match?(/comedy|humor|funny|hilarious|laugh|joke/i)
        return 'romance' if desc_lower.match?(/love|romance|relationship|heart|passion/i)
        return 'horror' if desc_lower.match?(/horror|scary|terror|fear|nightmare|ghost/i)
        return 'adventure' if desc_lower.match?(/adventure|journey|explore|discover|travel/i)

        # Default based on common patterns
        'fiction'
      end

      def infer_style_from_description(description)
        return 'narrative' if description.nil? || description.empty?

        desc_lower = description.downcase

        return 'humorous' if desc_lower.match?(/funny|comedy|hilarious|humor|laugh|joke|witty/i)
        return 'suspenseful' if desc_lower.match?(/thriller|suspense|mystery|danger|intense/i)
        return 'adventurous' if desc_lower.match?(/adventure|journey|explore|discover|epic|quest/i)
        return 'whimsical' if desc_lower.match?(/magic|fantasy|whimsical|wonder|enchant/i)
        return 'dramatic' if desc_lower.match?(/drama|emotional|intense|powerful|deep/i)
        return 'serious' if desc_lower.match?(/serious|important|critical|professional/i)

        # Default
        'narrative'
      end

      def infer_setting_from_description(description)
        return 'contemporary setting' if description.nil? || description.empty?

        desc_lower = description.downcase

        return 'magical realm' if desc_lower.match?(/magic|fantasy|realm|kingdom|wizard/i)
        return 'space station' if desc_lower.match?(/space|universe|station|galaxy|cosmos/i)
        return 'futuristic city' if desc_lower.match?(/future|cyber|robot|technology|digital/i)
        return 'modern detective office' if desc_lower.match?(/detective|investigation|crime|police/i)
        return 'parallel universe' if desc_lower.match?(/parallel|universe|dimension|alternate/i)
        return 'medieval world' if desc_lower.match?(/medieval|ancient|historical|past/i)
        return 'mysterious location' if desc_lower.match?(/mystery|secret|hidden|unknown/i)

        # Default
        'contemporary setting'
      end

      def infer_theme_from_description(description)
        return 'adventure' if description.nil? || description.empty?

        desc_lower = description.downcase

        return 'exploration' if desc_lower.match?(/explore|discover|journey|adventure|travel/i)
        return 'mystery' if desc_lower.match?(/mystery|secret|investigation|unknown|hidden/i)
        return 'magic' if desc_lower.match?(/magic|wizard|spell|enchant|fantasy/i)
        return 'technology' if desc_lower.match?(/technology|digital|cyber|robot|future/i)
        return 'discovery' if desc_lower.match?(/discover|find|reveal|uncover|learn/i)
        return 'friendship' if desc_lower.match?(/friend|together|team|companion|bond/i)
        return 'survival' if desc_lower.match?(/survive|danger|escape|threat|peril/i)

        # Default
        'adventure'
      end
    end

    # CLI commands for generating book content
    class Generate < Thor
      include Helpers

      class_option 'content-model', type: :string, desc: 'Specify the model to use for generation (defaults to settings.yml)'
      class_option :auto, type: :boolean, default: false, desc: 'Auto mode: skip interactive prompts'
      class_option :debug, type: :boolean, default: false, desc: 'Enable verbose LLM debug logging'
      class_option 'book-dir', aliases: ['-b'], type: :string, desc: 'Path to the book directory (defaults to current directory)'

      desc 'chapter [NUMBER]', 'Generate a chapter'
      def chapter(_number = nil)
        abs_root = resolve_project_root!(options['book-dir'])
        
        # Load configuration with CLI overrides
        config = BookCore::Configuration.load(abs_root, options)

        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]
          # Pass config to generator
          generator = BookCore::ChapterGenerator.new(configuration: config, project_root: abs_root)
          generator.generate_next_chapter(auto_generate: options[:auto])
        end
      end

      desc 'prompt [NUMBER]', 'Show generation prompt'
      def prompt(number = nil)
        project_root = resolve_project_root(options['book-dir'])
        unless project_root
          puts 'prompt stub for chapter'
          return
        end

        abs_root = File.expand_path(project_root)
        
        # Load configuration with CLI overrides
        config = BookCore::Configuration.load(abs_root, options)

        Dir.chdir(abs_root) do
          generator = BookCore::ChapterGenerator.new(configuration: config, project_root: abs_root)
          chapter_number = number ? number.to_i : generator.send(:determine_next_chapter_number)
          prompt = generator.send(:build_chapter_prompt, chapter_number)
          puts prompt
        end

      end

      desc 'illustration', 'Generate an illustration for a chapter using line numbers'
      method_option :chapter, type: :numeric, required: true, desc: 'Chapter number'
      method_option :content, type: :string, required: true, desc: 'Line range for content (e.g., "10:17")'
      method_option :anchor, type: :numeric, desc: 'Line number to anchor illustration (defaults to first line of content)'
      method_option :prompt, type: :string, desc: 'Additional prompt text to augment the extracted content'
      method_option 'alt-text', type: :string, desc: 'Alt text for the image (defaults to LLM summary of prompt)'
      method_option :style, type: :string, desc: 'Style of the illustration (defaults to settings.yml)'
      method_option :orientation, type: :string, desc: 'Orientation: landscape, portrait, square (defaults to settings.yml)'
      method_option :provider, type: :string, desc: 'Image provider: openai, openrouter (defaults to settings.yml)'
      method_option 'content-model', type: :string, desc: 'Model name (defaults to settings.yml)'
      method_option 'summarization-model', type: :string, desc: 'Model to use for alt text summarization'
      method_option :debug, type: :boolean, default: false, desc: 'Enable debug mode for AI calls'
      method_option 'dry-run', type: :boolean, default: false, desc: 'Dry run: print parameters without generating'
      method_option 'book-dir', aliases: ['-b'], type: :string, desc: 'Path to the book directory'
      def illustration
        abs_root = resolve_project_root!(options['book-dir'])
        
        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]
          
          chapter_number = options[:chapter]
          content_range = options[:content]
          
          # Parse content range (e.g., "10:17")
          unless content_range.match?(/^\d+:\d+$/)
            say "Error: --content must be in format 'START:END' (e.g., '10:17')", :red
            exit 1
          end
          
          start_line, end_line = content_range.split(':').map(&:to_i)
          
          # Read chapter file and extract content
          chapter_file = File.join(abs_root, 'content', 'chapters', format('%03d-chapter.md', chapter_number))
          unless File.exist?(chapter_file)
            say "Error: Chapter file not found: #{chapter_file}", :red
            exit 1
          end
          
          chapter_lines = File.readlines(chapter_file)
          
          # Validate line numbers
          if start_line < 1 || end_line > chapter_lines.length || start_line > end_line
            say "Error: Invalid line range #{content_range}. Chapter has #{chapter_lines.length} lines.", :red
            exit 1
          end
          
          # Extract content (lines are 1-indexed)
          content_lines = chapter_lines[(start_line - 1)..(end_line - 1)]
          extracted_content = content_lines.join.strip
          
          # Build prompt from extracted content and optional additional prompt
          prompt = extracted_content
          prompt += "\n\n#{options[:prompt]}" if options[:prompt]
          
          # Determine anchor line
          anchor_line = options[:anchor] || start_line
          if anchor_line < start_line || anchor_line > end_line
            say "Warning: Anchor line #{anchor_line} is outside content range #{content_range}", :yellow
          end
          
          # Extract anchor text (single line)
          anchor_text = anchor_line > 0 && anchor_line <= chapter_lines.length ? chapter_lines[anchor_line - 1].strip : nil
          
          # Load settings to get defaults
          # Illustration specific overrides (handled by IllustrationGenerator but passed via config if we want to unify)
          # For now, IllustrationGenerator handles its own config, but LLMService needs the LLM config
          config = BookCore::Configuration.load(abs_root, options)
          
          # Three-tier override precedence: CLI > ENV > Settings > Defaults (handled in LLMService)
          provider = options[:provider] || ENV['ILLUSTRATION_PROVIDER']
          model = options['content-model'] || ENV['ILLUSTRATION_MODEL']
          style = options[:style]
          orientation = options[:orientation]
          
          # Initialize LLM service with config
          llm_service = BookCore::LLMService.new(config)
          
          # Generate illustration with provider and model options
          generator = BookCore::IllustrationGenerator.new(llm_service, project_root: abs_root)
          generator.generate(
            chapter_number, 
            prompt, 
            style: style, 
            orientation: orientation, 
            anchor_text: anchor_text,
            provider: provider,
            model: model,
            dry_run: options['dry-run'],
            alt_text: options['alt-text']
          )
        end
      end
    end

    # CLI commands for translating book content
    class Translate < Thor
      include Helpers

      class_option 'content-model', type: :string, desc: 'Specify the model to use for translation (defaults to settings.yml)'
      class_option :debug, type: :boolean, default: false, desc: 'Enable verbose LLM debug logging'
      class_option 'book-dir', aliases: ['-b'], type: :string, desc: 'Path to the book directory (defaults to current directory)'

      desc 'chapter NUMBER LANG', 'Translate a chapter to a language'
      def chapter(number, lang)
        abs_root = resolve_project_root!(options['book-dir'])
        
        config = BookCore::Configuration.load(abs_root, options)

        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]
          translator = Book::Translator.new(config: config, project_root: abs_root)
          translator.translate_chapter_with_ai(number.to_i, lang)
        end
      end

      desc 'character SLUG LANG', 'Translate a character to a language'
      def character(slug, lang)
        abs_root = resolve_project_root!(options['book-dir'])
        
        config = BookCore::Configuration.load(abs_root, options)

        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]
          translator = Book::Translator.new(config: config, project_root: abs_root)
          translator.translate_character_with_ai(slug, lang)
        end
      end

      desc 'all LANG', 'Translate all content to a language'
      def all(lang)
        abs_root = resolve_project_root!(options['book-dir'])
        
        config = BookCore::Configuration.load(abs_root, options)

        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]
          translator = Book::Translator.new(config: config, project_root: abs_root)
          translator.translate_all_content?(lang)
        end
      end
    end

    # CLI commands for initializing new book projects
    class Init < Thor
      include Helpers

      class_option 'book-dir', aliases: ['-b'], type: :string, desc: 'Path to the book directory (defaults to current directory)'
      class_option :quick, type: :boolean, default: false, desc: 'Quick setup with minimal prompts (uses intelligent defaults)'

      desc 'here', 'Initialise a new book (use --book-dir to specify location)'
      def here
        target = File.expand_path(options['book-dir'] || Dir.pwd)

        validate_target_directory(target)
        book_info = collect_book_information
        create_book_structure(target, book_info)

        say "Initialised book at: #{target}", :green
        say '✅ Book is ready for chapter generation!', :green
      end

      private

      def validate_target_directory(target)
        # Check if directory exists and is not empty
        if Dir.exist?(target) && !Dir.empty?(target)
          say "Directory #{target} is not empty.", :red
          exit 1
        end

        # Ask for confirmation if using current directory (no --book-dir specified)
        return unless !options['book-dir'] && !yes?("Create book in current directory (#{target})? [y/N]", :yellow)

        say 'Aborted.', :red
        exit 1
      end

      def collect_book_information
        # Basic book information
        title = ask('Book title:', default: 'My New Book')
        author = ask('Author name:', default: 'Anonymous')
        description = ask('Short description:', default: 'A generated book.')
        languages = ask('Languages (comma-separated, e.g. en,ru):', default: 'en')
        default_lang = ask('Default language code:', default: (languages || 'en').split(',').first.strip)

        # Enhanced metadata for chapter generation
        if options[:quick]
          collect_quick_setup_info(description)
        else
          collect_detailed_setup_info
        end.merge(
          title: title,
          author: author,
          description: description,
          languages: languages,
          default_lang: default_lang
        )
      end

      def collect_quick_setup_info(description)
        genre = infer_genre_from_description(description)
        style = infer_style_from_description(description)
        setting = infer_setting_from_description(description)
        primary_theme = infer_theme_from_description(description)

        say "\n🚀 Quick setup enabled - using intelligent defaults:", :cyan
        say "  📖 Genre: #{genre}", :blue
        say "  ✍️ Style: #{style}", :blue
        say "  🌍 Setting: #{setting}", :blue
        say "  🎭 Theme: #{primary_theme}", :blue

        {
          genre: genre,
          style: style,
          setting: setting,
          primary_theme: primary_theme,
          secondary_themes: '',
          target_chapters: 10
        }
      end

      def collect_detailed_setup_info
        say "\n📚 Additional information needed for chapter generation:", :cyan

        # Genre with suggestions
        genre_examples = 'fantasy, sci-fi, mystery, thriller, comedy, romance, adventure, horror'
        genre = ask("📖 What genre is your book? (#{genre_examples}):", default: 'fiction')

        # Style with suggestions
        style_examples = 'humorous, serious, adventurous, suspenseful, whimsical, dramatic'
        style = ask("✍️  What writing style? (#{style_examples}):", default: 'narrative')

        # Setting
        setting = ask('🌍 What is the main setting/location of your story?', default: 'contemporary setting')

        # Themes
        primary_theme = ask('🎭 What is the primary theme? (e.g., friendship, mystery, adventure):', default: 'adventure')
        secondary_themes = ask('🎨 Secondary themes (comma-separated, optional):', default: '')

        # Target chapters
        target_chapters = ask('📊 Target number of chapters:', default: '10').to_i

        {
          genre: genre,
          style: style,
          setting: setting,
          primary_theme: primary_theme,
          secondary_themes: secondary_themes,
          target_chapters: target_chapters
        }
      end

      def create_book_structure(target, book_info)
        create_directories(target)
        create_metadata_files(target, book_info)
        create_world_data(target, book_info)
        create_strings_data(target, book_info)
        create_settings_data(target)
      end

      def create_directories(target)
        FileUtils.mkdir_p(target)
        FileUtils.mkdir_p(File.join(target, 'data'))
        FileUtils.mkdir_p(File.join(target, 'content', 'chapters'))
        FileUtils.mkdir_p(File.join(target, 'content', 'characters'))
      end

      def create_metadata_files(target, book_info)
        secondary_themes_array = book_info[:secondary_themes].strip.empty? ? [] : book_info[:secondary_themes].split(',').map(&:strip)

        metadata = build_book_metadata(book_info, secondary_themes_array)
        
        # Split metadata into config and state
        config_data, state_data = split_metadata(metadata)
        
        write_yaml_file(File.join(target, 'data', 'book_config.yml'), config_data)
        write_yaml_file(File.join(target, 'data', 'book_state.yml'), state_data)

        # Initialize characters with locale namespace and an empty map
        write_yaml_file(
          File.join(target, 'data', 'characters.yml'),
          {
            'en' => {
              'characters' => {}
            }
          }
        )
        write_yaml_file(File.join(target, 'data', 'generation_log.yml'), { 'chapters' => [] })
      end

      def build_book_metadata(book_info, secondary_themes_array)
        {
          'book' => {
            'target_chapters' => book_info[:target_chapters],
            'current_chapter' => 0
          },
          'generation' => {
            'chapter_length_target' => '1500-3000 words',
            'complexity_level' => 'medium',
            'character_consistency' => true
          },
          'status' => {
            'last_generated' => '',
            'generation_count' => 0,
            'characters_created' => 0,
            'active_storylines' => [],
            'chapters_written' => 0
          },
          'localized' => {
            'en' => {
              'title' => book_info[:title],
              'subtitle' => book_info[:description],
              'author' => book_info[:author],
              'genre' => book_info[:genre],
              'humor_style' => book_info[:style],
              'setting' => book_info[:setting],
              'themes' => {
                'primary' => book_info[:primary_theme],
                'secondary' => secondary_themes_array
              }
            }
          },
          # Legacy fields for backward compatibility
          'title' => book_info[:title],
          'author' => book_info[:author],
          'description' => book_info[:description],
          'languages' => (book_info[:languages] || 'en').split(',').map(&:strip),
          'default_language' => book_info[:default_lang]
        }
      end

      def create_world_data(target, book_info)
        world_data = build_world_data(book_info)
        add_russian_world_data(world_data, book_info) if includes_russian?(book_info[:languages])
        write_yaml_file(File.join(target, 'data', 'world.yml'), world_data)
      end

      def build_world_data(book_info)
        {
          'en' => {
            'world' => {
              'main_setting' => {
                'name' => book_info[:setting],
                'description' => "The primary location where the story of #{book_info[:title]} unfolds",
                'type' => 'primary',
                'established_chapter' => 'Chapter 1'
              },
              'culture' => {
                'narrative_style' => {
                  'description' => "#{book_info[:style]} storytelling with engaging characters",
                  'established_chapter' => 'Chapter 1'
                }
              },
              'established_facts' => [
                "Story takes place in #{book_info[:setting]}",
                "Genre focuses on #{book_info[:genre]} elements",
                "Primary theme is #{book_info[:primary_theme]}",
                "Writing style is #{book_info[:style]}"
              ]
            }
          }
        }
      end

      def add_russian_world_data(world_data, book_info)
        world_data['ru'] = {
          'world' => {
            'main_setting' => {
              'name' => book_info[:setting],
              'description' => "Основное место, где разворачивается история #{book_info[:title]}",
              'type' => 'primary',
              'established_chapter' => 'Глава 1'
            }
          }
        }
      end

      def create_strings_data(target, book_info)
        strings_data = build_strings_data(book_info)
        add_russian_strings_data(strings_data, book_info) if includes_russian?(book_info[:languages])
        write_yaml_file(File.join(target, 'data', 'strings.yml'), strings_data)
      end

      def build_strings_data(book_info)
        {
          'en' => {
            'site_title' => book_info[:title],
            'site_subtitle' => book_info[:description],
            'nav' => {
              'home' => 'Home',
              'chapters' => 'Chapters',
              'characters' => 'Characters',
              'about' => 'About'
            },
            'toc' => {
              'title' => 'Chapters',
              'no_chapters' => 'No chapters yet!'
            }
          }
        }
      end

      def add_russian_strings_data(strings_data, book_info)
        strings_data['ru'] = {
          'site_title' => book_info[:title].to_s,
          'site_subtitle' => book_info[:description],
          'nav' => {
            'home' => 'Главная',
            'chapters' => 'Главы',
            'characters' => 'Персонажи',
            'about' => 'О проекте'
          },
          'toc' => {
            'title' => 'Главы',
            'no_chapters' => 'Глав пока нет!'
          }
        }
      end

      def create_settings_data(target)
        settings_data = {
          'llm' => {
            'provider' => 'openai',
            'temperature' => 0.7,
            'timeout' => 240,
            'default_options' => {
              'max_tokens' => 12_000
            },
            'task_options' => {
              'generation' => {
                'max_tokens' => 8000,
                'timeout' => 300
              },
              'translation' => {
                'max_tokens' => 12_000,
                'timeout' => 300
              }
            },
            'retry' => {
              'max_attempts' => 3,
              'backoff_multiplier' => 2
            },
            'strict_model' => true,
            'models' => {}
          },
          'content' => {
            'model' => 'gpt-4o-mini'
          },
          'summarization' => {
            'model' => 'gpt-5-nano',
            'max_tokens' => 2000
          },
          'illustration' => {
            'provider' => 'openai',
            'model' => 'dall-e-3',
            'style' => 'vivid',
            'orientation' => 'square'
          }
        }
        write_yaml_file(File.join(target, 'data', 'settings.yml'), settings_data)
      end

      def includes_russian?(languages)
        (languages || 'en').split(',').map(&:strip).include?('ru')
      end

      def split_metadata(data)
        state_keys = %w[book status]
        state_data = data.slice(*state_keys)
        config_data = data.except(*state_keys)
        [config_data, state_data]
      end
    end

    # CLI commands for Jekyll site generation
    class Jekyll < Thor
      include Helpers

      desc 'generate [DEST]', 'Create or update a Jekyll site from the current book content'
      method_option :dest, aliases: '-d', type: :string, desc: 'Destination directory for the Jekyll site (defaults to ./site)'
      class_option 'book-dir', aliases: ['-b'], type: :string, desc: 'Path to the book directory (defaults to current directory)'
      def generate(dest = nil)
        book_root = resolve_project_root!(options['book-dir'])
        dest_dir = File.expand_path(dest || options[:dest] || File.join(book_root, 'site'))

        # Prefer local template bundled with this repo layout
        template_root = BookCore::EnvUtils.jekyll_template_path(File.expand_path('../../templates/jekyll', __dir__))
        unless Dir.exist?(template_root)
          say 'Jekyll site template not found. Set JEKYLL_TEMPLATE_PATH or ensure templates exist at book-generator/templates/jekyll.', :red
          exit 1
        end

        # Detect if this is an existing site with custom config BEFORE creating directory
        existing_site = existing_site?(dest_dir)

        FileUtils.mkdir_p(dest_dir)
        if existing_site
          say 'Detected existing Jekyll site - preserving custom configuration', :blue
        else
          say 'Creating new Jekyll site from templates', :green
        end

        # Export Story Bible to Jekyll-compatible format before copying
        if Dir.exist?(File.join(book_root, 'data', 'story_bible'))
          say 'Exporting Story Bible to Jekyll format...', :blue
          exporter = BookCore::StoryBibleExporter.new(project_root: book_root)
          exporter.export_for_jekyll!
        end

        # Copy template (skip content dirs which we handle separately)
        Dir.children(template_root).each do |entry|
          next if %w[_chapters _characters _data].include?(entry)

          src = File.join(template_root, entry)
          dst = File.join(dest_dir, entry)
          if File.directory?(src)
            FileUtils.mkdir_p(dst)
            Dir.glob(File.join(src, '**', '*'), File::FNM_DOTMATCH).each do |path|
              next if ['.', '..'].include?(File.basename(path))

              rel = path.delete_prefix("#{src}/")
              target = File.join(dst, rel)
              if File.directory?(path)
                FileUtils.mkdir_p(target)
              else
                copy_template_with_processing(path, target, book_root, existing_site: existing_site) unless File.exist?(target)
              end
            end
          else
            copy_template_with_processing(src, dst, book_root, existing_site: existing_site) unless File.exist?(dst)
          end
        end

        # Copy book content into site (no symlinks)
        [
          {
            dst_name: '_chapters',
            candidates: [File.join(book_root, '_chapters'), File.join(book_root, 'content', 'chapters')]
          },
          {
            dst_name: '_characters',
            candidates: [File.join(book_root, '_characters'), File.join(book_root, 'content', 'characters')]
          },
          {
            dst_name: '_data',
            candidates: [File.join(book_root, 'data')]
          },
          {
            dst_name: 'assets',
            candidates: [File.join(book_root, 'assets')]
          }
        ].each do |mapping|
          src = mapping[:candidates].find { |p| Dir.exist?(p) }
          dst = File.join(dest_dir, mapping[:dst_name])
          begin
            # Special handling for assets: merge instead of replace
            if mapping[:dst_name] == 'assets'
              FileUtils.mkdir_p(dst)
              if src
                FileUtils.cp_r(Dir.glob("#{src}/*"), dst)
              end
            else
              FileUtils.rm_rf(dst)
              if src
                FileUtils.mkdir_p(File.dirname(dst))
                FileUtils.cp_r(src, dst)
              else
                FileUtils.mkdir_p(dst)
              end
            end
          rescue StandardError => e
            say "Failed to copy #{mapping[:dst_name]}: #{e.message}", :yellow
          end
        end

        say "Jekyll site prepared at: #{dest_dir}", :green
        say 'Run `jekyll build` inside that directory to build the site.'
      end

      private

      def existing_site?(dest_dir)
        # Check for key indicators of an existing custom Jekyll site
        config_file = File.join(dest_dir, '_config.yml')
        return false unless File.exist?(config_file)

        # Check if _config.yml contains hardcoded values (not template placeholders like {{BOOK_TITLE}})
        config_content = File.read(config_file)
        has_title = config_content.include?('title:')
        # Check for our specific template placeholders, not Jekyll's {{ site.* }} syntax
        has_template_placeholders = config_content.match(/\{\{[A-Z_]+\}\}/)

        has_title && !has_template_placeholders
      end

      def copy_template_with_processing(src_path, dst_path, book_root, existing_site: false)
        # For existing sites, skip template processing to preserve custom config
        if !existing_site && needs_template_processing?(src_path)
          process_and_copy_template(src_path, dst_path, book_root)
        else
          # Just copy the file without processing placeholders
          FileUtils.cp(src_path, dst_path)
        end
      end

      def needs_template_processing?(file_path)
        # Process markdown files, YAML config files, and other text files that might contain placeholders
        ext = File.extname(file_path).downcase
        filename = File.basename(file_path)
        ['.md', '.yml', '.yaml', '.html', '.txt'].include?(ext) || filename == 'CNAME'
      end

      def process_and_copy_template(src_path, dst_path, book_root)
        # Read template content
        template_content = File.read(src_path)

        # Build placeholders from book metadata
        placeholders = build_jekyll_placeholders(book_root)

        # Special handling for CNAME file - skip if SITE_DOMAIN is empty
        if File.basename(src_path) == 'CNAME'
          site_domain = placeholders['SITE_DOMAIN'].to_s.strip
          if site_domain.empty?
            say '⚠️  Skipping CNAME file - no site domain configured', :yellow
            return
          end
        end

        # Process template through PromptUtils
        processed_content = PromptUtils.build_prompt(template_content, placeholders, warn_unused: false)

        # Write processed content
        FileUtils.mkdir_p(File.dirname(dst_path))
        File.write(dst_path, processed_content)
      rescue StandardError => e
        # Fallback to direct copy if processing fails
        say "⚠️  Warning: Failed to process template #{File.basename(src_path)}: #{e.message}", :yellow
        FileUtils.cp(src_path, dst_path)
      end

      def build_jekyll_placeholders(book_root)
        placeholders = {}
        book_metadata = load_jekyll_metadata(book_root)

        return placeholders unless book_metadata && book_metadata['localized']

        add_english_placeholders(placeholders, book_metadata)
        add_russian_placeholders(placeholders, book_metadata)
        add_genre_description_placeholders(placeholders, book_metadata)
        add_site_configuration_placeholders(placeholders, book_metadata)

        placeholders
      rescue StandardError => e
        say "⚠️  Warning: Failed to load book metadata for Jekyll placeholders: #{e.message}", :yellow
        {}
      end

      def load_jekyll_metadata(book_root)
        metadata_path = File.join(book_root, 'data', 'book_metadata.yml')
        return nil unless File.exist?(metadata_path)

        YAML.safe_load_file(metadata_path)
      end

      def add_english_placeholders(placeholders, book_metadata)
        en_data = book_metadata.dig('localized', 'en')
        return unless en_data

        placeholders.merge!({
                              'BOOK_TITLE' => en_data['title'] || 'Untitled Book',
                              'BOOK_AUTHOR' => en_data['author'] || 'Unknown Author',
                              'BOOK_GENRE' => en_data['genre'] || 'Fiction',
                              'BOOK_SUBTITLE' => en_data['subtitle'] || '',
                              'AUTHOR_EMAIL' => en_data['author_email'] || 'author@example.com',
                              'BOOK_DESCRIPTION' => en_data['description'] || book_metadata['description'] || 'An AI-generated book'
                            })
      end

      def add_russian_placeholders(placeholders, book_metadata)
        ru_data = book_metadata.dig('localized', 'ru') || {}

        placeholders.merge!({
                              'BOOK_TITLE_RU' => ru_data['title'] || placeholders['BOOK_TITLE'] || 'Untitled Book',
                              'BOOK_AUTHOR_RU' => ru_data['author'] || placeholders['BOOK_AUTHOR'] || 'Unknown Author',
                              'BOOK_GENRE_RU' => ru_data['genre'] || placeholders['BOOK_GENRE'] || 'Fiction',
                              'BOOK_SUBTITLE_RU' => ru_data['subtitle'] || '',
                              'BOOK_GENRE_DESCRIPTION_RU' => build_russian_genre_description(ru_data, placeholders)
                            })
      end

      def build_russian_genre_description(ru_data, placeholders)
        return ru_data['genre_description'] if ru_data['genre_description']
        return "#{ru_data['genre']} истории" if ru_data['genre']
        return "#{placeholders['BOOK_GENRE']} истории" if placeholders['BOOK_GENRE']

        'истории'
      end

      def add_genre_description_placeholders(placeholders, book_metadata)
        en_data = book_metadata.dig('localized', 'en')
        return unless en_data

        genre_desc = en_data['genre_description']
        genre_desc ||= en_data['genre'] ? "#{en_data['genre']} story" : 'story'
        placeholders['BOOK_GENRE_DESCRIPTION'] = genre_desc
      end

      def add_site_configuration_placeholders(placeholders, book_metadata)
        placeholders.merge!({
                              'SITE_URL' => book_metadata['site_url'] || 'http://example.com',
                              'TWITTER_USERNAME' => book_metadata['twitter_username'] || '',
                              'GITHUB_USERNAME' => book_metadata['github_username'] || '',
                              'SITE_DOMAIN' => book_metadata['site_domain'] || ''
                            })
      end
    end

    # CLI commands for resetting book project content
    class Reset < Thor
      class_option :force, type: :boolean, default: false, desc: 'Force operations without confirmation'

      desc 'all', 'Reset all generated content and data'
      def all
        resetter.reset_all(force: options[:force])
      end

      desc 'chapters', 'Reset generated chapters'
      def chapters
        resetter.reset_chapters(force: options[:force])
      end

      desc 'characters', 'Reset generated characters'
      def characters
        resetter.reset_characters(force: options[:force])
      end

      desc 'data', 'Reset data files'
      def data
        resetter.reset_data_files
      end

      desc 'site', 'Reset generated site files'
      def site
        resetter.reset_generated_site
      end

      desc 'status', 'Show reset status'
      def status
        resetter.status
      end

      private

      def resetter
        @resetter ||= Book::Reset.new
      end
    end

    # CLI commands for Story Bible management
    class Bible < Thor
      include Helpers

      class_option 'book-dir', aliases: ['-b'], type: :string, desc: 'Path to the book directory'

      desc 'migrate', 'Migrate existing data to Story Bible format'
      def migrate
        abs_root = resolve_project_root!(options['book-dir'])
        Dir.chdir(abs_root) do
          migrator = BookCore::StoryBibleMigrator.new(project_root: abs_root)
          migrator.migrate!
        end
      end

      desc 'export', 'Export Story Bible to Jekyll-compatible format (updates data/*.yml files)'
      def export
        abs_root = resolve_project_root!(options['book-dir'])
        Dir.chdir(abs_root) do
          exporter = BookCore::StoryBibleExporter.new(project_root: abs_root)
          exporter.export_for_jekyll!
        end
      end

      desc 'list TYPE', 'List entities (characters, locations, facts, relationships, plot_threads)'
      def list(type)
        abs_root = resolve_project_root!(options['book-dir'])
        bible = BookCore::StoryBible.new(project_root: abs_root)

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
        abs_root = resolve_project_root!(options['book-dir'])
        bible = BookCore::StoryBible.new(project_root: abs_root)

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
            fact_id = parts[2..-1].join('/')
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
        abs_root = resolve_project_root!(options['book-dir'])
        bible = BookCore::StoryBible.new(project_root: abs_root)

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
        abs_root = resolve_project_root!(options['book-dir'])
        bible = BookCore::StoryBible.new(project_root: abs_root)

        ctx = bible.chapter_context(chapter.to_i)
        say "Chapter #{chapter} Context:", :cyan
        say ctx.to_yaml
      end
    end

    # CLI commands for agent-based content generation (experimental)
    class Agent < Thor
      include Helpers

      class_option 'book-dir', aliases: ['-b'], type: :string, desc: 'Path to the book directory'

      desc 'write [CHAPTER]', 'Generate a chapter using the Agent-Writer (experimental)'
      option :requirements, type: :string, aliases: '-r', desc: 'Additional requirements for the chapter'
      option :dry_run, type: :boolean, default: false, desc: 'Show what would be generated without writing'
      option :debug, type: :boolean, default: false, desc: 'Enable debug output'
      option :force, type: :boolean, default: false, desc: 'Force overwrite if chapter exists'
      def write(chapter = nil)
        abs_root = resolve_project_root!(options['book-dir'])

        # Determine chapter number using max(files, state) + 1 (same as ChapterGenerator)
        chapter_number = if chapter
                           chapter.to_i
                         else
                           determine_next_chapter_number(abs_root)
                         end

        # Check if chapter file already exists (unless --force)
        chapters_dir = File.join(abs_root, 'content', 'chapters')
        chapter_file = File.join(chapters_dir, format('%03d-chapter.md', chapter_number))
        
        if File.exist?(chapter_file) && !options[:force]
          say "⚠️  Chapter #{chapter_number} already exists at #{chapter_file}", :yellow
          say "   Use --force to overwrite, or specify a different chapter number.", :yellow
          say "   Next available: #{determine_next_chapter_number(abs_root)}", :cyan
          return
        end

        say "🤖 Agent-Writer: Generating Chapter #{chapter_number}...", :cyan
        say "   Model: #{BookCore::WriterAgent::DEFAULT_MODEL}", :blue

        # Initialize services
        config = BookCore::Configuration.load(abs_root, {})
        llm_service = BookCore::LLMService.new(config)
        story_bible = BookCore::StoryBible.new(project_root: abs_root)

        # Create agent
        agent = BookCore::WriterAgent.new(
          llm_service: llm_service,
          story_bible: story_bible,
          project_root: abs_root,
          debug: options[:debug]
        )

        if options[:dry_run]
          say "\n[Dry Run] Would generate chapter using these tools:", :yellow
          BookCore::AgentTools::StoryBibleTools.definitions.each do |tool|
            say "  • #{tool[:function][:name]}: #{tool[:function][:description].slice(0, 60)}...", :white
          end
          return
        end

        # Generate chapter
        begin
          result = agent.generate_chapter(chapter_number, requirements: options[:requirements])

          # Show tool calls log
          if options[:debug] && agent.tool_calls_log.any?
            say "\n📋 Tool calls made:", :blue
            agent.tool_calls_log.each do |call|
              say "   • #{call[:name]}(#{call[:arguments].inspect})", :white
            end
          end

          say "\n✅ Chapter generated successfully!", :green
          say "   Title: #{result['title']}", :cyan
          say "   Summary: #{result['summary'].slice(0, 100)}...", :white if result['summary']
          say "   Word count: #{result['content'].to_s.split.length}", :white
          say "   Characters: #{result['characters_featured'].join(', ')}", :white if result['characters_featured']&.any?

          # Save the chapter (using existing chapter generator infrastructure)
          save_agent_chapter(abs_root, chapter_number, result)

        rescue BookCore::LLMService::LLMError => e
          say "\n❌ Agent error: #{e.message}", :red
          exit 1
        end
      end

      private

      # Determine next chapter number using max(files, state) + 1
      # This is the same logic as ChapterGenerator.determine_next_chapter_number
      def determine_next_chapter_number(project_root)
        chapters_dir = File.join(project_root, 'content', 'chapters')
        max_from_files = 0
        
        if Dir.exist?(chapters_dir)
          Dir.glob(File.join(chapters_dir, '*.md')).each do |path|
            basename = File.basename(path)
            # Match NNN-chapter.md only (no language suffix like .ru.md)
            if basename =~ /^(\d{3})-chapter\.md$/
              num = Regexp.last_match(1).to_i
              max_from_files = [max_from_files, num].max
            end
          end
        end

        book_config = BookCore::BookConfig.load_from_project(project_root)
        current_in_metadata = book_config&.current_chapter || 0

        [max_from_files, current_in_metadata].max + 1
      end

      def save_agent_chapter(project_root, chapter_number, result)
        # Create chapter file
        chapters_dir = File.join(project_root, 'content', 'chapters')
        FileUtils.mkdir_p(chapters_dir)

        filename = File.join(chapters_dir, format('%03d-chapter.md', chapter_number))

        front_matter = {
          'layout' => 'chapter',
          'title' => result['title'],
          'chapter_number' => chapter_number,
          'summary' => result['summary'],
          'characters' => result['characters_featured'] || [],
          'generated_by' => 'agent-writer',
          'generated_at' => Time.now.strftime('%Y-%m-%dT%H:%M:%S%:z'),
          'lang' => 'en'
        }

        content = +"---\n"
        content << front_matter.to_yaml.lines[1..].join
        content << "---\n\n"
        content << result['content'].to_s

        File.write(filename, content)
        say "   Saved to: #{filename}", :green

        # Update book state
        begin
          book_config = BookCore::BookConfig.load_from_project(project_root)
          if book_config
            book_config.update_current_chapter(chapter_number)
            book_config.save!
          end
        rescue StandardError => e
          say "   ⚠️  Could not update book state: #{e.message}", :yellow
        end
      end
    end

    # CLI commands for displaying book project status
    class Status < Thor
      include Helpers

      class_option 'book-dir', aliases: ['-b'], type: :string, desc: 'Path to the book directory (defaults to current directory)'

      desc 'show', 'Show current book configuration and status'
      def show
        book_root = resolve_project_root(options['book-dir'])
        unless book_root
          say "Not in a book directory. Use 'book init' to create a new book.", :red
          return
        end

        abs_root = File.expand_path(book_root)
        render_status_report(abs_root)
      end
    end

    # Main CLI runner that organizes subcommands
    class Runner < Thor
      include Helpers

      desc 'generate SUBCOMMAND ...ARGS', 'Generate content'
      subcommand 'generate', Generate

      desc 'translate SUBCOMMAND ...ARGS', 'Translate content'
      subcommand 'translate', Translate

      desc 'init', 'Initialize a new book project'
      class_option 'book-dir', aliases: ['-b'], type: :string, desc: 'Path to the book directory (defaults to current directory)'
      class_option :quick, type: :boolean, default: false, desc: 'Quick setup with minimal prompts (uses intelligent defaults)'
      def init
        # Delegate to the Init class's here method with the same options
        Init.new.invoke(:here, [], options)
      end

      desc 'jekyll SUBCOMMAND ...ARGS', 'Jekyll site operations'
      subcommand 'jekyll', Jekyll

      desc 'bible SUBCOMMAND ...ARGS', 'Story Bible management'
      subcommand 'bible', Bible

      desc 'agent SUBCOMMAND ...ARGS', 'Agent-based content generation (experimental)'
      subcommand 'agent', Agent

      desc 'reset SUBCOMMAND ...ARGS', 'Reset generated content'
      subcommand 'reset', Reset

      # Replace subcommand with a top-level status command
      desc 'status', 'Show current book configuration and status'
      method_option 'book-dir', aliases: ['-b'], type: :string, desc: 'Path to the book directory (defaults to current directory)'
      def status
        book_root = resolve_project_root(options['book-dir'])
        unless book_root
          say "Not in a book directory. Use 'book init' to create a new book.", :red
          return
        end

        abs_root = File.expand_path(book_root)
        render_status_report(abs_root)
      end

      desc 'migrate', 'Migrate legacy configuration to new format'
      method_option 'book-dir', aliases: ['-b'], type: :string, desc: 'Path to the book directory (defaults to current directory)'
      def migrate
        book_root = resolve_project_root(options['book-dir'])
        unless book_root
          say "Not in a book directory.", :red
          return
        end

        abs_root = File.expand_path(book_root)
        legacy_path = File.join(abs_root, 'data', 'book_metadata.yml')
        config_path = File.join(abs_root, 'data', 'book_config.yml')
        state_path = File.join(abs_root, 'data', 'book_state.yml')

        if File.exist?(config_path) || File.exist?(state_path)
          say "New configuration files already exist. Migration skipped.", :yellow
          return
        end

        unless File.exist?(legacy_path)
          say "No legacy metadata found at #{legacy_path}.", :red
          return
        end

        say "Migrating #{legacy_path}...", :blue
        
        # Load legacy data
        data = YAML.safe_load_file(legacy_path)
        
        # Split data
        state_keys = %w[book status]
        state_data = data.slice(*state_keys)
        config_data = data.except(*state_keys)

        # Write new files
        write_yaml_file(config_path, config_data)
        write_yaml_file(state_path, state_data)
        
        say "✅ Created data/book_config.yml", :green
        say "✅ Created data/book_state.yml", :green
        
        # Rename legacy file to backup
        backup_path = "#{legacy_path}.bak"
        FileUtils.mv(legacy_path, backup_path)
        say "📦 Archived legacy file to #{backup_path}", :green
      end

      desc 'version', 'Show version'
      def version
        puts Book::CLI::VERSION
      end

      map %w[--version -v] => :version
    end
  end
end
