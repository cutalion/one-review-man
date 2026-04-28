# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'yaml'
require 'eidos/cli/helpers'
require 'eidos/cli/version'
require 'eidos/cli/unknown_command_help'
require 'eidos/world_config'
require 'eidos/reset'

module Eidos
  module CLI
    # CLI commands for world management: init, status, reset, migrate, version
    class World < Thor
      extend Eidos::CLI::UnknownCommandHelp
      include Helpers

      # --- new (init) -----------------------------------------------------------

      desc 'new', 'Initialize a new world project'
      method_option 'world-dir', aliases: ['-b', '-w'], type: :string,
                                 desc: 'Path to the world directory (defaults to current directory)'
      method_option :quick, type: :boolean, default: false,
                            desc: 'Quick setup with minimal prompts (uses intelligent defaults)'
      method_option 'no-seed', type: :boolean, default: false,
                               desc: 'Skip the Story Bible seed prompt (also implied by --quick)'
      method_option :title, type: :string,
                            desc: '(--quick) World title (required when non-interactive)'
      method_option :author, type: :string,
                             desc: '(--quick) Author name (required when non-interactive)'
      method_option :premise, type: :string,
                              desc: '(--quick) Multi-line premise; lands in subtitle/description verbatim'
      method_option :languages, type: :string,
                                desc: '(--quick) Comma-separated ISO codes (default: en)'
      method_option 'default-language', type: :string,
                                        desc: '(--quick) Default ISO code; must be in --languages'
      method_option :genre, type: :string,
                            desc: '(--quick) Explicit genre; default is literal sentinel "unspecified"'
      method_option :style, type: :string,
                            desc: '(--quick) Explicit narrative style; default "unspecified"'
      method_option :setting, type: :string,
                              desc: '(--quick) Explicit setting; default "unspecified"'
      method_option :theme, type: :string,
                            desc: '(--quick) Explicit primary theme; default "unspecified"'
      def new
        target = File.expand_path(options['world-dir'] || Dir.pwd)

        validate_target_directory(target)
        world_info = collect_world_information
        create_world_structure(target, world_info)
        maybe_seed_story_bible(target, world_info)

        say "Initialised world at: #{target}", :green
        say 'World is ready for chapter generation!', :green
      end

      map 'init' => :new

      # --- status ---------------------------------------------------------------

      desc 'status', 'Show world status'
      method_option 'world-dir', aliases: ['-b', '-w'], type: :string,
                                 desc: 'Path to the world directory (defaults to current directory)'
      def status
        world_root = resolve_project_root(options['world-dir'])
        unless world_root
          say "Not in a world directory. Use 'world new' to create a new world.", :red
          return
        end

        abs_root = File.expand_path(world_root)
        render_status_report(abs_root)
      end

      # --- reset ----------------------------------------------------------------

      desc 'reset SCOPE', 'Reset world content (all/chapters/characters/data/site/status)'
      method_option :force, type: :boolean, default: false, desc: 'Force operations without confirmation'
      def reset(scope)
        case scope
        when 'all'
          resetter.reset_all(force: options[:force])
        when 'chapters'
          resetter.reset_chapters(force: options[:force])
        when 'characters'
          resetter.reset_characters(force: options[:force])
        when 'data'
          resetter.reset_data_files
        when 'site'
          resetter.reset_generated_site
        when 'status'
          resetter.status
        else
          say "Unknown reset scope: #{scope}. Use one of: all, chapters, characters, data, site, status", :red
        end
      end

      # --- migrate --------------------------------------------------------------

      desc 'migrate', 'Migrate legacy configuration format'
      method_option 'world-dir', aliases: ['-b', '-w'], type: :string,
                                 desc: 'Path to the world directory (defaults to current directory)'
      def migrate
        world_root = resolve_project_root(options['world-dir'])
        unless world_root
          say 'Not in a world directory.', :red
          return
        end

        abs_root = File.expand_path(world_root)
        legacy_path = File.join(abs_root, 'data', 'world_metadata.yml')
        config_path = File.join(abs_root, 'data', 'world_config.yml')
        state_path  = File.join(abs_root, 'data', 'world_state.yml')

        if File.exist?(config_path) || File.exist?(state_path)
          say 'New configuration files already exist. Migration skipped.', :yellow
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
        state_keys = %w[world book status]
        state_data  = data.slice(*state_keys)
        config_data = data.except(*state_keys)

        # Write new files
        write_yaml_file(config_path, config_data)
        write_yaml_file(state_path, state_data)

        say 'Created data/world_config.yml', :green
        say 'Created data/world_state.yml', :green

        # Rename legacy file to backup
        backup_path = "#{legacy_path}.bak"
        FileUtils.mv(legacy_path, backup_path)
        say "Archived legacy file to #{backup_path}", :green
      end

      # --- version --------------------------------------------------------------

      desc 'version', 'Show version'
      def version
        puts Eidos::CLI::VERSION
      end

      map %w[--version -v] => :version

      private

      # ---- resetter helper -----------------------------------------------------

      def resetter
        @resetter ||= Eidos::Reset.new
      end

      # ---- new/init helpers ----------------------------------------------------

      def validate_target_directory(target)
        if Dir.exist?(target) && !Dir.empty?(target)
          say "Directory #{target} is not empty.", :red
          exit 1
        end

        return unless !options['world-dir'] && !yes?("Create world in current directory (#{target})? [y/N]", :yellow)

        say 'Aborted.', :red
        exit 1
      end

      def collect_world_information
        return quick_setup_from_flags if non_interactive_quick?

        title       = ask('World title:', default: 'My New World')
        author      = ask('Author name:', default: 'Anonymous')
        description = ask('Short description:', default: 'A generated world.')
        languages   = ask('Languages (comma-separated, e.g. en,ru):', default: 'en')
        default_lang = resolve_default_language(languages)

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

      # True when --quick is in effect AND we have flag values OR stdin is
      # not a TTY. In this mode no prompts are read — all values come from
      # Thor options per `contracts/cli-flags.md`.
      def non_interactive_quick?
        return false unless options[:quick]

        any_quick_flag_present? || !$stdin.tty?
      end

      QUICK_SETUP_FLAGS = %w[title author premise languages default-language].freeze
      private_constant :QUICK_SETUP_FLAGS

      def any_quick_flag_present?
        QUICK_SETUP_FLAGS.any? { |f| options[f] && !options[f].to_s.empty? }
      end

      # Build the world_info hash from Thor options. Exits non-zero on
      # missing required flags (--title, --author, --premise) or an
      # invalid --default-language. Never reads stdin.
      def quick_setup_from_flags
        validate_required_quick_flags!

        languages_csv = options['languages'] || 'en'
        codes = languages_csv.split(',').map(&:strip).reject(&:empty?)
        if codes.empty?
          $stderr.puts 'Error: --languages must contain at least one ISO code.'
          exit 1
        end

        default_lang = options['default-language'] || codes.first
        unless codes.include?(default_lang)
          $stderr.puts "Error: --default-language '#{default_lang}' is not a member of --languages " \
                       "(#{codes.join(', ')})."
          exit 1
        end

        {
          title: options['title'],
          author: options['author'],
          description: options['premise'],
          languages: codes.join(','),
          default_lang: default_lang,
          genre: options['genre'] || 'unspecified',
          style: options['style'] || 'unspecified',
          setting: options['setting'] || 'unspecified',
          primary_theme: options['theme'] || 'unspecified',
          secondary_themes: ''
        }
      end

      def validate_required_quick_flags!
        missing = []
        missing << '--title'   if options['title'].to_s.empty?
        missing << '--author'  if options['author'].to_s.empty?
        missing << '--premise' if options['premise'].to_s.empty?
        return if missing.empty?

        $stderr.puts 'Error: --quick requires all of: --title, --author, --premise'
        $stderr.puts "Missing: #{missing.join(', ')}"
        exit 1
      end

      # Quick-setup under an interactive TTY (when --quick is set but no
      # metadata flags were given). Per feature 015 US4: no regex heuristics,
      # no hardcoded "fiction"/"adventure"/etc. fallbacks. Either the user
      # types a value or we write the literal sentinel "unspecified" which
      # `world status` surfaces as an action item.
      def collect_quick_setup_info(_description)
        say "\nQuick setup — metadata fields (press Enter to leave as 'unspecified'):", :cyan

        {
          genre: ask_or_unspecified('Genre (e.g. comedy, sci-fi, mystery):'),
          style: ask_or_unspecified('Writing style (e.g. deadpan, whimsical, dramatic):'),
          setting: ask_or_unspecified('Setting (e.g. open-plan office, magical realm):'),
          primary_theme: ask_or_unspecified('Primary theme (e.g. disillusionment, adventure):'),
          secondary_themes: ''
        }
      end

      def collect_detailed_setup_info
        say "\nAdditional information needed for chapter generation:", :cyan

        {
          genre: ask_or_unspecified('Genre (e.g. comedy, sci-fi, mystery):'),
          style: ask_or_unspecified('Writing style (e.g. deadpan, whimsical, dramatic):'),
          setting: ask_or_unspecified('Setting (e.g. open-plan office, magical realm):'),
          primary_theme: ask_or_unspecified('Primary theme (e.g. disillusionment, adventure):'),
          secondary_themes: ask('Secondary themes (comma-separated, optional):', default: '')
        }
      end

      # Prompts for a free-text metadata value; an empty answer persists as
      # the literal sentinel "unspecified". NEVER substitute a real-looking
      # value. See specs/015-scaffold-hardening/spec.md FR-011.
      def ask_or_unspecified(prompt)
        response = ask(prompt, default: 'unspecified').to_s.strip
        response.empty? ? 'unspecified' : response
      end

      # When only one language was provided there's nothing to choose between,
      # so don't badger the user with a second prompt — just use that language.
      def resolve_default_language(languages)
        codes = (languages || 'en').split(',').map(&:strip).reject(&:empty?)
        return codes.first if codes.size <= 1

        ask('Default language code:', default: codes.first)
      end

      def create_world_structure(target, world_info)
        create_directories(target)
        create_metadata_files(target, world_info)
        create_story_bible(target)
        create_strings_data(target, world_info)
        create_settings_data(target)
      end

      def create_story_bible(target)
        require 'eidos/story_bible'
        Eidos::StoryBible.new(project_root: target).setup
      end

      # Offers to seed the Story Bible from the user's premise. Silent under
      # --quick and --no-seed; otherwise prompts (default Yes). All errors
      # inside SeedExtractor are non-fatal — they collapse to an empty result
      # with a warning, which we render as a skip-reason.
      def maybe_seed_story_bible(target, world_info)
        return if options[:quick]
        return if options['no-seed']
        return unless yes?('Seed the Story Bible from your premise? [Y/n]', :cyan)

        require 'eidos/seed_extractor'
        require 'eidos/story_bible'
        require 'eidos/llm_service'
        require 'eidos/configuration'

        bible = Eidos::StoryBible.new(project_root: target)
        llm = Eidos::LLMService.new(Eidos::Configuration.load(target))
        result = Eidos::SeedExtractor.new(llm_service: llm, story_bible: bible).extract(
          premise: world_info[:description].to_s
        )

        persist_seed_result(bible, result)
        report_seed_result(result)
      end

      def persist_seed_result(bible, result)
        result.characters.each do |char|
          id = Eidos::ValidationUtils.slugify(char['id'].to_s)
          next if id.empty?

          char['slug'] = id
          bible.save_character(id, char, change_reason: 'Seeded from premise')
        end
        result.locations.each do |loc|
          id = Eidos::ValidationUtils.slugify(loc['id'].to_s)
          next if id.empty?

          loc['slug'] = id
          bible.save_location(id, loc, change_reason: 'Seeded from premise')
        end
        result.facts.each_with_index do |fact, idx|
          data = { 'description' => fact, 'origin' => 'seed', 'origin_note' => 'derived from premise' }
          bible.add_fact('world_rules', "seed_#{idx + 1}", data, change_reason: 'Seeded from premise')
        end
      end

      def report_seed_result(result)
        if result.warnings.any?
          say "Seed skipped: #{result.warnings.first}", :yellow
        else
          say "Seeded #{result.characters.size} characters, #{result.locations.size} locations, " \
              "#{result.facts.size} facts.", :green
        end
      end

      def create_directories(target)
        FileUtils.mkdir_p(target)
        FileUtils.mkdir_p(File.join(target, 'data'))
        FileUtils.mkdir_p(File.join(target, 'content'))
      end

      def create_metadata_files(target, world_info)
        secondary_themes_array = world_info[:secondary_themes].strip.empty? ? [] : world_info[:secondary_themes].split(',').map(&:strip)

        metadata = build_world_metadata(world_info, secondary_themes_array)

        # Split metadata into config and state
        config_data, state_data = split_metadata(metadata)

        write_yaml_file(File.join(target, 'data', 'world_config.yml'), config_data)
        write_yaml_file(File.join(target, 'data', 'world_state.yml'), state_data)

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

      def build_world_metadata(world_info, secondary_themes_array)
        {
          'world' => {
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
              'story_title' => world_info[:title],
              'subtitle' => world_info[:description],
              'author' => world_info[:author],
              'story_genre' => world_info[:genre],
              'story_style' => world_info[:style],
              'story_setting' => world_info[:setting],
              'themes' => {
                'primary' => world_info[:primary_theme],
                'secondary' => secondary_themes_array
              }
            }
          },
          # Legacy fields for backward compatibility
          'title' => world_info[:title],
          'author' => world_info[:author],
          'description' => world_info[:description],
          'languages' => (world_info[:languages] || 'en').split(',').map(&:strip),
          'default_language' => world_info[:default_lang]
        }
      end

      def create_strings_data(target, world_info)
        strings_data = build_strings_data(world_info)
        add_russian_strings_data(strings_data, world_info) if includes_russian?(world_info[:languages])
        write_yaml_file(File.join(target, 'data', 'strings.yml'), strings_data)
      end

      def build_strings_data(world_info)
        {
          'en' => {
            'site_title' => world_info[:title],
            'site_subtitle' => world_info[:description],
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

      def add_russian_strings_data(strings_data, world_info)
        strings_data['ru'] = {
          'site_title' => world_info[:title].to_s,
          'site_subtitle' => world_info[:description],
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
            'provider' => 'openrouter',
            'model' => 'google/gemini-3-flash-preview',
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
            'provider' => 'openrouter',
            'model' => 'google/gemini-3-flash-preview'
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
          },
          'storage' => {
            'backend' => 'yaml_file'
          }
        }
        write_yaml_file(File.join(target, 'data', 'settings.yml'), settings_data)
      end

      def includes_russian?(languages)
        (languages || 'en').split(',').map(&:strip).include?('ru')
      end

      def split_metadata(data)
        state_keys = %w[world book status]
        state_data  = data.slice(*state_keys)
        config_data = data.except(*state_keys)
        [config_data, state_data]
      end
    end
  end
end
