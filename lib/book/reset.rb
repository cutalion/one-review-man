#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require_relative 'utils/book_utils'
require_relative 'jekyll_helper'

module Book
  class Reset
    include BookUtils

    def initialize(config: nil)
      @config = config || Config.new
      @dry_run = false
    end

    def reset_all(force: false)
      puts '🔄 Book Reset Tool'
      puts '=' * 50

      unless force
        puts '⚠️  WARNING: This will delete ALL book content!'
        puts ''
        puts 'This action will:'
        puts '- Remove all character files and data'
        puts '- Remove all chapter files'
        puts '- Reset all _data/*.yml files to initial state'
        puts '- Clear generation logs'
        puts ''
        print "Are you absolutely sure? Type 'RESET' to confirm: "

        confirmation = $stdin.gets.chomp
        unless confirmation == 'RESET'
          puts '❌ Reset cancelled.'
          return false
        end
      end

      puts "\n🧹 Starting book reset..."

      success = true
      success &= reset_characters(force: true)
      success &= reset_chapters(force: true)
      success &= reset_data_files
      success &= JekyllHelper.clean_generated_site

      if success
        puts "\n✅ Book reset completed successfully!"
        puts '📝 The book is now in its initial empty state.'
      else
        puts "\n❌ Some errors occurred during reset."
      end

      success
    end

    def reset_characters(force: false)
      unless force
        puts "\n📊 Character Reset Preview:"
        character_files = Dir.glob("#{@config.characters_dir}/*.md")
        if character_files.empty?
          puts '  No character files found.'
          return true # Nothing to reset
        else
          puts '  Files to be deleted:'
          character_files.each { |f| puts "    - #{f}" }
        end

        print "\nProceed with character reset? (y/N): "
        begin
          response = $stdin.gets&.chomp&.downcase || 'n'
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
      character_files = Dir.glob("#{@config.characters_dir}/*.md")
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
        chapter_files = Dir.glob("#{@config.chapters_dir}/*.md")
        if chapter_files.empty?
          puts '  No chapter files found.'
          return true # Nothing to reset
        else
          puts '  Files to be deleted:'
          chapter_files.each { |f| puts "    - #{f}" }
        end

        print "\nProceed with chapter reset? (y/N): "
        begin
          response = $stdin.gets&.chomp&.downcase || 'n'
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
      chapter_files = Dir.glob("#{@config.chapters_dir}/*.md")
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

    def status
      puts '📊 Book Status'
      puts '=' * 30

      # Characters
      character_files = Dir.glob("#{@config.characters_dir}/*.md")
      characters_data = load_characters(@config)
      char_count = characters_data['characters']&.size || 0

      puts 'Characters:'
      puts "  📄 Files: #{character_files.size}"
      puts "  💾 In YAML: #{char_count}"

      # Chapters
      chapter_files = Dir.glob("#{@config.chapters_dir}/*.md")
      chapters_data = get_all_chapters

      puts "\nChapters:"
      puts "  📄 Files: #{chapter_files.size}"
      puts "  📖 Parsed: #{chapters_data.size}"

      # Data files
      puts "\nData Files:"
      %w[book_metadata.yml characters.yml generation_log.yml strings.yml].each do |file|
        path = File.join(@config.data_dir, file)
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
        'book' => {
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
        # Language-specific content only
        'localized' => {
          'en' => {
            'title' => 'One Review Man',
            'subtitle' => 'An AI-Generated Comedy of Errors',
            'author' => 'AI Collective',
            'genre' => 'Humor/Comedy',
            'humor_style' => 'absurdist',
            'themes' => {
              'primary' => 'workplace comedy',
              'secondary' => [
                'mistaken identity',
                'bureaucratic absurdity',
                'everyday situations gone wrong'
              ]
            }
          },
          'ru' => {
            'title' => 'Ванревьюмэн',
            'subtitle' => 'ИИ-генерируемая Комедия Ошибок',
            'author' => 'ИИ Коллектив',
            'genre' => 'Юмор/Комедия',
            'humor_style' => 'абсурдистский',
            'themes' => {
              'primary' => 'рабочая комедия',
              'secondary' => [
                'ошибочная идентичность',
                'бюрократический абсурд',
                'обычные ситуации, которые идут не так'
              ]
            }
          }
        }
      }

      File.write("#{@config.data_dir}/book_metadata.yml", initial_data.to_yaml)
      puts '  📝 Reset: book_metadata.yml'
    end

    def reset_characters_yml
      initial_data = {
        'en' => {
          'characters' => {}
        }
      }

      File.write("#{@config.data_dir}/characters.yml", initial_data.to_yaml)
      puts '  📝 Reset: characters.yml'
    end

    def reset_generation_log_yml
      initial_data = {
        'generations' => [],
        'used_plot_devices' => [],
        'character_interactions' => {}
      }

      File.write("#{@config.data_dir}/generation_log.yml", initial_data.to_yaml)
      puts '  📝 Reset: generation_log.yml'
    end
  end
end