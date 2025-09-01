# frozen_string_literal: true

require 'fileutils'
require 'yaml'
require 'date'

module BookCore
  # Adapter that writes book content into the book's content/ directories
  # rather than Jekyll site collections. This keeps authored content separate
  # from site output. The Jekyll command later maps these into _chapters/_characters.
  class BookContentAdapter
    def setup_project(project_root = Dir.pwd)
      @project_root = File.expand_path(project_root)
      FileUtils.mkdir_p(File.join(@project_root, 'content', 'chapters'))
      FileUtils.mkdir_p(File.join(@project_root, 'content', 'characters'))
    end

    def write_chapter(chapter_number, content, metadata = {})
      filename = File.join(@project_root, 'content', 'chapters', "#{format('%03d', chapter_number)}-chapter.md")
      default_front_matter = {
        'layout' => 'chapter',
        'title' => "Chapter #{chapter_number}"
      }
      # Allow rich metadata from generator; stringify keys for YAML consistency
      merged = default_front_matter.merge(stringify_keys(metadata))
      write_file(filename, merged, content)
    end

    def write_character_page(slug, character_data)
      filename = File.join(@project_root, 'content', 'characters', "#{slug}.md")
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

      body_lines = []
      body_lines << "## About #{character_data['name']}"
      body_lines << ''
      body_lines << (character_data['description'] || '')
      body_lines << ''
      write_file(filename, front_matter, body_lines.join("\n"))
    end

    private

    def write_file(filename, front_matter, body)
      FileUtils.mkdir_p(File.dirname(filename))
      File.open(filename, 'w') do |file|
        file.puts '---'
        file.puts front_matter.to_yaml.lines[1..]
        file.puts '---'
        file.puts ''
        file.puts body if body && !body.empty?
        file.puts ''
      end
    end

    def stringify_keys(hash)
      hash.transform_keys(&:to_s)
    end
  end
end
