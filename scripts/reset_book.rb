#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require_relative 'book_utils'

class BookReset
  include BookUtils

  def initialize
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

      confirmation = gets.chomp
      unless confirmation == 'RESET'
        puts '❌ Reset cancelled.'
        return false
      end
    end

    puts "\n🧹 Starting book reset..."

    success = true
    success &= reset_characters
    success &= reset_chapters
    success &= reset_data_files
    success &= reset_generated_site

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
      chapter_files = Dir.glob('_chapters/*.md')
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
    chapter_files = Dir.glob('_chapters/*.md')
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
    puts '📊 Book Status'
    puts '=' * 30

    # Characters
    character_files = Dir.glob('_characters/*.md')
    characters_data = load_characters
    char_count = characters_data['characters']&.size || 0

    puts 'Characters:'
    puts "  📄 Files: #{character_files.size}"
    puts "  💾 In YAML: #{char_count}"

    # Chapters
    chapter_files = Dir.glob('_chapters/*.md')
    chapters_data = get_all_chapters

    puts "\nChapters:"
    puts "  📄 Files: #{chapter_files.size}"
    puts "  📖 Parsed: #{chapters_data.size}"

    # Data files
    puts "\nData Files:"
    %w[book_metadata.yml characters.yml generation_log.yml strings.yml].each do |file|
      path = File.join('_data', file)
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
      'en' => {
        'book' => {
          'title' => 'One Review Man',
          'subtitle' => 'An AI-Generated Comedy of Errors',
          'author' => 'AI Collective',
          'genre' => 'Humor/Comedy',
          'target_chapters' => 50,
          'current_chapter' => 0
        },
        'generation' => {
          'model' => 'gpt-4.1',
          'chapter_length_target' => '1500-3000 words',
          'humor_style' => 'absurdist',
          'complexity_level' => 'medium',
          'character_consistency' => true
        },
        'themes' => {
          'primary' => 'workplace comedy',
          'secondary' => [
            'mistaken identity',
            'bureaucratic absurdity',
            'everyday situations gone wrong'
          ]
        },
        'status' => {
          'last_generated' => nil,
          'generation_count' => 0,
          'characters_created' => 0,
          'active_storylines' => [],
          'chapters_written' => 0
        }
      },
      'ru' => {
        'book' => {
          'title' => 'Ванревьюмэн',
          'subtitle' => 'ИИ-генерируемая Комедия Ошибок',
          'author' => 'ИИ Коллектив',
          'genre' => 'Юмор/Комедия',
          'target_chapters' => 50,
          'current_chapter' => 0
        },
        'generation' => {
          'model' => 'gpt-4.1',
          'chapter_length_target' => '1500-3000 слов',
          'humor_style' => 'абсурдистский',
          'complexity_level' => 'средний',
          'character_consistency' => true
        },
        'themes' => {
          'primary' => 'рабочая комедия',
          'secondary' => [
            'ошибочная идентичность',
            'бюрократический абсурд',
            'обычные ситуации, которые идут не так'
          ]
        },
        'status' => {
          'last_generated' => nil,
          'generation_count' => 0,
          'characters_created' => 0,
          'active_storylines' => [],
          'chapters_written' => 0
        }
      }
    }

    File.write('_data/book_metadata.yml', initial_data.to_yaml)
    puts '  📝 Reset: book_metadata.yml'
  end

  def reset_characters_yml
    initial_data = {
      'en' => {
        'characters' => {}
      }
    }

    File.write('_data/characters.yml', initial_data.to_yaml)
    puts '  📝 Reset: characters.yml'
  end

  def reset_generation_log_yml
    initial_data = {
      'generations' => [],
      'used_plot_devices' => [],
      'character_interactions' => {}
    }

    File.write('_data/generation_log.yml', initial_data.to_yaml)
    puts '  📝 Reset: generation_log.yml'
  end
end

# Command line interface
if __FILE__ == $PROGRAM_NAME
  reset_tool = BookReset.new

  case ARGV[0]
  when 'all'
    force = ARGV.include?('--force')
    reset_tool.reset_all(force: force)

  when 'characters'
    force = ARGV.include?('--force')
    reset_tool.reset_characters(force: force)

  when 'chapters'
    force = ARGV.include?('--force')
    reset_tool.reset_chapters(force: force)

  when 'data'
    reset_tool.reset_data_files

  when 'site'
    reset_tool.reset_generated_site

  when 'status'
    reset_tool.status

  else
    puts 'One Review Man - Book Reset Tool'
    puts ''
    puts 'Usage:'
    puts '  ruby reset_book.rb all              # Reset everything (interactive)'
    puts '  ruby reset_book.rb all --force      # Reset everything (no prompts)'
    puts '  ruby reset_book.rb characters       # Reset only characters'
    puts '  ruby reset_book.rb chapters         # Reset only chapters'
    puts '  ruby reset_book.rb data             # Reset only _data/*.yml files'
    puts '  ruby reset_book.rb site             # Clean generated site files'
    puts '  ruby reset_book.rb status           # Show current book status'
    puts ''
    puts 'Examples:'
    puts '  ruby reset_book.rb status           # Check what content exists'
    puts '  ruby reset_book.rb characters       # Remove all characters'
    puts '  ruby reset_book.rb all              # Full reset (with confirmation)'
    puts '  ruby reset_book.rb all --force      # Full reset (no confirmation)'
    puts ''
    puts '⚠️  WARNING: Reset operations delete content permanently!'
  end
end
