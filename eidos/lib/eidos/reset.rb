#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require_relative 'utils'

module Eidos
  # Utilities for resetting world project content and state
  class Reset
    include Eidos::Utils

    # Initialize the reset helper.
    #
    # Parameters
    # ----------
    # io: (IO)
    #   Stream used for interactive prompts.  Defaults to `$stdin` so existing
    #   behaviour is unchanged but can be overridden in tests with a `StringIO`
    #   (or similar) object to avoid blocking for user input.
    def initialize(io: $stdin)
      @dry_run = false
      @io = io
    end

    def reset_all(force: false)
      puts '🔄 World Reset Tool'
      puts '=' * 50

      unless force
        puts '⚠️  WARNING: This will delete ALL world content!'
        puts ''
        puts 'This action will:'
        puts '- Remove all character files and data'
        puts '- Remove all chapter files'
        puts '- Reset all data/*.yml files to initial state'
        puts '- Clear generation logs'
        puts ''
        print "Are you absolutely sure? Type 'RESET' to confirm: "

        confirmation = @io.gets.chomp
        unless confirmation == 'RESET'
          puts '❌ Reset cancelled.'
          return false
        end
      end

      puts "\n🧹 Starting world reset..."

      success = true
      success &= reset_characters(force: true)
      success &= reset_chapters(force: true)
      success &= reset_data_files
      success &= reset_generated_site

      if success
        puts "\n✅ World reset completed successfully!"
        puts '📝 The world is now in its initial empty state.'
      else
        puts "\n❌ Some errors occurred during reset."
      end

      success
    end

    def reset_characters(force: false)
      unless force
        puts "\n📊 Character Reset Preview:"
        character_files = Dir.glob('_characters/*.md')
        if character_files.empty?
          puts '  No character files found.'
          return true # Nothing to reset
        else
          puts '  Files to be deleted:'
          character_files.each { |f| puts "    - #{f}" }
        end

        print "\nProceed with character reset? (y/N): "
        begin
          response = @io.gets&.chomp&.downcase || 'n'
          unless response.start_with?('y')
            puts '❌ Character reset cancelled.'
            return false
          end
        rescue StandardError => e
          puts "❌ Input error: #{e.message}"
          puts '❌ Character reset cancelled.'
          return false
        end
      end

      puts "\n🎭 Resetting characters..."

      # Remove character files
      character_files = Dir.glob('_characters/*.md')
      character_files.each do |file|
        File.delete(file)
        puts "  🗑️  Deleted: #{file}"
      end

      # Reset characters.yml
      reset_characters_yml

      puts '✅ Characters reset completed.'
      true
    rescue StandardError => e
      puts "❌ Error resetting characters: #{e.message}"
      false
    end

    def reset_chapters(force: false)
      unless force
        puts "\n📊 Chapter Reset Preview:"
        chapter_files = Dir.glob('content/chapters/*.md')
        if chapter_files.empty?
          puts '  No chapter files found.'
          return true # Nothing to reset
        else
          puts '  Files to be deleted:'
          chapter_files.each { |f| puts "    - #{f}" }
        end

        print "\nProceed with chapter reset? (y/N): "
        begin
          response = @io.gets&.chomp&.downcase || 'n'
          unless response.start_with?('y')
            puts '❌ Chapter reset cancelled.'
            return false
          end
        rescue StandardError => e
          puts "❌ Input error: #{e.message}"
          puts '❌ Chapter reset cancelled.'
          return false
        end
      end

      puts "\n📚 Resetting chapters..."

      # Remove chapter files
      chapter_files = Dir.glob('content/chapters/*.md')
      chapter_files.each do |file|
        File.delete(file)
        puts "  🗑️  Deleted: #{file}"
      end

      puts '✅ Chapters reset completed.'
      true
    rescue StandardError => e
      puts "❌ Error resetting chapters: #{e.message}"
      false
    end

    def reset_data_files
      puts "\n💾 Resetting data files..."

      reset_book_metadata_yml
      reset_characters_yml
      reset_generation_log_yml

      puts '✅ Data files reset completed.'
      true
    rescue StandardError => e
      puts "❌ Error resetting data files: #{e.message}"
      false
    end

    def reset_generated_site
      puts "\n🌐 Cleaning generated site..."

      # Clean Jekyll cache
      if Dir.exist?('.jekyll-cache')
        FileUtils.rm_rf('.jekyll-cache')
        puts '  🗑️  Deleted: .jekyll-cache/'
      end

      # Clean _site directory
      if Dir.exist?('_site')
        FileUtils.rm_rf('_site')
        puts '  🗑️  Deleted: _site/'
      end

      puts '✅ Generated site cleanup completed.'
      true
    rescue StandardError => e
      puts "❌ Error cleaning generated site: #{e.message}"
      false
    end

    def status
      puts '📊 World Status'
      puts '=' * 30

      # Characters
      character_files = Dir.glob('_characters/*.md')
      characters_data = load_characters
      char_count = characters_data['characters']&.size || 0

      puts 'Characters:'
      puts "  📄 Files: #{character_files.size}"
      puts "  💾 In YAML: #{char_count}"

      # Chapters
      chapter_files = Dir.glob('content/chapters/*.md')
      chapters_data = get_all_chapters

      puts "\nChapters:"
      puts "  📄 Files: #{chapter_files.size}"
      puts "  📖 Parsed: #{chapters_data.size}"

      # Data files
      puts "\nData Files:"
      %w[world_config.yml world_state.yml characters.yml generation_log.yml strings.yml].each do |file|
        path = File.join('data', file)
        status = File.exist?(path) ? '✅ Exists' : '❌ Missing'
        puts "  #{file}: #{status}"
      end

      # Generated content
      puts "\nGenerated Content:"
      puts "  .jekyll-cache: #{Dir.exist?('.jekyll-cache') ? '✅ Exists' : '❌ Missing'}"
      puts "  _site: #{Dir.exist?('_site') ? '✅ Exists' : '❌ Missing'}"
    end

    private

    def reset_book_metadata_yml
      initial_data = {
        # Shared technical metadata (language-independent)
        'world' => {
          'target_chapters' => 50,
          'current_chapter' => 0
        },
        'generation' => {
          'chapter_length_target' => '1500-3000 words',
          'complexity_level' => 'medium',
          'character_consistency' => true
        },
        'status' => {
          'last_generated' => nil,
          'generation_count' => 0,
          'characters_created' => 0,
          'active_storylines' => [],
          'chapters_written' => 0
        },
        # Language-specific content only (defaults - to be customized per book)
        'localized' => {
          'en' => {
            'title' => 'Generated World',
            'subtitle' => 'An AI-Generated Story',
            'author' => 'AI Generator',
            'genre' => 'Fiction',
            'humor_style' => 'narrative',
            'themes' => {
              'primary' => 'general fiction',
              'secondary' => [
                'character development',
                'story progression',
                'engaging narrative'
              ]
            }
          },
          'ru' => {
            'title' => 'Сгенерированная Книга',
            'subtitle' => 'ИИ-Сгенерированная История',
            'author' => 'ИИ Генератор',
            'genre' => 'Художественная литература',
            'humor_style' => 'повествовательный',
            'themes' => {
              'primary' => 'общая художественная литература',
              'secondary' => [
                'развитие персонажей',
                'развитие сюжета',
                'увлекательное повествование'
              ]
            }
          }
        }
      }

      FileUtils.mkdir_p('data')
      File.write('data/world_metadata.yml', initial_data.to_yaml)
      puts '  Reset: world_metadata.yml'
    end

    def reset_characters_yml
      initial_data = {
        'en' => {
          'characters' => {}
        }
      }

      FileUtils.mkdir_p('data')
      File.write('data/characters.yml', initial_data.to_yaml)
      puts '  📝 Reset: characters.yml'
    end

    def reset_generation_log_yml
      initial_data = {
        'generations' => [],
        'used_plot_devices' => [],
        'character_interactions' => {}
      }

      FileUtils.mkdir_p('data')
      File.write('data/generation_log.yml', initial_data.to_yaml)
      puts '  📝 Reset: generation_log.yml'
    end
  end
end
