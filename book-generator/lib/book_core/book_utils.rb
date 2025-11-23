# frozen_string_literal: true

require 'yaml'
require 'book_core/validation_utils'
require 'fileutils'

# Common utilities and constants for book project management
module BookUtils
  DATA_DIR = 'data'
  CHAPTERS_DIR = '_chapters'
  CHARACTERS_DIR = '_characters'

  # Data file loading methods - support both simple and language-specific patterns
  def load_book_data(lang = nil)
    file_path = File.join(DATA_DIR, 'book_metadata.yml')
    data = load_yaml_file(file_path)

    if lang && data['localized'] && data['localized'][lang]
      # Return merged structure: shared data + localized content
      shared_data = data.reject { |k| k == 'localized' }
      localized_data = data['localized'][lang]
      shared_data.merge('localized_content' => localized_data)
    elsif lang.nil? && data['localized'] && data['localized']['en']
      # Default to English for generation scripts - merge shared + English
      shared_data = data.reject { |k| k == 'localized' }
      localized_data = data['localized']['en']
      shared_data.merge('localized_content' => localized_data)
    elsif lang.nil? && data['en']
      # Legacy single-language format with 'en' key
      data['en']
    elsif lang.nil?
      # Legacy single-language format or new format without localized content
      data.key?('localized') ? data.reject { |k| k == 'localized' } : data
    else
      # Language not found, return empty structure
      {
        'book' => {},
        'generation' => {},
        'themes' => {},
        'status' => {}
      }
    end
  end

  def load_characters(lang = nil)
    file_path = File.join(DATA_DIR, 'characters.yml')
    data = load_yaml_file(file_path) || { 'characters' => {} }

    if lang && data[lang]
      # Language-specific data
      data[lang]
    elsif lang.nil? && data['en']
      # Default to English for generation scripts
      data['en']
    elsif lang.nil?
      # Legacy single-language format or simple case
      data['characters'] ? data : { 'characters' => data }
    else
      # Language not found, return empty structure
      { 'characters' => {} }
    end
  end

  def load_generation_log
    file_path = File.join(DATA_DIR, 'generation_log.yml')
    load_yaml_file(file_path)
  end

  def load_strings(lang = 'en')
    file_path = File.join(DATA_DIR, 'strings.yml')
    data = load_yaml_file(file_path) || {}
    data[lang] || data['en'] || {}
  end

  def load_world_data(lang = 'en')
    file_path = File.join(DATA_DIR, 'world.yml')
    data = load_yaml_file(file_path) || {}

    if lang && data[lang] && data[lang]['world']
      data[lang]['world']
    elsif data['en'] && data['en']['world']
      data['en']['world']
    else
      {}
    end
  end

  # File operation helpers
  # Centralised YAML loading – delegates to Book::Config so that all YAML
  # access points go through a single helper.  Behaviour is identical (returns
  # an empty Hash for missing files).
  def load_yaml_file(file_path)
    # Always use the new core implementation
    unless defined?(BookCore::Config)
      core_lib = File.expand_path('../../../../book-generator/lib', __dir__)
      $LOAD_PATH.unshift(core_lib) unless $LOAD_PATH.include?(core_lib)
      require 'book_core/config'
    end

    BookCore::Config.load_yaml(file_path)
  end

  # Content helpers
  def get_all_chapters(lang = nil)
    return [] unless Dir.exist?(CHAPTERS_DIR)

    # Filter chapters based on language
    pattern = if lang && lang != 'en'
                "#{CHAPTERS_DIR}/*.#{lang}.md"
              else
                # For English or no language specified, get base chapters (no language suffix)
                "#{CHAPTERS_DIR}/*.md"
              end

    files = Dir.glob(pattern).reject do |file|
      # Skip files with language suffixes when looking for English/base chapters
      lang.nil? && File.basename(file, '.md').include?('.')
    end

    chapters = files.map do |file|
      parse_chapter_file(file)
    end

    chapters.sort_by { |chapter| chapter['chapter_number'] || 0 }
  end

  def parse_character_file(file_path)
    content = File.read(file_path)
    match = content.match(/\A---\s*\n(.*?)\n---\s*\n(.*)/m)

    if match
      front_matter = YAML.safe_load(match[1]) || {}
      content_text = match[2]

      front_matter.merge({
                           'content' => content_text,
                           'file_path' => file_path
                         })
    else
      {
        'name' => File.basename(file_path, '.md').gsub('_', ' '),
        'content' => content,
        'file_path' => file_path
      }
    end
  rescue StandardError => e
    puts "Error parsing #{file_path}: #{e.message}"
    { 'file_path' => file_path, 'name' => File.basename(file_path, '.md').gsub('_', ' ') }
  end

  private

  def parse_chapter_file(file_path)
    content = File.read(file_path)
    match = content.match(/\A---\s*\n(.*?)\n---\s*\n(.*)/m)

    if match
      front_matter = YAML.safe_load(match[1]) || {}
      content_text = match[2]

      front_matter.merge({
                           'content' => content_text,
                           'file_path' => file_path
                         })
    else
      {
        'title' => File.basename(file_path, '.md'),
        'content' => content,
        'file_path' => file_path
      }
    end
  rescue StandardError => e
    puts "Error parsing #{file_path}: #{e.message}"
    { 'file_path' => file_path, 'title' => File.basename(file_path, '.md') }
  end

  def format_chapter_filename(chapter_number)
    "#{chapter_number.to_s.rjust(3, '0')}-chapter.md"
  end
end
