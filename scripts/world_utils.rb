#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'book_utils'

module WorldUtils
  include BookUtils

  # Build world context hash for prompt placeholders
  # @param lang [String] Language code (default: 'en')
  # @return [Hash] World context data formatted for prompt placeholders
  def build_world_context(lang = 'en')
    world_data = load_world_data(lang)
    return default_world_context if world_data.empty?

    {
      'COMPANY_NAME' => extract_company_name(world_data),
      'OFFICE_DESCRIPTION' => extract_office_description(world_data),
      'ESTABLISHED_LOCATIONS' => format_locations(world_data),
      'INFRASTRUCTURE_DETAILS' => format_infrastructure(world_data),
      'CULTURAL_PATTERNS' => format_cultural_patterns(world_data),
      'ESTABLISHED_FACTS' => format_established_facts(world_data)
    }
  end

  # Analyze a chapter file for world consistency issues
  # @param chapter_file [String] Path to chapter file
  # @return [Hash] Analysis results with warnings and suggestions
  def analyze_chapter_consistency(chapter_file)
    return { error: "Chapter file not found: #{chapter_file}" } unless File.exist?(chapter_file)

    content = File.read(chapter_file)
    world_data = load_world_data

    # Extract content after front matter
    chapter_content = extract_chapter_content_text(content)

    analysis = {
      locations: extract_locations_from_text(chapter_content),
      infrastructure: extract_infrastructure_from_text(chapter_content),
      company_names: extract_company_names_from_text(chapter_content),
      cultural_patterns: detect_cultural_patterns(chapter_content),
      warnings: []
    }

    # Check consistency
    expected_company = world_data.dig('company', 'name') || 'HeroTech Solutions'
    analysis[:company_names].each do |company|
      unless company == expected_company
        analysis[:warnings] << "⚠️  Found '#{company}' but expected '#{expected_company}'"
      end
    end

    # Check for established cultural patterns
    expected_patterns = ['dismissed', 'underestimated', 'lucky', 'trivial']
    found_patterns = analysis[:cultural_patterns] & expected_patterns
    if found_patterns.any?
      analysis[:warnings] << "✅ Cultural patterns maintained: #{found_patterns.join(', ')}"
    end

    analysis
  end

  # Update chapter to fix world consistency issues
  # @param chapter_file [String] Path to chapter file
  # @param fixes [Hash] Hash of fixes to apply
  # @return [Boolean] Success status
  def fix_chapter_consistency(chapter_file, fixes)
    return false unless File.exist?(chapter_file)

    content = File.read(chapter_file)
    
    fixes.each do |old_value, new_value|
      content.gsub!(old_value, new_value)
    end

    File.write(chapter_file, content)
    true
  rescue StandardError => e
    puts "Error fixing chapter consistency: #{e.message}"
    false
  end

  private

  def default_world_context
    {
      'COMPANY_NAME' => 'HeroTech Solutions',
      'OFFICE_DESCRIPTION' => 'Modern tech startup office',
      'ESTABLISHED_LOCATIONS' => '- Office: Modern tech workspace',
      'INFRASTRUCTURE_DETAILS' => '- Production Environment: Critical systems',
      'CULTURAL_PATTERNS' => '- Code Review Process: Efficient development workflow',
      'ESTABLISHED_FACTS' => '- Team follows modern development practices'
    }
  end

  def extract_company_name(world_data)
    world_data.dig('company', 'name') || 'HeroTech Solutions'
  end

  def extract_office_description(world_data)
    world_data.dig('company', 'description') || 'Modern tech startup office'
  end

  def format_locations(world_data)
    locations = world_data['locations'] || {}
    location_lines = []

    locations.each do |loc_key, loc_data|
      name = loc_data['name'] || loc_key.to_s.tr('_', ' ').capitalize
      desc = loc_data['description'] || ''
      location_lines << "- #{name}: #{desc}"

      # Add nearby locations if they exist
      if loc_data['nearby_locations']
        loc_data['nearby_locations'].each do |nearby|
          nearby_name = nearby['name'] || ''
          nearby_type = nearby['type'] || ''
          location_lines << "  - #{nearby_name} (#{nearby_type})"
        end
      end
    end

    location_lines.join("\n")
  end

  def format_infrastructure(world_data)
    infrastructure = world_data['infrastructure'] || {}
    infra_lines = []

    infrastructure.each do |infra_key, infra_data|
      name = infra_data['name'] || infra_key.to_s.tr('_', ' ').capitalize
      desc = infra_data['description'] || ''
      infra_lines << "- #{name}: #{desc}"
    end

    infra_lines.join("\n")
  end

  def format_cultural_patterns(world_data)
    culture = world_data['culture'] || {}
    culture_lines = []

    culture.each do |culture_key, culture_data|
      desc = culture_data.is_a?(Hash) ? culture_data['description'] : culture_data.to_s
      culture_lines << "- #{culture_key.to_s.tr('_', ' ').capitalize}: #{desc}"
    end

    culture_lines.join("\n")
  end

  def format_established_facts(world_data)
    facts = world_data['established_facts'] || []
    facts.map { |fact| "- #{fact}" }.join("\n")
  end

  def extract_chapter_content_text(content)
    # Remove front matter
    if content.start_with?('---')
      parts = content.split('---', 3)
      parts.length >= 3 ? parts[2] : content
    else
      content
    end
  end

  def extract_locations_from_text(text)
    patterns = [
      /at ([A-Z][A-Za-z\s]+(?:Inc|Corp|Solutions|Tech|Labs))/i,
      /in the ([a-z\s]+room)/i,
      /at the ([a-z\s]+office)/i,
      /([A-Z][A-Za-z\s]+Café|[A-Z][A-Za-z\s]+Coffee)/i,
      /([A-Z][A-Za-z\s]+Gym|[A-Z][A-Za-z\s]+Fitness)/i
    ]

    locations = []
    patterns.each do |pattern|
      matches = text.scan(pattern).flatten
      locations.concat(matches)
    end

    locations.uniq
  end

  def extract_infrastructure_from_text(text)
    patterns = [
      /(legacy\s+\w+)/i,
      /(production\s+\w+)/i,
      /(\w+\s+server)/i,
      /(\w+\s+database)/i,
      /(\w+\s+system)/i
    ]

    infrastructure = []
    patterns.each do |pattern|
      matches = text.scan(pattern).flatten
      infrastructure.concat(matches)
    end

    infrastructure.uniq
  end

  def extract_company_names_from_text(text)
    pattern = /([A-Z][A-Za-z\s]+(?:Inc|Corp|Solutions|Tech|Labs))/
    text.scan(pattern).flatten.uniq
  end

  def detect_cultural_patterns(text)
    indicators = [
      'dismissed', 'underestimated', 'lucky', 'trivial', 'obvious',
      'anyone could', 'not that impressive', 'just happened'
    ]

    found_patterns = []
    indicators.each do |indicator|
      found_patterns << indicator if text.downcase.include?(indicator)
    end

    found_patterns.uniq
  end
end 
