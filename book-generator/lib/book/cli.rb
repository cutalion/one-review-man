# frozen_string_literal: true

require 'thor'
require 'fileutils'
require 'yaml'
require 'book/cli/version'
require 'book/translator'
require 'book_core/reset'
require 'book_core/chapter_generator'

module Book
  module CLI
    # Utilities shared by subcommands
    module Helpers
      private

      # Non-terminating resolver: returns project root or nil
      def resolve_project_root(candidate = nil)
        candidate ||= Dir.pwd
        data_dir = File.join(candidate, 'data')
        metadata = File.join(data_dir, 'book_metadata.yml')
        return candidate if File.exist?(metadata)
        nil
      end

      def resolve_project_root!(explicit_path = nil)
        candidate = explicit_path || Dir.pwd
        data_dir = File.join(candidate, 'data')
        metadata = File.join(data_dir, 'book_metadata.yml')
        return candidate if File.exist?(metadata)

        $stderr.puts 'Not a book directory (missing data/book_metadata.yml).'
        path = ask('Path to book directory (leave empty to abort):')
        if path && !path.strip.empty?
          return resolve_project_root!(File.expand_path(path.strip))
        end

        $stderr.puts 'Aborted. Please run in a book directory or pass --project-dir.'
        exit 1
      end

      def write_yaml_file(path, hash)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, hash.to_yaml)
      end
    end
    class Generate < Thor
      include Helpers

      class_option :model, type: :string, desc: 'Specify the model to use for generation'
      class_option :auto, type: :boolean, default: false, desc: 'Auto mode: skip interactive prompts'
      class_option :debug, type: :boolean, default: false, desc: 'Enable verbose LLM debug logging'
      class_option :project_dir, type: :string, desc: 'Path to the book directory (defaults to current directory)'

      desc 'chapter [NUMBER]', 'Generate a chapter'
      def chapter(number = nil)
        model_name = options[:model]
        project_root = resolve_project_root!(options[:project_dir])
        abs_root = File.expand_path(project_root)
        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]
          generator = BookCore::ChapterGenerator.new(model_name, project_root: abs_root)
          generator.generate_next_chapter(auto_generate: options[:auto])
        end
      end

      desc 'prompt [NUMBER]', 'Show generation prompt'
      def prompt(number = nil)
        project_root = resolve_project_root(options[:project_dir])
        unless project_root
          puts 'prompt stub for chapter'
          return
        end

        abs_root = File.expand_path(project_root)
        Dir.chdir(abs_root) do
          generator = BookCore::ChapterGenerator.new(options[:model], project_root: abs_root)
          chapter_number = number ? number.to_i : generator.send(:determine_next_chapter_number)
          prompt = generator.send(:build_chapter_prompt, chapter_number)
          puts prompt
        end
      end
    end

    class Translate < Thor
      include Helpers

      class_option :model, type: :string, desc: 'Specify the model to use for translation'
      class_option :debug, type: :boolean, default: false, desc: 'Enable verbose LLM debug logging'
      class_option :project_dir, type: :string, desc: 'Path to the book directory (defaults to current directory)'

      desc 'chapter NUMBER LANG', 'Translate a chapter to a language'
      def chapter(number, lang)
        book_root = resolve_project_root!(options[:project_dir])
        abs_root = File.expand_path(book_root)
        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]
          translator = Book::Translator.new(options[:model], project_root: abs_root)
          translator.translate_chapter_with_ai(number.to_i, lang)
        end
      end

      desc 'character SLUG LANG', 'Translate a character to a language'
      def character(slug, lang)
        book_root = resolve_project_root!(options[:project_dir])
        abs_root = File.expand_path(book_root)
        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]
          translator = Book::Translator.new(options[:model], project_root: abs_root)
          translator.translate_character_with_ai(slug, lang)
        end
      end

      desc 'all LANG', 'Translate all content to a language'
      def all(lang)
        book_root = resolve_project_root!(options[:project_dir])
        abs_root = File.expand_path(book_root)
        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]
          translator = Book::Translator.new(options[:model], project_root: abs_root)
          translator.translate_all_content(lang)
        end
      end
    end

    class Init < Thor
      include Helpers

      desc 'here [PATH]', 'Initialise a new book in PATH (or current directory)'
      method_option :path, aliases: '-p', type: :string, desc: 'Target directory (defaults to CWD)'
      def here(path = nil)
        target = File.expand_path(path || options[:path] || Dir.pwd)

        title = ask('Book title:', default: 'My New Book')
        author = ask('Author name:', default: 'Anonymous')
        description = ask('Short description:', default: 'A generated book.')
        languages = ask('Languages (comma-separated, e.g. en,ru):', default: 'en')
        default_lang = ask('Default language code:', default: languages.split(',').first.strip)

        FileUtils.mkdir_p(target)
        FileUtils.mkdir_p(File.join(target, 'data'))
        FileUtils.mkdir_p(File.join(target, '_chapters'))
        FileUtils.mkdir_p(File.join(target, '_characters'))
        FileUtils.mkdir_p(File.join(target, 'scripts'))

        # Minimal data files
        write_yaml_file(File.join(target, 'data', 'book_metadata.yml'), {
          'title' => title,
          'author' => author,
          'description' => description,
          'languages' => languages.split(',').map { |s| s.strip },
          'default_language' => default_lang
        })

        write_yaml_file(File.join(target, 'data', 'characters.yml'), { 'characters' => [] })
        write_yaml_file(File.join(target, 'data', 'generation_log.yml'), { 'chapters' => [] })

        # LLM config stub living INSIDE the book folder
        llm_config_path = File.join(target, 'scripts', 'llm_config.yml')
        unless File.exist?(llm_config_path)
          write_yaml_file(llm_config_path, {
            'provider' => 'openai',
            'model' => 'gpt-4o-mini',
            'temperature' => 0.7,
            'api_key' => ENV['OPENAI_API_KEY'] || 'set-me-via-env'
          })
        end

        say "Initialised book at: #{target}", :green
      end
    end

    class Jekyll < Thor
      include Helpers

      desc 'generate [DEST]', 'Create or update a Jekyll site from the current book content'
      method_option :dest, aliases: '-d', type: :string, desc: 'Destination directory for the Jekyll site (defaults to ./site)'
      class_option :project_dir, type: :string, desc: 'Path to the book directory (defaults to current directory)'
      def generate(dest = nil)
        book_root = resolve_project_root!(options[:project_dir])
        dest_dir = File.expand_path(dest || options[:dest] || File.join(book_root, 'site'))

        # Prefer local template bundled with this repo layout
        template_root = ENV['JEKYLL_TEMPLATE_PATH'] || File.expand_path('../../../jekyll-site/site_template', __dir__)
        unless Dir.exist?(template_root)
          say 'Jekyll site template not found. Ensure the jekyll-site package is available.', :red
          exit 1
        end

        FileUtils.mkdir_p(dest_dir)

        # Copy template (skip content dirs which we handle separately)
        Dir.children(template_root).each do |entry|
          next if %w[_chapters _characters _data].include?(entry)
          src = File.join(template_root, entry)
          dst = File.join(dest_dir, entry)
          if File.directory?(src)
            FileUtils.mkdir_p(dst)
            Dir.glob(File.join(src, '**', '*'), File::FNM_DOTMATCH).each do |path|
              next if ['.', '..'].include?(File.basename(path))
              rel = path.delete_prefix(src + '/')
              target = File.join(dst, rel)
              if File.directory?(path)
                FileUtils.mkdir_p(target)
              else
                FileUtils.cp(path, target) unless File.exist?(target)
              end
            end
          else
            FileUtils.cp(src, dst) unless File.exist?(dst)
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
          }
        ].each do |mapping|
          src = mapping[:candidates].find { |p| Dir.exist?(p) }
          dst = File.join(dest_dir, mapping[:dst_name])
          begin
            FileUtils.rm_rf(dst)
            if src
              FileUtils.mkdir_p(File.dirname(dst))
              FileUtils.cp_r(src, dst)
            else
              FileUtils.mkdir_p(dst)
            end
          rescue StandardError => e
            say "Failed to copy #{mapping[:dst_name]}: #{e.message}", :yellow
          end
        end

        say "Jekyll site prepared at: #{dest_dir}", :green
        say 'Run `jekyll build` inside that directory to build the site.'
      end
    end

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

    class Runner < Thor
      desc 'generate SUBCOMMAND ...ARGS', 'Generate content'
      subcommand 'generate', Generate

      desc 'translate SUBCOMMAND ...ARGS', 'Translate content'
      subcommand 'translate', Translate

      desc 'init SUBCOMMAND ...ARGS', 'Project scaffolding commands'
      subcommand 'init', Init

      desc 'jekyll SUBCOMMAND ...ARGS', 'Jekyll site operations'
      subcommand 'jekyll', Jekyll

      desc 'reset SUBCOMMAND ...ARGS', 'Reset generated content'
      subcommand 'reset', Reset

      desc 'version', 'Show version'
      def version
        puts Book::CLI::VERSION
      end

      map %w[--version -v] => :version
    end
  end
end
