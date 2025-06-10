#!/usr/bin/env ruby
# frozen_string_literal: true

require 'slop'
require_relative 'book_utils'
require_relative 'world_utils'

class WorldConsistencyAnalyzer
  include BookUtils
  include WorldUtils

  def initialize
    @world_data = load_world_data
  end

  def analyze_chapter(chapter_file)
    unless File.exist?(chapter_file)
      puts "❌ Chapter file not found: #{chapter_file}"
      return false
    end

    puts "🔍 Analyzing world consistency for: #{chapter_file}"
    puts '=' * 50

    analysis = analyze_chapter_consistency(chapter_file)

    if analysis[:error]
      puts "❌ Error: #{analysis[:error]}"
      return false
    end

    # Display analysis results
    display_analysis_results(analysis)

    # Return true if no warnings, false if issues found
    analysis[:warnings].none? { |w| w.start_with?('⚠️') }
  end

  def analyze_all_chapters
    chapters = get_all_chapters
    issues_found = false

    puts "🔍 Analyzing world consistency for all chapters..."
    puts '=' * 60

    chapters.each do |chapter_data|
      chapter_file = "_chapters/#{format_chapter_filename(chapter_data['chapter_number'])}"
      next unless File.exist?(chapter_file)

      puts "\n📖 Chapter #{chapter_data['chapter_number']}: #{chapter_data['title']}"
      puts '-' * 40

      analysis = analyze_chapter_consistency(chapter_file)
      
      if analysis[:error]
        puts "❌ Error: #{analysis[:error]}"
        issues_found = true
        next
      end

      display_analysis_results(analysis, compact: true)

      # Check for issues
      has_warnings = analysis[:warnings].any? { |w| w.start_with?('⚠️') }
      issues_found = true if has_warnings
    end

    puts "\n" + '=' * 60
    if issues_found
      puts "⚠️  World consistency issues found. Review the warnings above."
    else
      puts "✅ All chapters are world-consistent!"
    end

    !issues_found
  end

  def fix_chapter_consistency(chapter_file, fixes_hash)
    unless File.exist?(chapter_file)
      puts "❌ Chapter file not found: #{chapter_file}"
      return false
    end

    puts "🔧 Fixing world consistency issues in: #{chapter_file}"

    if fix_chapter_consistency(chapter_file, fixes_hash)
      puts "✅ Chapter consistency fixes applied successfully!"
      
      # Re-analyze to confirm fixes
      puts "\n🔍 Re-analyzing to confirm fixes..."
      analyze_chapter(chapter_file)
    else
      puts "❌ Failed to apply consistency fixes"
      false
    end
  end

  def show_world_summary
    puts "🌍 World Consistency Summary"
    puts '=' * 50

    company_name = @world_data.dig('company', 'name') || 'Not defined'
    puts "Company: #{company_name}"

    office_desc = @world_data.dig('company', 'description') || 'Not defined'
    puts "Setting: #{office_desc}"

    puts "\nEstablished Locations:"
    locations = @world_data['locations'] || {}
    if locations.empty?
      puts "  (No locations defined)"
    else
      locations.each do |loc_key, loc_data|
        name = loc_data['name'] || loc_key.to_s.tr('_', ' ').capitalize
        puts "  - #{name}: #{loc_data['description']}"
      end
    end

    puts "\nInfrastructure:"
    infrastructure = @world_data['infrastructure'] || {}
    if infrastructure.empty?
      puts "  (No infrastructure defined)"
    else
      infrastructure.each do |infra_key, infra_data|
        name = infra_data['name'] || infra_key.to_s.tr('_', ' ').capitalize
        puts "  - #{name}: #{infra_data['description']}"
      end
    end

    puts "\nEstablished Facts:"
    facts = @world_data['established_facts'] || []
    if facts.empty?
      puts "  (No facts defined)"
    else
      facts.each { |fact| puts "  - #{fact}" }
    end
  end

  private

  def display_analysis_results(analysis, compact: false)
    # Company names
    if analysis[:company_names].any?
      puts "🏢 Company names found:" unless compact
      analysis[:company_names].each do |company|
        expected = @world_data.dig('company', 'name') || 'HeroTech Solutions'
        if company == expected
          puts "  ✅ #{company}" unless compact
        else
          puts "  ⚠️  #{company} (should be '#{expected}')"
        end
      end
    end

    # Locations
    if analysis[:locations].any? && !compact
      puts "\n📍 Locations mentioned:"
      analysis[:locations].each { |loc| puts "  - #{loc}" }
    end

    # Infrastructure
    if analysis[:infrastructure].any? && !compact
      puts "\n🔧 Infrastructure mentioned:"
      analysis[:infrastructure].each { |infra| puts "  - #{infra}" }
    end

    # Cultural patterns
    if analysis[:cultural_patterns].any? && !compact
      puts "\n🎭 Cultural patterns detected:"
      analysis[:cultural_patterns].each { |pattern| puts "  - #{pattern}" }
    end

    # Warnings
    if analysis[:warnings].any?
      puts "\n⚠️  Issues:" if analysis[:warnings].any? { |w| w.start_with?('⚠️') }
      puts "\n✅ Consistency:" if analysis[:warnings].any? { |w| w.start_with?('✅') }
      analysis[:warnings].each { |warning| puts "#{warning}" }
    elsif !compact
      puts "\n✅ No consistency issues found!"
    end
  end
end

# CLI Interface
def main
  opts = Slop.parse do |o|
    o.banner = 'Usage: ruby analyze_world_consistency.rb [options]'
    o.string '-c', '--chapter', 'Analyze specific chapter file'
    o.bool '-a', '--all', 'Analyze all chapters'
    o.bool '-s', '--summary', 'Show world summary'
    o.bool '-h', '--help', 'Show this help message'
  end

  if opts.help?
    puts opts
    return
  end

  analyzer = WorldConsistencyAnalyzer.new

  if opts[:summary]
    analyzer.show_world_summary
  elsif opts[:chapter]
    analyzer.analyze_chapter(opts[:chapter])
  elsif opts[:all]
    analyzer.analyze_all_chapters
  else
    puts "Please specify an action. Use --help for options."
    puts "\nExamples:"
    puts "  ruby analyze_world_consistency.rb --summary"
    puts "  ruby analyze_world_consistency.rb --chapter _chapters/003-chapter.md"
    puts "  ruby analyze_world_consistency.rb --all"
  end
end

if __FILE__ == $PROGRAM_NAME
  main
end 
