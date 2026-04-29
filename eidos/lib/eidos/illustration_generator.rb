# frozen_string_literal: true

require 'fileutils'
require 'securerandom'
require 'base64'
require 'yaml'

module Eidos
  # Service for generating and embedding illustrations
  class IllustrationGenerator
    def initialize(llm_service, project_root:)
      @llm_service = llm_service
      @project_root = project_root
      @characters_data = load_characters_data
    end

    def generate(chapter_number, prompt, style: nil, orientation: nil, anchor_text: nil, provider: nil, model: nil, dry_run: false, alt_text: nil)
      # 1. Prepare prompt and parameters
      context_enhanced_prompt = inject_character_context(prompt)
      
      # Resolve defaults for accurate logging/dry-run
      opts = @llm_service.resolve_image_options(
        provider: provider, 
        model: model, 
        style: style, 
        orientation: orientation
      )
      
      provider = opts[:provider]
      model = opts[:model]
      style = opts[:style]
      size = opts[:size]
      orientation = opts[:orientation]
      
      full_prompt = build_prompt(context_enhanced_prompt, style)
      
      # 2. Generate image
      puts "🎨 Generating illustration for Chapter #{chapter_number}..."
      puts "   Provider: #{provider}"
      puts "   Model: #{model}"
      puts "   Prompt: #{prompt}"
      puts "   Enhanced Prompt: #{full_prompt}" if full_prompt != prompt
      puts "   Style: #{style}"
      puts "   Orientation: #{orientation || 'default'} (#{size})"
      
      if dry_run
        puts "   [Dry Run] Skipping image generation and embedding."
        return nil
      end

      b64_data = @llm_service.generate_image(full_prompt, size: size, provider: provider, model: model)
      
      # 3. Save image
      image_path = save_image(b64_data, prompt)
      puts "   Saved to: #{image_path}"
      
      # 4. Embed in chapter
      final_alt_text = resolve_alt_text(alt_text, prompt)
      embed_in_chapter(chapter_number, image_path, final_alt_text, anchor_text)
      puts "✅ Illustration added to Chapter #{chapter_number}"
      
      image_path
    end

    private

    def build_prompt(prompt, style)
      return prompt unless style
      "#{style} style. #{prompt}"
    end


    def save_image(b64_data, prompt)
      slug = generate_slug(prompt)
      hash = SecureRandom.hex(4)
      filename = "#{slug}-#{hash}.png"
      
      assets_dir = File.join(@project_root, 'assets', 'images')
      FileUtils.mkdir_p(assets_dir)
      
      file_path = File.join(assets_dir, filename)
      
      # Decode and write
      File.open(file_path, 'wb') do |f|
        f.write(Base64.decode64(b64_data))
      end
      
      # Return relative path for markdown
      "/assets/images/#{filename}"
    end

    def generate_slug(text)
      # First 6 words, downcase, remove special chars
      words = text.to_s.split(/\s+/).take(6)
      words.map { |w| w.downcase.gsub(/[^a-z0-9]/, '') }.reject(&:empty?).join('-')
    end

    def embed_in_chapter(chapter_number, image_path, alt_text, anchor_text)
      chapter_file = find_chapter_file(chapter_number)
      return unless chapter_file

      # Liquid tag for robust linking
      # {{ '/assets/images/foo.png' | relative_url }}
      # Wrap in div.illustration for better styling control
      image_markdown = "\n\n<div class=\"illustration\" markdown=\"1\">\n\n![#{alt_text}]({{ '#{image_path}' | relative_url }})\n\n</div>\n\n"

      # Calculate block index for translations BEFORE updating the main file
      anchor_block_index = find_anchor_block_index(chapter_file, anchor_text)

      # Embed in main chapter file
      update_chapter_content(chapter_file, image_markdown, anchor_text)

      # Embed in translated chapter files
      find_translated_chapter_files(chapter_number).each do |translated_file|
        puts "   Adding illustration to translation: #{File.basename(translated_file)}"
        update_translated_chapter_content(translated_file, image_markdown, anchor_block_index)
      end
    end

    def update_chapter_content(file_path, image_markdown, anchor_text)
      content = File.read(file_path)

      if anchor_text && !anchor_text.strip.empty?
        # Normalize content and anchor for matching
        normalized_content = normalize_text(content)
        normalized_anchor = normalize_text(anchor_text)

        if normalized_content.include?(normalized_anchor)
          # We need to find the *actual* text in the file to replace it, 
          # but we only have the normalized anchor.
          # Strategy: Find the paragraph index using normalized text, then insert into the original content.
          
          blocks = content.split(/\n{2,}/)
          normalized_blocks = blocks.map { |b| normalize_text(b) }
          
          target_index = normalized_blocks.find_index { |nb| nb.include?(normalized_anchor) }
          
          if target_index
            blocks[target_index] = "#{blocks[target_index]}#{image_markdown}"
            content = blocks.join("\n\n")
          else
             # Fallback if block splitting differs slightly (shouldn't happen if logic matches)
             puts "⚠️  Anchor found in normalized text but block matching failed. Appending to end."
             content += image_markdown
          end
        else
          puts "⚠️  Anchor text '#{anchor_text}' not found in #{File.basename(file_path)}. Appending to end."
          content += image_markdown
        end
      else
        content += image_markdown
      end

      File.write(file_path, content)
    end

    def update_translated_chapter_content(file_path, image_markdown, block_index)
      content = File.read(file_path)
      blocks = content.split(/\n{2,}/)
      
      if block_index && block_index < blocks.length
        # Insert after the block at block_index
        blocks[block_index] = "#{blocks[block_index]}#{image_markdown}"
        new_content = blocks.join("\n\n")
        File.write(file_path, new_content)
      else
        puts "⚠️  Could not find corresponding location in #{File.basename(file_path)}. Appending to end."
        File.write(file_path, "#{content}#{image_markdown}")
      end
    end

    def find_anchor_block_index(chapter_file, anchor_text)
      return nil unless anchor_text && !anchor_text.strip.empty?

      content = File.read(chapter_file)
      # Split by 2 or more newlines to handle various spacing
      blocks = content.split(/\n{2,}/)
      
      normalized_anchor = normalize_text(anchor_text)

      blocks.each_with_index do |block, index|
        # Normalize block content for comparison
        normalized_block = normalize_text(block)
        return index if normalized_block.include?(normalized_anchor)
      end
      
      nil
    end

    def find_translated_chapter_files(chapter_number)
      # Pad number to 3 digits
      padded_num = chapter_number.to_i.to_s.rjust(3, '0')
      chapters_dir = File.join(@project_root, 'content', 'chapters')
      
      # Find files like 001-chapter.ru.md, but NOT the main 001-chapter.md
      Dir.glob(File.join(chapters_dir, "#{padded_num}-chapter.*.md"))
    end

    def find_chapter_file(chapter_number)
      # Pad number to 3 digits to match the chapter filename convention
      padded_num = chapter_number.to_i.to_s.rjust(3, '0')
      chapters_dir = File.join(@project_root, 'content', 'chapters')
      
      # Find file starting with number
      Dir.glob(File.join(chapters_dir, "#{padded_num}-*.md")).first
    end

    def load_characters_data
      path = File.join(@project_root, 'data', 'characters.yml')
      return {} unless File.exist?(path)

      data = YAML.load_file(path)
      # Handle both structure formats (direct list or nested under 'en')
      data['en'] ? data['en']['characters'] : (data['characters'] || {})
    rescue StandardError => e
      puts "⚠️  Warning: Failed to load characters data: #{e.message}"
      {}
    end

    def inject_character_context(prompt)
      return prompt if @characters_data.empty?

      mentioned_characters = []
      @characters_data.each do |slug, char_info|
        name = char_info['name']
        next unless name

        # Check full name or first name
        first_name = name.split.first
        
        if prompt.downcase.include?(name.downcase) || (first_name && prompt.downcase.include?(first_name.downcase))
          description = char_info['description']
          physical = char_info['physical_appearance']
          
          char_desc = "#{name}: #{description}"
          
          if physical
            details = []
            details << "Age: #{physical['age']}" if physical['age']
            details << "Skin: #{physical['skin_tone']}" if physical['skin_tone']
            details << "Hair: #{physical['hair']}" if physical['hair']
            details << "Eyes: #{physical['eyes']}" if physical['eyes']
            details << "Outfit: #{physical['outfit']}" if physical['outfit']
            details << "Features: #{physical['distinguishing_features']}" if physical['distinguishing_features']
            
            char_desc += " [Appearance: #{details.join(', ')}]" unless details.empty?
          end
          
          mentioned_characters << char_desc if description
        end
      end

      return prompt if mentioned_characters.empty?

      "#{prompt} (Context: #{mentioned_characters.join('; ')})"
    end

    def normalize_text(text)
      # Fuzzy normalization:
      # 1. Downcase
      # 2. Replace smart quotes with straight quotes (just in case)
      # 3. Remove all non-alphanumeric characters (punctuation, whitespace)
      text.to_s
          .downcase
          .gsub(/[“”]/, '"')
          .gsub(/[‘’]/, "'")
          .gsub(/[^a-z0-9]/, '')
    end

    def resolve_alt_text(alt_text, prompt)
      return alt_text if alt_text && !alt_text.strip.empty?

      # If no alt text provided, summarize the prompt using LLM
      puts "   Generating alt text summary..."
      begin
        summary = @llm_service.summarize_text(prompt)
        puts "   Alt text: #{summary}"
        summary
      rescue StandardError => e
        puts "⚠️  Failed to generate alt text summary: #{e.message}"
        # Fallback to truncated prompt
        prompt.split[0..10].join(' ') + '...'
      end
    end
  end
end
