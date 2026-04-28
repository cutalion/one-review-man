# frozen_string_literal: true

require 'thor'
require 'eidos/cli/helpers'
require 'eidos/cli/unknown_command_help'
require 'eidos/form_registry'
require 'eidos/audit_log'

module Eidos
  module CLI
    # CLI commands for content production. Generates pieces of any registered form
    # — chapter, haiku, vignette, comic-script, portrait, social-post, illustration,
    # or a world-defined custom form. `produce chapter` remains as a shortcut for
    # the chapter form; `produce piece --form <name>` is the generic entry point.
    class Produce < Thor
      extend Eidos::CLI::UnknownCommandHelp
      include Helpers

      # Thor subcommands that must NEVER be shadowed by short-form dispatch
      # (T033). `chapter` stays routed to the chapter subcommand (SC-002),
      # `piece` is the generic entry point, `comic` / `illustration` drive
      # specialized producers, and the rest are existing utility commands.
      RESERVED_SUBCOMMANDS = %w[piece chapter comic illustration prompt write help version].freeze

      # Intercept argv before Thor dispatches. If the first positional
      # argument resolves to a registered form in the active world AND is
      # not a reserved subcommand, rewrite `produce <form> ...` into
      # `produce piece --form <form> ...` (FR-012). Covers both the direct
      # `Eidos::CLI::Produce.start(...)` invocation path (specs) and the
      # parent-router `invoke subcommand_class, ...` path (the `eidos`
      # binary routes through Main → dispatch).
      def self.start(given_args = ARGV, config = {})
        given_args = rewrite_short_form(given_args.dup) if given_args.is_a?(Array)
        super
      end

      def self.dispatch(meth, given_args, given_opts, config)
        if meth.nil? && given_args.is_a?(Array) && !given_args.empty? &&
           form_candidate?(given_args.first)
          combined = given_args + (given_opts || [])
          rewritten = rewrite_short_form(combined)
          return super(meth, rewritten, nil, config) if rewritten != combined
        end
        super
      end

      def self.form_candidate?(arg)
        s = arg.to_s
        !s.empty? && !s.start_with?('-') && !RESERVED_SUBCOMMANDS.include?(s)
      end

      def self.rewrite_short_form(args)
        return args if args.empty?

        cmd = args.first.to_s
        return args if cmd.empty? || cmd.start_with?('-')
        return args if RESERVED_SUBCOMMANDS.include?(cmd)

        world_dir = extract_world_dir(args) || Dir.pwd
        registry = Eidos::FormRegistry.new(world_path: world_dir)
        return ['piece', '--form', cmd, *args[1..]] if registry.registered?(cmd)

        warn "Unknown form or subcommand: '#{cmd}'."
        warn 'Registered forms in this world:'
        registry.each { |f| warn "  #{f.name} (#{f.category})" }
        exit 1
      rescue SystemExit
        raise
      rescue StandardError
        args
      end

      def self.extract_world_dir(args)
        idx = args.index('-w') || args.index('--world-dir')
        return nil unless idx && args[idx + 1]

        args[idx + 1]
      end

      class_option 'world-dir', aliases: ['-w'], type: :string,
                                desc: 'Path to the world directory (defaults to current directory)'
      class_option 'content-model', type: :string,
                                    desc: 'Specify the model to use for generation (defaults to settings.yml)'
      class_option :auto, type: :boolean, default: false, desc: 'Auto mode: skip interactive prompts'
      class_option :debug, type: :boolean, default: false, desc: 'Enable verbose LLM debug logging'

      # T036 — when `produce piece --help` (or `produce help piece`) runs,
      # list the forms registered in the active world so the user can see
      # built-ins + world-local custom forms without digging into files.
      # Thor routes both `produce help piece` and `produce piece --help` to
      # the class-level `command_help`; that's where we hook in.
      def self.command_help(shell, command_name)
        super
        return unless command_name.to_s == 'piece'

        world_dir = ARGV.each_cons(2).detect { |a, _| %w[-w --world-dir].include?(a) }&.last || Dir.pwd
        registry = Eidos::FormRegistry.new(world_path: world_dir)
        shell.say ''
        shell.say 'Forms registered in this world:'
        registry.each do |form|
          origin = form.world_local? ? ' (world-local)' : ''
          shell.say "  #{form.name}#{origin}  [#{form.category}]"
        end
      rescue StandardError
        # Help output must never crash the CLI.
      end

      desc 'piece', 'Generate a piece in any registered form (vignette, haiku, portrait, …)'
      method_option :form, type: :string, required: true,
                           desc: 'Registered form name (e.g. vignette, haiku, short-story, portrait)'
      method_option :prompt, type: :string, required: true,
                             desc: 'User guidance for the form (e.g. "A quiet morning of job rejections")'
      method_option :length, type: :string,
                             desc: 'Per-invocation length override (integer or shape string)'
      method_option 'dry-run', type: :boolean, default: false,
                               desc: 'Print the body without writing a piece file'
      method_option :snapshot, type: :string, desc: 'Pin generation to a specific canon snapshot'
      def piece
        abs_root = resolve_project_root!(options['world-dir'])

        Dir.chdir(abs_root) do
          ENV['DEBUG_AI'] = '1' if options[:debug]

          require 'eidos/configuration'
          require 'eidos/llm_service'
          require 'eidos/world_config'
          require 'eidos/bible'
          require 'eidos/canon'
          require 'eidos/form_registry'
          require 'eidos/producers/piece_producer'

          config = Eidos::Configuration.load(abs_root, options)
          llm = Eidos::LLMService.new(config)
          world_config = Eidos::WorldConfig.load_from_project(abs_root)
          bible = Eidos::Bible.new(world_path: abs_root)
          canon = Eidos::Canon.new(world_path: abs_root)
          registry = Eidos::FormRegistry.new(world_path: abs_root)
          audit_log = Eidos::AuditLog.new(world_path: abs_root)

          # T035 / FR-013: tell the user when a world-local form won over
          # a built-in. Printed before any other stdout so script callers
          # parsing output get a stable signal.
          puts "Using world-local form '#{options[:form]}' (overrides built-in)." if registry.registered?(options[:form]) && registry.override?(options[:form])

          producer = Eidos::Producers::PieceProducer.new(
            world_path: abs_root,
            llm_service: llm,
            form_registry: registry,
            bible: bible,
            canon: canon,
            audit_log: audit_log,
            world_config: world_config
          )

          length = coerce_length(options[:length])

          begin
            result = producer.produce(
              form: options[:form],
              prompt: options[:prompt],
              length: length,
              dry_run: options['dry-run']
            )
          rescue Eidos::FormNotFound => e
            warn "Error: #{e.message}"
            exit 1
          end

          puts "Generated #{result.form} piece: #{result.id}" unless options['dry-run']
        end
      end

      desc 'chapter [NUMBER]', 'Generate the next chapter (form=chapter shortcut)'
      method_option :snapshot, type: :string, desc: 'Pin generation to a specific canon snapshot'
      method_option :output, type: :string, desc: 'Output directory for generated artifacts'
      method_option :prompt, type: :string,
                             desc: 'Extra guidance appended to the generation prompt (e.g. "keep it under 3 sentences")'
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
              model: options['content-model'],
              extra_guidance: options[:prompt]
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
          say "Warning: Anchor line #{anchor_line} is outside content range #{content_range}", :yellow if anchor_line < start_line || anchor_line > end_line

          # Extract anchor text (single line)
          anchor_text = anchor_line.positive? && anchor_line <= chapter_lines.length ? chapter_lines[anchor_line - 1].strip : nil

          # Load settings to get defaults
          require 'eidos/configuration'
          config = Eidos::Configuration.load(abs_root, options)

          # Three-tier override precedence: CLI > ENV > Settings > Defaults (handled in LLMService)
          provider = options[:provider] || ENV.fetch('ILLUSTRATION_PROVIDER', nil)
          model = options['content-model'] || ENV.fetch('ILLUSTRATION_MODEL', nil)
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
          say "   Characters: #{result['characters_featured'].join(', ')}", :white if result['characters_featured']&.any?

          # Save the chapter
          save_agent_chapter(abs_root, chapter_number, result)
        rescue Eidos::LLMService::LLMError => e
          say "\nAgent error: #{e.message}", :red
          exit 1
        end
      end

      private

      # Accept either a bare integer ("400") or a shape string ("500-1000 words").
      # Integers are coerced; anything else passes through as a string so the
      # prompt can carry descriptive length targets for haiku / portrait / etc.
      def coerce_length(raw)
        return nil if raw.nil? || raw.to_s.empty?

        raw.to_s.match?(/\A\d+\z/) ? raw.to_i : raw.to_s
      end

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
