# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module BookUtils
  DATA_DIR = '_data'
  CHAPTERS_DIR = '_chapters'
  CHARACTERS_DIR = '_characters'

  # Data file loading methods - support both simple and language-specific patterns
  def load_book_data(lang = nil)
    file_path = File.join(DATA_DIR, 'book_metadata.yml')
    data = load_yaml_file(file_path)
    
    if lang && data[lang]
      # Language-specific data
      data[lang]
    elsif lang.nil? && data['en']
      # Default to English for generation scripts
      data['en']
    elsif lang.nil?
      # Legacy single-language format
      data
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

  # Data file saving methods - support both simple and language-specific patterns
  def save_book_data(data, lang = nil)
    file_path = File.join(DATA_DIR, 'book_metadata.yml')
    
    if lang
      # Save to language-specific section
      existing_data = load_yaml_file(file_path) || {}
      existing_data[lang] = data
      save_yaml_file(file_path, existing_data)
    else
      # For generation scripts, assume English and maintain language structure
      existing_data = load_yaml_file(file_path) || {}
      existing_data['en'] = data
      save_yaml_file(file_path, existing_data)
    end
  end

  def save_characters(data, lang = nil)
    file_path = File.join(DATA_DIR, 'characters.yml')
    
    if lang
      # Save to language-specific section
      existing_data = load_yaml_file(file_path) || {}
      existing_data[lang] = data
      save_yaml_file(file_path, existing_data)
    else
      # For generation scripts, assume English and maintain language structure
      existing_data = load_yaml_file(file_path) || {}
      existing_data['en'] = data
      save_yaml_file(file_path, existing_data)
    end
  end

  def save_generation_log(data)
    file_path = File.join(DATA_DIR, 'generation_log.yml')
    save_yaml_file(file_path, data)
  end

  # File operation helpers
  def load_yaml_file(file_path)
    if File.exist?(file_path)
      YAML.load_file(file_path) || {}
    else
      puts "Warning: #{file_path} not found, returning empty hash"
      {}
    end
  end

  def save_yaml_file(file_path, data)
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, data.to_yaml)
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

    chapters = Dir.glob(pattern).reject do |file|
      # Skip files with language suffixes when looking for English/base chapters
      lang.nil? && File.basename(file, '.md').include?('.')
    end.map do |file|
      parse_chapter_file(file)
    end

    chapters.sort_by { |chapter| chapter['chapter_number'] || 0 }
  end

  def get_all_character_slugs(lang = nil)
    characters = load_characters(lang)
    characters['characters']&.keys || []
  end

  def get_characters_by_slugs(slugs, lang = nil)
    characters = load_characters(lang)
    return [] if characters.empty? || !characters['characters']

    slugs.filter_map { |slug| characters['characters'][slug] }
  end

  # Generation helpers
  def log_generation(type, content_id, details = {})
    log = load_generation_log
    log['generations'] ||= []

    generation_entry = {
      'date' => Date.today.to_s,
      'type' => type,
      'content_id' => content_id
    }.merge(details)

    log['generations'] << generation_entry
    save_generation_log(log)
  end

  def get_used_plot_devices
    log = load_generation_log
    log['used_plot_devices'] || []
  end

  def add_used_plot_device(device)
    log = load_generation_log
    log['used_plot_devices'] ||= []

    return if log['used_plot_devices'].include?(device)

    log['used_plot_devices'] << device
    save_generation_log(log)
  end

  # Character relationship helpers
  def update_character_interaction(char1_slug, char2_slug, interaction_type)
    log = load_generation_log
    log['character_interactions'] ||= {}

    key = [char1_slug, char2_slug].sort.join('_')
    log['character_interactions'][key] ||= []
    log['character_interactions'][key] << {
      'type' => interaction_type,
      'date' => Date.today.to_s
    }

    save_generation_log(log)
  end

  def get_character_interactions(char_slug)
    log = load_generation_log
    interactions = log['character_interactions'] || {}

    interactions.select do |key, _|
      key.split('_').include?(char_slug)
    end
  end

  # Validation helpers
  def validate_chapter_structure(chapter_data)
    required_fields = %w[title chapter_number]
    missing_fields = required_fields.select { |field| chapter_data[field].nil? }

    if missing_fields.any?
      puts "Warning: Chapter missing required fields: #{missing_fields.join(', ')}"
      return false
    end

    true
  end

  def validate_character_structure(character_data)
    required_fields = %w[name description]
    missing_fields = required_fields.select { |field| character_data[field].nil? || character_data[field].empty? }

    if missing_fields.any?
      puts "Warning: Character missing required fields: #{missing_fields.join(', ')}"
      return false
    end

    true
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

  def slugify(text)
    text.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_|_$/, '')
  end

  def format_chapter_filename(chapter_number)
    "#{chapter_number.to_s.rjust(3, '0')}-chapter.md"
  end

  def extract_chapter_content(file_path)
    return '' unless File.exist?(file_path)

    content = File.read(file_path)
    match = content.match(/\A---\s*\n.*?\n---\s*\n(.*)/m)

    match ? match[1].strip : content.strip
  end

  def update_chapter_content(file_path, new_content)
    return false unless File.exist?(file_path)

    content = File.read(file_path)
    match = content.match(/(\A---\s*\n.*?\n---\s*\n)(.*)/m)

    if match
      updated_content = match[1] + new_content
      File.write(file_path, updated_content)
      true
    else
      File.write(file_path, new_content)
      true
    end
  end

  def update_chapter_front_matter(file_path, updates)
    return false unless File.exist?(file_path)

    content = File.read(file_path)
    match = content.match(/\A(---\s*\n)(.*?)(\n---\s*\n)(.*)/m)

    if match
      front_matter = YAML.safe_load(match[2]) || {}
      front_matter.merge!(updates)

      updated_content = match[1] + front_matter.to_yaml + match[3] + match[4]
      File.write(file_path, updated_content)
      true
    else
      false
    end
  end

  def create_character_page(slug, character_data)
    filename = "_characters/#{slug}.md"

    front_matter = {
      'layout' => 'character',
      'name' => character_data['name'],
      'slug' => slug,
      'description' => character_data['description'],
      'personality_traits' => character_data['personality_traits'] || [],
      'first_appearance' => character_data['first_appearance'],
      'relationships' => character_data['relationships'] || []
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
    end
  end

  def update_character_page(slug)
    characters = load_characters
    character = characters['characters'][slug]
    return false unless character

    create_character_page(slug, character)
    true
  end

  def build_character_description_text(character)
    text = "Name: #{character['name']}\n"
    text += "Description: #{character['description']}\n"
    text += "Personality Traits: #{character['personality_traits']&.join(', ')}\n" if character['personality_traits']
    text += "Backstory: #{character['backstory']}\n" if character['backstory']
    text += "Quirks: #{character['quirks']}\n" if character['quirks']
    text += "Catchphrase: #{character['catchphrase']}\n" if character['catchphrase']
    text
  end

  def parse_character_improvements(improved_text)
    # Parse improved character text back into structured data
    improvements = {}

    if improved_text.match(/Description:\s*(.+?)(?=\n[A-Z]|\z)/m)
      improvements['description'] = $1.strip
    end

    if improved_text.match(/Backstory:\s*(.+?)(?=\n[A-Z]|\z)/m)
      improvements['backstory'] = $1.strip
    end

    if improved_text.match(/Quirks:\s*(.+?)(?=\n[A-Z]|\z)/m)
      improvements['quirks'] = $1.strip
    end

    if improved_text.match(/Catchphrase:\s*(.+?)(?=\n[A-Z]|\z)/m)
      improvements['catchphrase'] = $1.strip
    end

    improvements
  end
end
