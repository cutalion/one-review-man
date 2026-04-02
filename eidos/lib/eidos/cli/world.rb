# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'yaml'
require 'eidos/cli/helpers'
require 'eidos/cli/version'
require 'eidos/world_config'
require 'eidos/reset'

module Eidos
  module CLI
    # CLI commands for world management: init, status, reset, migrate, version
    class World < Thor
      include Helpers

      # --- new (init) -----------------------------------------------------------

      desc 'new', 'Initialize a new world project'
      method_option 'world-dir', aliases: ['-b', '-w'], type: :string,
                                 desc: 'Path to the world directory (defaults to current directory)'
      method_option :quick, type: :boolean, default: false,
                            desc: 'Quick setup with minimal prompts (uses intelligent defaults)'
      def new
        target = File.expand_path(options['world-dir'] || Dir.pwd)

        validate_target_directory(target)
        world_info = collect_world_information
        create_world_structure(target, world_info)

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
        title       = ask('World title:', default: 'My New World')
        author      = ask('Author name:', default: 'Anonymous')
        description = ask('Short description:', default: 'A generated world.')
        languages   = ask('Languages (comma-separated, e.g. en,ru):', default: 'en')
        default_lang = ask('Default language code:', default: (languages || 'en').split(',').first.strip)

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
        genre         = infer_genre_from_description(description)
        style         = infer_style_from_description(description)
        setting       = infer_setting_from_description(description)
        primary_theme = infer_theme_from_description(description)

        say "\nQuick setup enabled - using intelligent defaults:", :cyan
        say "  Genre: #{genre}", :blue
        say "  Style: #{style}", :blue
        say "  Setting: #{setting}", :blue
        say "  Theme: #{primary_theme}", :blue

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
        say "\nAdditional information needed for chapter generation:", :cyan

        genre_examples = 'fantasy, sci-fi, mystery, thriller, comedy, romance, adventure, horror'
        genre = ask("What genre is your world? (#{genre_examples}):", default: 'fiction')

        style_examples = 'humorous, serious, adventurous, suspenseful, whimsical, dramatic'
        style = ask("What writing style? (#{style_examples}):", default: 'narrative')

        setting = ask('What is the main setting/location of your story?', default: 'contemporary setting')

        primary_theme    = ask('What is the primary theme? (e.g., friendship, mystery, adventure):', default: 'adventure')
        secondary_themes = ask('Secondary themes (comma-separated, optional):', default: '')

        target_chapters = ask('Target number of chapters:', default: '10').to_i

        {
          genre: genre,
          style: style,
          setting: setting,
          primary_theme: primary_theme,
          secondary_themes: secondary_themes,
          target_chapters: target_chapters
        }
      end

      def create_world_structure(target, world_info)
        create_directories(target)
        create_metadata_files(target, world_info)
        create_world_data(target, world_info)
        create_strings_data(target, world_info)
        create_settings_data(target)
      end

      def create_directories(target)
        FileUtils.mkdir_p(target)
        FileUtils.mkdir_p(File.join(target, 'data'))
        FileUtils.mkdir_p(File.join(target, 'content', 'chapters'))
        FileUtils.mkdir_p(File.join(target, 'content', 'characters'))
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
            'target_chapters' => world_info[:target_chapters],
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
              'title' => world_info[:title],
              'subtitle' => world_info[:description],
              'author' => world_info[:author],
              'genre' => world_info[:genre],
              'humor_style' => world_info[:style],
              'setting' => world_info[:setting],
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

      def create_world_data(target, world_info)
        world_data = build_world_data(world_info)
        add_russian_world_data(world_data, world_info) if includes_russian?(world_info[:languages])
        write_yaml_file(File.join(target, 'data', 'world.yml'), world_data)
      end

      def build_world_data(world_info)
        {
          'en' => {
            'world' => {
              'main_setting' => {
                'name' => world_info[:setting],
                'description' => "The primary location where the story of #{world_info[:title]} unfolds",
                'type' => 'primary',
                'established_chapter' => 'Chapter 1'
              },
              'culture' => {
                'narrative_style' => {
                  'description' => "#{world_info[:style]} storytelling with engaging characters",
                  'established_chapter' => 'Chapter 1'
                }
              },
              'established_facts' => [
                "Story takes place in #{world_info[:setting]}",
                "Genre focuses on #{world_info[:genre]} elements",
                "Primary theme is #{world_info[:primary_theme]}",
                "Writing style is #{world_info[:style]}"
              ]
            }
          }
        }
      end

      def add_russian_world_data(world_data, world_info)
        world_data['ru'] = {
          'world' => {
            'main_setting' => {
              'name' => world_info[:setting],
              'description' => "Основное место, где разворачивается история #{world_info[:title]}",
              'type' => 'primary',
              'established_chapter' => 'Глава 1'
            }
          }
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
        state_keys = %w[world book status]
        state_data  = data.slice(*state_keys)
        config_data = data.except(*state_keys)
        [config_data, state_data]
      end
    end
  end
end
