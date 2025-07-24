# frozen_string_literal: true

require 'fileutils'

module Book
  class JekyllHelper
    def self.clean_generated_site
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
  end
end
