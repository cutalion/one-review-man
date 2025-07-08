# frozen_string_literal: true

require 'thor'
require 'fileutils'
require_relative 'cli/version'
require_relative '../book/chapter_generator'
require_relative '../book/translator'
require_relative '../book/reset'

module Book
  module CLI
    # ---- Subcommand definitions ----

    # Generate command suite (chapter, prompt, etc.)
    class Generate < Thor
      desc 'chapter', 'Generate the next chapter'
      method_option :auto, type: :boolean, default: false, desc: 'Generate without interactive prompts'
      method_option :model, type: :string, desc: 'Specify LLM model (e.g., gpt-4o, gpt-4o-mini)'
      def chapter
        generator = Book::ChapterGenerator.new(options[:model])
        generator.generate_next_chapter(auto_generate: options[:auto])
      end

      desc 'prompt [NUMBER]', 'Show generation prompt'
      def prompt(number = nil)
        puts "prompt stub for chapter #{number || 'next'}"
      end
    end

    # Translate command suite (chapter, character, etc.)
    class Translate < Thor
      desc 'chapter <number> <lang>', 'Translate a chapter'
      method_option :model, type: :string, desc: 'Specify LLM model (e.g., gpt-4o, gpt-4o-mini)'
      def chapter(number, lang)
        translator = Book::Translator.new(options[:model])
        translator.translate_chapter_with_ai(number.to_i, lang)
      end

      desc 'character <slug> <lang>', 'Translate a character'
      method_option :model, type: :string, desc: 'Specify LLM model (e.g., gpt-4o, gpt-4o-mini)'
      def character(slug, lang)
        translator = Book::Translator.new(options[:model])
        translator.translate_character_with_ai(slug, lang)
      end

      desc 'all <lang>', 'Translate all content'
      method_option :model, type: :string, desc: 'Specify LLM model (e.g., gpt-4o, gpt-4o-mini)'
      def all(lang)
        translator = Book::Translator.new(options[:model])
        translator.translate_all_content(lang)
      end
    end

    # Reset command suite
    class Reset < Thor
      desc 'all', 'Reset everything'
      method_option :force, type: :boolean, default: false, desc: 'Skip confirmation prompts'
      def all
        reset = Book::Reset.new
        reset.reset_all(force: options[:force])
      end

      desc 'characters', 'Reset only characters'
      method_option :force, type: :boolean, default: false, desc: 'Skip confirmation prompts'
      def characters
        reset = Book::Reset.new
        reset.reset_characters(force: options[:force])
      end

      desc 'chapters', 'Reset only chapters'
      method_option :force, type: :boolean, default: false, desc: 'Skip confirmation prompts'
      def chapters
        reset = Book::Reset.new
        reset.reset_chapters(force: options[:force])
      end

      desc 'data', 'Reset only _data/*.yml files'
      def data
        reset = Book::Reset.new
        reset.reset_data_files
      end

      desc 'site', 'Clean generated site files'
      def site
        reset = Book::Reset.new
        reset.reset_generated_site
      end

      desc 'status', 'Show current book status'
      def status
        reset = Book::Reset.new
        reset.status
      end
    end

    # Main command-line interface for the `book` tool.
    class Runner < Thor
      class_option :verbose, type: :boolean, desc: 'Enable verbose output'

      desc 'version', 'Print the version information'
      map %w[--version -v] => :version
      def version
        puts VERSION
      end

      # Attach subcommands
      desc 'generate SUBCOMMAND ...', 'Generate content (chapters, prompts, etc.)'
      subcommand 'generate', Book::CLI::Generate

      desc 'translate SUBCOMMAND ...', 'Translate content (chapters, characters, etc.)'
      subcommand 'translate', Book::CLI::Translate

      desc 'reset SUBCOMMAND ...', 'Reset book content'
      subcommand 'reset', Book::CLI::Reset

      def self.exit_on_failure?
        true
      end
    end
  end
end