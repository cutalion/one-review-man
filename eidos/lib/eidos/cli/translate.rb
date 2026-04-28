# frozen_string_literal: true

require 'thor'
require 'eidos/cli/helpers'
require 'eidos/cli/unknown_command_help'
require 'eidos/translator'
require 'eidos/configuration'

module Eidos
  module CLI
    # CLI commands for translating world content
    class Translate < Thor
      extend Eidos::CLI::UnknownCommandHelp
      include Eidos::CLI::Helpers

      class_option 'world-dir', aliases: ['-w'], type: :string,
                                desc: 'Path to the world directory (defaults to current directory)'
      class_option 'content-model', type: :string,
                                    desc: 'Specify the model to use for translation (defaults to settings.yml)'
      class_option :debug, type: :boolean, default: false, desc: 'Enable verbose LLM debug logging'

      desc 'chapter NUMBER LANG', 'Translate a specific chapter'
      def chapter(number, lang)
        abs_root = resolve_project_root!(options['world-dir'])

        config = Eidos::Configuration.load(abs_root, options)

        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]
          translator = Eidos::Translator.new(config: config, project_root: abs_root)
          translator.translate_chapter_with_ai(number.to_i, lang)
        end
      end

      desc 'character SLUG LANG', 'Translate a specific character'
      def character(slug, lang)
        abs_root = resolve_project_root!(options['world-dir'])

        config = Eidos::Configuration.load(abs_root, options)

        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]
          translator = Eidos::Translator.new(config: config, project_root: abs_root)
          translator.translate_character_with_ai(slug, lang)
        end
      end

      desc 'all LANG', 'Translate all content'
      def all(lang)
        abs_root = resolve_project_root!(options['world-dir'])

        config = Eidos::Configuration.load(abs_root, options)

        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]
          translator = Eidos::Translator.new(config: config, project_root: abs_root)
          translator.translate_all_content?(lang)
        end
      end
    end
  end
end
