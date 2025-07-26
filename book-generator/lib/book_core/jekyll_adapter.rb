# frozen_string_literal: true

require 'fileutils'
require 'yaml'
require 'date'

module BookCore
  class JekyllAdapter
    # Prepare a fresh Jekyll project structure by ensuring the mandatory
    # `_layouts/` and `_includes/` directories (and a few default files) are
    # present. This is purely additive – it NEVER overwrites existing user
    # files – so behaviour for existing projects remains 100% unchanged.

    DEFAULT_TEMPLATE_PATH = File.expand_path('../../../templates/jekyll', __dir__)

    # Public: Ensure the given +project_root+ has the minimum folder & file
    # structure required for a Jekyll book site.
    #
    # project_root - String absolute path. Defaults to the current working
    #                directory so callers can simply invoke `setup_project`.
    #
    # Returns nothing.
    def setup_project(project_root = Dir.pwd)
      @project_root = File.expand_path(project_root)

      layouts_dir  = File.join(@project_root, '_layouts')
      includes_dir = File.join(@project_root, '_includes')

      FileUtils.mkdir_p(layouts_dir)
      FileUtils.mkdir_p(includes_dir)

      copy_default_layouts(layouts_dir)
      copy_default_includes(includes_dir)
    end

    # Write a chapter file with proper Jekyll front-matter
    def write_chapter(chapter_number, content, metadata = {})
      filename = File.join(@project_root, "_chapters/#{format('%03d', chapter_number)}-chapter.md")
      front_matter = {
        'layout' => 'chapter',
        'title' => "Chapter #{chapter_number}",
        **metadata
      }
      write_file(filename, front_matter, content)
    end

    private

    # Internal: Copy default layout templates unless the user already created
    # them. Safe-no-op when template source is missing (e.g., developer hasn’t
    # added templates to the gem yet).
    def copy_default_layouts(target_dir)
      default_layouts_dir = File.join(DEFAULT_TEMPLATE_PATH, 'layouts')
      return unless Dir.exist?(default_layouts_dir)

      Dir.glob(File.join(default_layouts_dir, '*')).each do |src|
        dest = File.join(target_dir, File.basename(src))
        FileUtils.cp(src, dest) unless File.exist?(dest)
      end
    end

    # Internal: Copy default include templates unless they already exist.
    def copy_default_includes(target_dir)
      default_includes_dir = File.join(DEFAULT_TEMPLATE_PATH, 'includes')
      return unless Dir.exist?(default_includes_dir)

      Dir.glob(File.join(default_includes_dir, '*')).each do |src|
        dest = File.join(target_dir, File.basename(src))
        FileUtils.cp(src, dest) unless File.exist?(dest)
      end
    end

    # ---------------------------------------------------------------
    #  Below: full Jekyll writing helpers migrated from legacy class
    # ---------------------------------------------------------------

    # Generic helper – writes a markdown file with YAML front-matter followed
    # by the supplied body string. Creates parent directories if missing.
    #
    # filename      – String path (e.g. "_chapters/001-chapter.md")
    # front_matter  – Hash that will be serialised as YAML
    # body          – String markdown content (can be empty)
    def write_file(filename, front_matter, body)
      FileUtils.mkdir_p(File.dirname(filename))

      File.open(filename, 'w') do |file|
        file.puts '---'
        file.puts front_matter.to_yaml.lines[1..] # Skip leading '---'
        file.puts '---'
        file.puts ''
        file.puts body if body && !body.empty?
        file.puts ''
      end
    end

    # Convenience wrapper for creating character pages.
    def write_character_page(slug, character_data)
      filename = File.join(@project_root, "_characters/#{slug}.md")
      permalink_slug = slug.gsub('_', '-')
      permalink = "/characters/#{permalink_slug}/"

      front_matter = {
        'layout'             => 'character',
        'name'               => character_data['name'],
        'slug'               => slug,
        'description'        => character_data['description'],
        'personality_traits' => character_data['personality_traits'] || [],
        'programming_skills' => character_data['programming_skills'],
        'first_appearance'   => character_data['first_appearance'],
        'permalink'          => permalink,
        'created_date'       => Date.today.to_s,
        'lang'               => 'en'
      }

      body_lines = []
      body_lines << "## About #{character_data['name']}"
      body_lines << ''
      body_lines << character_data['description'].to_s
      body_lines << ''

      if character_data['backstory']
        body_lines << '## Backstory'
        body_lines << ''
        body_lines << character_data['backstory']
        body_lines << ''
      end

      if character_data['quirks']
        body_lines << '## Notable Quirks'
        body_lines << ''
        body_lines << character_data['quirks']
        body_lines << ''
      end

      if character_data['catchphrase']
        body_lines << '## Catchphrase'
        body_lines << ''
        body_lines << "> \"#{character_data['catchphrase']}\""
        body_lines << ''
      end

      body_lines << '## Appearances'
      body_lines << ''
      body_lines << "First appeared in: #{character_data['first_appearance'] || 'To be determined'}"
      body_lines << ''
      body_lines << '<!-- Chapter appearances will be tracked automatically -->'

      write_file(filename, front_matter, body_lines.join("\n"))
    end

    # ---------------------- UPDATE HELPERS ----------------------------

    # Replace the markdown BODY of an existing file while keeping front-matter.
    def update_body(file_path, new_body)
      front_matter, _old_body = parse_file(file_path)
      write_file(file_path, front_matter, new_body)
    end

    # Merge keys into the existing front-matter and write a new body.
    def update_front_matter_and_body(file_path, changes, new_body)
      front_matter, _old_body = parse_file(file_path)
      front_matter.merge!(changes)
      write_file(file_path, front_matter, new_body)
    end

    # Utility that returns [front_matter_hash, body_string]
    def parse_file(path)
      content = File.exist?(path) ? File.read(path) : ''
      parts = content.split(/^---\s*$/, 3)

      if parts.length >= 3
        front = YAML.safe_load(parts[1]) || {}
        body  = parts[2].lstrip
      else
        front = {}
        body  = ''
      end

      [front, body]
    end
  end
end 
