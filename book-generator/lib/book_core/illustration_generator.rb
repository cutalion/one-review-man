# frozen_string_literal: true

require 'openai'
require 'down'
require 'fileutils'
require 'securerandom'
require 'book_core/book_config'

module BookCore
  class IllustrationGenerator
    def initialize(client: nil, project_root: nil, config: nil)
      @client = client || OpenAI::Client.new
      @project_root = project_root || Dir.pwd
      @config = config || BookCore::BookConfig.load_from_project(@project_root)
    end

    def generate(prompt:, chapter_number:, anchor_text: nil)
      # 1. Generate image
      model = @config.get('llm.task_options.illustration.model') || @config.get('llm.model') || 'dall-e-3'
      puts "Generating illustration with prompt: #{prompt} using model #{model}"
      response = @client.images.generate(parameters: { model: model, prompt: prompt, size: '1024x1024' })
      image_url = response.dig('data', 0, 'url')
      image_data = Down.download(image_url)
      puts "Illustration downloaded from #{image_url}"

      # 2. Determine paths
      image_filename = "#{SecureRandom.hex(8)}.png"
      image_dir = File.join(@project_root, 'assets', 'images', "chapter_#{chapter_number}")
      FileUtils.mkdir_p(image_dir)
      image_path = File.join(image_dir, image_filename)

      # 3. Save image
      File.open(image_path, 'wb') do |file|
        file.write(image_data.read)
      end
      puts "Illustration saved to #{image_path}"

      # 4. Prepare markdown tag
      illustration_tag = "![[illustration:#{image_filename}]]"

      if anchor_text
        # 5. Embed if anchor_text is provided
        chapter_filename = "#{format('%03d', chapter_number.to_i)}-chapter.md"
        chapter_path = File.join(preferred_chapters_dir, chapter_filename)

        unless File.exist?(chapter_path)
          puts "Error: Chapter file not found at #{chapter_path}"
          puts "You can manually insert the following tag into your chapter:"
          puts illustration_tag
          return
        end

        content = File.read(chapter_path)
        if content.include?(anchor_text)
          new_content = content.sub(anchor_text, "#{anchor_text}\n\n#{illustration_tag}")
          File.write(chapter_path, new_content)
          puts "Illustration embedded in chapter #{chapter_number}."
        else
          puts "Anchor text '#{anchor_text}' not found in chapter. Illustration not embedded."
          puts "You can manually insert the following tag into your chapter:"
          puts illustration_tag
        end
      else
        # 6. Otherwise, print the tag
        puts "Illustration generated successfully. To embed it in your chapter, use the following tag:"
        puts illustration_tag
      end
    end

    private

    def preferred_chapters_dir
      content_dir = File.join(@project_root, 'content', 'chapters')
      return content_dir if Dir.exist?(content_dir)

      legacy_dir = File.join(@project_root, '_chapters')
      return legacy_dir if Dir.exist?(legacy_dir)

      content_dir
    end
  end
end
