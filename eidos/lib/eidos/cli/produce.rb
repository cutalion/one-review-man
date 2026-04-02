# frozen_string_literal: true

require 'thor'
require 'eidos/cli/helpers'

module Eidos
  module CLI
    # CLI commands for content production (chapters, comics, illustrations, agent writing)
    class Produce < Thor
      include Helpers

      class_option 'world-dir', aliases: ['-w'], type: :string,
                                desc: 'Path to the world directory (defaults to current directory)'
      class_option 'content-model', type: :string,
                                    desc: 'Specify the model to use for generation (defaults to settings.yml)'
      class_option :auto, type: :boolean, default: false, desc: 'Auto mode: skip interactive prompts'
      class_option :debug, type: :boolean, default: false, desc: 'Enable verbose LLM debug logging'

      desc 'chapter [NUMBER]', 'Generate the next chapter'
      method_option :snapshot, type: :string, desc: 'Pin generation to a specific canon snapshot'
      method_option :output, type: :string, desc: 'Output directory for generated artifacts'
      def chapter(_number = nil)
        abs_root = resolve_project_root!(options['world-dir'])

        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]

          require 'eidos/producers/chapter_producer'
          producer = Eidos::Producers::ChapterProducer.new(project_root: abs_root)
          result = producer.produce(
            snapshot: options[:snapshot],
            config: {
              auto_generate: options[:auto],
              model: options['content-model']
            },
            output: options[:output]
          )

          unless result.success?
            puts "Error: #{result.error}"
            exit 1
          end
        end
      end

      desc 'comic', 'Generate comic panels for a chapter'
      method_option :chapter, type: :numeric, required: true, desc: 'Chapter number to generate panels from'
      method_option :panels, type: :numeric, default: 4, desc: 'Number of panels to generate (default: 4)'
      method_option :style, type: :string, default: 'manga',
                            desc: 'Art style (e.g., manga, western comic, pixel art)'
      method_option :format, type: :string, default: 'square',
                            desc: 'Image format: square (1080x1080) or portrait (1080x1350)'
      method_option :snapshot, type: :string, desc: 'Pin generation to a specific canon snapshot'
      method_option :output, type: :string, desc: 'Output directory for generated panels'
      method_option 'describe-only', type: :boolean, default: false,
                                     desc: 'Generate panel descriptions only (no images)'
      def comic
        abs_root = resolve_project_root!(options['world-dir'])

        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]

          require 'eidos/producers/instagram_comic_producer'
          producer = Eidos::Producers::InstagramComicProducer.new(project_root: abs_root)
          result = producer.produce(
            snapshot: options[:snapshot],
            config: {
              source: { type: 'chapter', number: options[:chapter] },
              panel_count: options[:panels],
              art_style: options[:style],
              image_format: options[:format],
              description_only: options['describe-only']
            },
            output: options[:output]
          )

          if result.success?
            puts "Comic panels generated at #{result.output_path}"
            puts "Artifacts: #{result.artifacts.length} files"
            result.artifacts.each { |a| puts "  #{a}" }
          else
            puts "Error: #{result.error}"
            exit 1
          end
        end
      end

      desc 'illustration', 'Generate an illustration for a chapter using line numbers'
      method_option :chapter, type: :numeric, required: true, desc: 'Chapter number'
      method_option :content, type: :string, required: true,
                              desc: 'Line range for content (e.g., "10:17")'
      method_option :anchor, type: :numeric,
                             desc: 'Line number to anchor illustration (defaults to first line of content)'
      method_option :prompt, type: :string,
                             desc: 'Additional prompt text to augment the extracted content'
      method_option 'alt-text', type: :string,
                                desc: 'Alt text for the image (defaults to LLM summary of prompt)'
      method_option :style, type: :string,
                            desc: 'Style of the illustration (defaults to settings.yml)'
      method_option :orientation, type: :string,
                                  desc: 'Orientation: landscape, portrait, square (defaults to settings.yml)'
      method_option :provider, type: :string,
                               desc: 'Image provider: openai, openrouter (defaults to settings.yml)'
      method_option 'content-model', type: :string, desc: 'Model name (defaults to settings.yml)'
      method_option 'summarization-model', type: :string,
                                           desc: 'Model to use for alt text summarization'
      method_option 'dry-run', type: :boolean, default: false,
                               desc: 'Dry run: print parameters without generating'
      method_option :snapshot, type: :string, desc: 'Pin generation to a specific canon snapshot'
      def illustration
        abs_root = resolve_project_root!(options['world-dir'])

        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]

          chapter_number = options[:chapter]
          content_range = options[:content]

          # Parse content range (e.g., "10:17")
          unless content_range.match?(/^\d+:\d+$/)
            say "Error: --content must be in format 'START:END' (e.g., '10:17')", :red
            exit 1
          end

          start_line, end_line = content_range.split(':').map(&:to_i)

          # Read chapter file and extract content
          chapter_file = File.join(abs_root, 'content', 'chapters',
                                   format('%03d-chapter.md', chapter_number))
          unless File.exist?(chapter_file)
            say "Error: Chapter file not found: #{chapter_file}", :red
            exit 1
          end

          chapter_lines = File.readlines(chapter_file)

          # Validate line numbers
          if start_line < 1 || end_line > chapter_lines.length || start_line > end_line
            say "Error: Invalid line range #{content_range}. Chapter has #{chapter_lines.length} lines.", :red
            exit 1
          end

          # Extract content (lines are 1-indexed)
          content_lines = chapter_lines[(start_line - 1)..(end_line - 1)]
          extracted_content = content_lines.join.strip

          # Build prompt from extracted content and optional additional prompt
          illustration_prompt = extracted_content
          illustration_prompt += "\n\n#{options[:prompt]}" if options[:prompt]

          # Determine anchor line
          anchor_line = options[:anchor] || start_line
          if anchor_line < start_line || anchor_line > end_line
            say "Warning: Anchor line #{anchor_line} is outside content range #{content_range}", :yellow
          end

          # Extract anchor text (single line)
          anchor_text = anchor_line.positive? && anchor_line <= chapter_lines.length ? chapter_lines[anchor_line - 1].strip : nil

          # Load settings to get defaults
          require 'eidos/configuration'
          config = Eidos::Configuration.load(abs_root, options)

          # Three-tier override precedence: CLI > ENV > Settings > Defaults (handled in LLMService)
          provider = options[:provider] || ENV['ILLUSTRATION_PROVIDER']
          model = options['content-model'] || ENV['ILLUSTRATION_MODEL']
          style = options[:style]
          orientation = options[:orientation]

          # Initialize LLM service with config
          require 'eidos/llm_service'
          llm_service = Eidos::LLMService.new(config)

          # Generate illustration with provider and model options
          require 'eidos/illustration_generator'
          generator = Eidos::IllustrationGenerator.new(llm_service, project_root: abs_root)
          generator.generate(
            chapter_number,
            illustration_prompt,
            style: style,
            orientation: orientation,
            anchor_text: anchor_text,
            provider: provider,
            model: model,
            dry_run: options['dry-run'],
            alt_text: options['alt-text']
          )
        end
      end

      desc 'prompt [CHAPTER_NUMBER]', 'Show the generation prompt'
      def prompt(number = nil)
        project_root = resolve_project_root(options['world-dir'])
        unless project_root
          puts 'prompt stub for chapter'
          return
        end

        abs_root = File.expand_path(project_root)

        # Load configuration with CLI overrides
        require 'eidos/configuration'
        config = Eidos::Configuration.load(abs_root, options)

        Dir.chdir(abs_root) do
          require 'eidos/chapter_generator'
          generator = Eidos::ChapterGenerator.new(configuration: config, project_root: abs_root)
          chapter_number = number ? number.to_i : generator.send(:determine_next_chapter_number)
          built_prompt = generator.send(:build_chapter_prompt, chapter_number)
          puts built_prompt
        end
      end

      desc 'write [CHAPTER]', 'Agent-based chapter writing (experimental)'
      option :requirements, type: :string, aliases: '-r', desc: 'Additional requirements for the chapter'
      option :dry_run, type: :boolean, default: false, desc: 'Show what would be generated without writing'
      option :force, type: :boolean, default: false, desc: 'Force overwrite if chapter exists'
      def write(chapter = nil)
        abs_root = resolve_project_root!(options['world-dir'])

        # Determine chapter number using max(files, state) + 1 (same as ChapterGenerator)
        chapter_number = if chapter
                           chapter.to_i
                         else
                           determine_next_chapter_number(abs_root)
                         end

        # Check if chapter file already exists (unless --force)
        chapters_dir = File.join(abs_root, 'content', 'chapters')
        chapter_file = File.join(chapters_dir, format('%03d-chapter.md', chapter_number))

        if File.exist?(chapter_file) && !options[:force]
          say "Chapter #{chapter_number} already exists at #{chapter_file}", :yellow
          say '   Use --force to overwrite, or specify a different chapter number.', :yellow
          say "   Next available: #{determine_next_chapter_number(abs_root)}", :cyan
          return
        end

        say "Agent-Writer: Generating Chapter #{chapter_number}...", :cyan

        require 'eidos/writer_agent'
        say "   Model: #{Eidos::WriterAgent::DEFAULT_MODEL}", :blue

        # Initialize services
        require 'eidos/configuration'
        require 'eidos/llm_service'
        require 'eidos/story_bible'
        config = Eidos::Configuration.load(abs_root, {})
        llm_service = Eidos::LLMService.new(config)
        story_bible = Eidos::StoryBible.new(project_root: abs_root)

        # Create agent
        agent = Eidos::WriterAgent.new(
          llm_service: llm_service,
          story_bible: story_bible,
          project_root: abs_root,
          debug: options[:debug]
        )

        if options[:dry_run]
          say "\n[Dry Run] Would generate chapter using these tools:", :yellow
          require 'eidos/agent_tools/story_bible_tools'
          Eidos::AgentTools::StoryBibleTools.definitions.each do |tool|
            say "  - #{tool[:function][:name]}: #{tool[:function][:description].slice(0, 60)}...", :white
          end
          return
        end

        # Generate chapter
        begin
          result = agent.generate_chapter(chapter_number, requirements: options[:requirements])

          # Show tool calls log
          if options[:debug] && agent.tool_calls_log.any?
            say "\nTool calls made:", :blue
            agent.tool_calls_log.each do |call|
              say "   - #{call[:name]}(#{call[:arguments].inspect})", :white
            end
          end

          say "\nChapter generated successfully!", :green
          say "   Title: #{result['title']}", :cyan
          say "   Summary: #{result['summary'].slice(0, 100)}...", :white if result['summary']
          say "   Word count: #{result['content'].to_s.split.length}", :white
          if result['characters_featured']&.any?
            say "   Characters: #{result['characters_featured'].join(', ')}", :white
          end

          # Save the chapter
          save_agent_chapter(abs_root, chapter_number, result)
        rescue Eidos::LLMService::LLMError => e
          say "\nAgent error: #{e.message}", :red
          exit 1
        end
      end

      private

      # Determine next chapter number using max(files, state) + 1
      # This is the same logic as ChapterGenerator.determine_next_chapter_number
      def determine_next_chapter_number(project_root)
        chapters_dir = File.join(project_root, 'content', 'chapters')
        max_from_files = 0

        if Dir.exist?(chapters_dir)
          Dir.glob(File.join(chapters_dir, '*.md')).each do |path|
            basename = File.basename(path)
            # Match NNN-chapter.md only (no language suffix like .ru.md)
            if basename =~ /^(\d{3})-chapter\.md$/
              num = Regexp.last_match(1).to_i
              max_from_files = [max_from_files, num].max
            end
          end
        end

        require 'eidos/world_config'
        world_config = Eidos::WorldConfig.load_from_project(project_root)
        current_in_metadata = world_config&.current_chapter || 0

        [max_from_files, current_in_metadata].max + 1
      end

      def save_agent_chapter(project_root, chapter_number, result)
        # Create chapter file
        chapters_dir = File.join(project_root, 'content', 'chapters')
        FileUtils.mkdir_p(chapters_dir)

        filename = File.join(chapters_dir, format('%03d-chapter.md', chapter_number))

        front_matter = {
          'layout' => 'chapter',
          'title' => result['title'],
          'chapter_number' => chapter_number,
          'summary' => result['summary'],
          'characters' => result['characters_featured'] || [],
          'generated_by' => 'agent-writer',
          'generated_at' => Time.now.strftime('%Y-%m-%dT%H:%M:%S%:z'),
          'lang' => 'en'
        }

        content = +"---\n"
        content << front_matter.to_yaml.lines[1..].join
        content << "---\n\n"
        content << result['content'].to_s

        File.write(filename, content)
        say "   Saved to: #{filename}", :green

        # Update world state
        begin
          require 'eidos/world_config'
          world_config = Eidos::WorldConfig.load_from_project(project_root)
          if world_config
            world_config.update_current_chapter(chapter_number)
            world_config.save!
          end
        rescue StandardError => e
          say "   Could not update world state: #{e.message}", :yellow
        end
      end
    end
  end
end
