# frozen_string_literal: true

require 'fileutils'
require 'yaml'

module Book
  class JekyllWriter
    def initialize(config)
      @config = config
    end

    def write_chapter(chapter_num, chapter_data, characters)
      filename = "#{@config.chapters_dir}/#{format_chapter_filename(chapter_num)}"

      # Extract new characters if present
      new_characters = chapter_data['new_characters'] || []
      character_slugs = new_characters.map { |char| slugify(char['name']) }

      # Generate proper permalink for Jekyll Polyglot (use dashes, not underscores)
      chapter_slug = format_chapter_filename(chapter_num).gsub('.md', '').gsub('_', '-')
      permalink = "/chapters/#{chapter_slug}/"

      front_matter = {
        'layout' => 'chapter',
        'title' => chapter_data['title'],
        'chapter_number' => chapter_num,
        'characters' => characters.map { |c| c['slug'] },
        'new_characters' => character_slugs,
        'summary' => chapter_data['summary'],
        'programming_themes' => chapter_data['programming_themes'] || [],
        'comedy_elements' => chapter_data['comedy_elements'] || [],
        'word_count' => chapter_data['word_count'],
        'difficulty_level' => chapter_data['difficulty_level'],
        'one_punch_man_references' => chapter_data['one_punch_man_references'] || [],
        'permalink' => permalink,
        'generated_date' => Date.today.to_s,
        'status' => 'generated',
        'lang' => 'en'
      }

      File.open(filename, 'w') do |file|
        file.puts '---'
        file.puts front_matter.to_yaml.lines[1..] # Skip first "---" line
        file.puts '---'
        file.puts ''
        file.puts chapter_data['content']
        file.puts ''
      end
    end

    def write_character_page(slug, character_data)
      filename = "#{@config.characters_dir}/#{slug}.md"

      # Generate proper permalink for Jekyll Polyglot (use dashes, not underscores)
      permalink_slug = slug.gsub('_', '-')
      permalink = "/characters/#{permalink_slug}/"

      front_matter = {
        'layout' => 'character',
        'name' => character_data['name'],
        'slug' => slug,
        'description' => character_data['description'],
        'personality_traits' => character_data['personality_traits'] || [],
        'programming_skills' => character_data['programming_skills'],
        'first_appearance' => character_data['first_appearance'],
        'permalink' => permalink,
        'created_date' => Date.today.to_s,
        'lang' => 'en'
      }

      File.open(filename, 'w') do |file|
        file.puts '---'
        file.puts front_matter.to_yaml.lines[1..]
        file.puts '---'
        file.puts ''

        file.puts "## About #{character_data['name']}"
        file.puts ''
        file.puts character_data['description']
        file.puts ''

        if character_data['backstory']
          file.puts '## Backstory'
          file.puts ''
          file.puts character_data['backstory']
          file.puts ''
        end

        if character_data['quirks']
          file.puts '## Notable Quirks'
          file.puts ''
          file.puts character_data['quirks']
          file.puts ''
        end

        if character_data['catchphrase']
          file.puts '## Catchphrase'
          file.puts ''
          file.puts "> \"#{character_data['catchphrase']}\""
          file.puts ''
        end

        file.puts '## Appearances'
        file.puts ''
        file.puts "First appeared in: #{character_data['first_appearance'] || 'To be determined'}"
        file.puts ''
        file.puts '<!-- Chapter appearances will be tracked automatically -->'
      end
    end

    private

    def format_chapter_filename(chapter_num)
      "#{chapter_num.to_s.rjust(3, '0')}-chapter.md"
    end

    def slugify(name)
      name.downcase.gsub(/[^a-z0-9\u0430-\u044f]+/, '_').gsub(/^_+|_+$/, '')
    end
  end
end
