# frozen_string_literal: true

# lib/test_support/mock_llm_service.rb
#
# Deterministic replacement for LLMService used in tests and validation scripts.
# It sources canned chapter responses from `test/support/mock_responses.yml` so that
# the test-suite and validation runs remain stable without network calls.
#
# Every prompt-facing method is wrapped in the PromptAssertionHarness gate so
# unfilled `{PLACEHOLDER}` tokens and "Unused placeholders" warnings emitted
# during prompt construction fail the enclosing spec.
#
# Contract: specs/013-spec-coverage-backfill/contracts/prompt-assertion.md

require 'yaml'
require 'stringio'
require_relative 'prompt_assertion_harness'

class MockLLMService
  RESPONSES_FILE = File.expand_path('mock_responses.yml', __dir__)

  # Names of prompt-facing public methods routed through the harness. Kept
  # in sync with prompt-assertion.md#surface-area; the harness's self-test
  # spec asserts this list matches MockLLMService.instance_methods(false).
  HARNESS_COVERED_METHODS = %i[
    generate_text
    generate_chapter_structured
    improve_content
    translate_chapter_structured
    translate_character_structured
  ].freeze

  # Tee $stderr into a thread-local buffer so warnings emitted during prompt
  # construction (which happens BEFORE the mock method is entered) are
  # visible when the wrap drains the buffer on each call. Forwards to the
  # real $stderr so spec output stays readable — this is not a silent
  # redirect.
  module StderrCapture
    class Tee
      def initialize(real)
        @real = real
      end

      def write(str)
        buffer << str.to_s
        @real.write(str)
      end

      def puts(*args)
        if args.empty?
          write("\n")
        else
          args.each do |a|
            s = a.to_s
            write(s.end_with?("\n") ? s : "#{s}\n")
          end
        end
        nil
      end

      def print(*args)
        args.each { |a| write(a.to_s) }
        nil
      end

      def printf(format_str, *args)
        write(format(format_str, *args))
      end

      def <<(obj)
        write(obj.to_s)
        self
      end

      def buffer
        Thread.current[:prompt_assertion_warn_buffer] ||= +''
      end

      def drain_lines!
        lines = buffer.split("\n").reject(&:empty?)
        Thread.current[:prompt_assertion_warn_buffer] = +''
        lines
      end

      def respond_to_missing?(name, include_private = false)
        @real.respond_to?(name, include_private) || super
      end

      def method_missing(name, *args, &blk)
        if @real.respond_to?(name)
          @real.send(name, *args, &blk)
        else
          super
        end
      end
    end

    @installed = false

    def self.install!
      return if @installed

      @tee = Tee.new($stderr)
      $stderr = @tee
      @installed = true
    end

    def self.tee
      @tee
    end

    def self.drain!
      tee ? tee.drain_lines! : []
    end
  end

  StderrCapture.install!

  def initialize(config_or_path = nil, *args)
    if config_or_path.is_a?(Hash)
      @config = config_or_path['llm'] || {}
      @settings = config_or_path
      responses_file = RESPONSES_FILE
    else
      @config = {}
      @settings = {}
      responses_file = config_or_path || RESPONSES_FILE
    end
    @responses = File.exist?(responses_file) ? YAML.load_file(responses_file) : {}
  end

  # Simple text generation API (compatible subset)
  # @param prompt [String]
  # @param context [Hash]
  def generate_text(prompt:, context: {})
    assert_prompt!(prompt, :generate_text)
    capture_during_call do
      form_key = extract_form_hint(prompt)
      if form_key && @responses[form_key]
        @responses[form_key]
      else
        chapter_num = extract_chapter_number(prompt) || context[:chapter_number] || '1'
        @responses["chapter_#{chapter_num}"] || 'Mock chapter content for testing'
      end
    end
  end

  # Structured chapter generation used by ChapterGenerator
  def generate_chapter_structured(prompt, *_)
    assert_prompt!(prompt, :generate_chapter_structured)
    capture_during_call do
      {
        'title' => 'Mock Title',
        'summary' => 'Mock Summary',
        'content' => @responses['chapter_1'] || '# Heading\nMock content.',
        'new_characters' => []
      }
    end
  end

  # Basic stubs for other API calls used in specs
  def improve_content(content, *_)
    assert_prompt!(content, :improve_content)
    capture_during_call do
      "#{content}\n(Improved)"
    end
  end

  def translate_chapter_structured(title, summary, content, *_)
    combined = [title, summary, content].map(&:to_s).join("\n")
    assert_prompt!(combined, :translate_chapter_structured)
    capture_during_call do
      { 'title' => title, 'summary' => summary, 'content' => content }
    end
  end

  def translate_character_structured(name, description, *_)
    combined = [name, description].map(&:to_s).join("\n")
    assert_prompt!(combined, :translate_character_structured)
    capture_during_call do
      {
        'name' => name,
        'description' => description,
        'personality_traits' => [],
        'programming_skills' => '',
        'catchphrase' => '',
        'backstory' => '',
        'quirks' => ''
      }
    end
  end

  def get_model_for_task(task_type)
    if @settings && @settings['content'] && @settings['content']['model']
      @settings['content']['model']
    else
      @config['model'] || 'mock-model'
    end
  end

  def resolve_image_options(provider: nil, model: nil, style: nil, size: nil, orientation: nil)
    illustration_config = (@settings && @settings['illustration']) || {}

    # Use explicit args, then illustration config, then hardcoded fallbacks
    provider ||= illustration_config['provider'] || 'openai'
    model ||= illustration_config['model'] || 'dall-e-3'
    style ||= illustration_config['style'] || 'vivid'

    # Resolve size from orientation if size is not explicit
    unless size
      orientation ||= illustration_config['orientation']
      size = resolve_default_size(orientation) || '1024x1024'
    end

    {
      provider: provider,
      model: model,
      style: style,
      size: size,
      orientation: orientation
    }
  end

  def resolve_default_size(orientation)
    case orientation.to_s.downcase
    when 'portrait'
      '1024x1792'
    when 'landscape'
      '1792x1024'
    else
      '1024x1024' # square
    end
  end

  def generate_image(prompt, size: nil, quality: 'standard', style: nil, model: nil, provider: nil)
    'https://placehold.co/1024x1024/png?text=Mock+Image'
  end

  private

  # Drains any $stderr lines accumulated since the last mock call (typically
  # emitted by PromptUtils.build_prompt during prompt construction) and
  # routes the prompt + those warnings through the assertion harness. Runs
  # BEFORE the delegate body so a leak short-circuits the mock response.
  def assert_prompt!(prompt, method_name)
    warnings = StderrCapture.drain!
    Eidos::Spec::PromptAssertionHarness.assert!(
      prompt: prompt.to_s,
      warnings: warnings,
      caller_desc: caller_description(method_name)
    )
    log_prompt!(prompt, method_name)
  end

  # Subprocess-spy hook: when EIDOS_SPEC_PROMPT_LOG is set, append every prompt
  # passed through the harness to the named file, separated by a fixed delimiter.
  # Used by integration specs that shell out to the CLI and need to inspect the
  # actual prompt string the mock received (see T021 / produce --prompt flag).
  def log_prompt!(prompt, method_name)
    path = ENV['EIDOS_SPEC_PROMPT_LOG']
    return if path.nil? || path.empty?

    record = "---PROMPT-BEGIN method=#{method_name}---\n#{prompt}\n---PROMPT-END---\n"
    File.open(path, 'a') { |f| f.write(record) }
  end

  # Narrow $stderr capture around the delegate body: any lines the mock
  # itself writes to $stderr during this call are captured into a local
  # StringIO (forwarded back to the real stream on exit), so they don't
  # contaminate the buffer used by the NEXT mock call's warnings scan.
  def capture_during_call
    io = StringIO.new
    real_tee = $stderr
    $stderr = io
    begin
      result = yield
    ensure
      $stderr = real_tee
      real_tee.write(io.string) unless io.string.empty?
    end
    result
  end

  def caller_description(method_name)
    example_desc =
      if defined?(::RSpec) && ::RSpec.respond_to?(:current_example) && ::RSpec.current_example
        ::RSpec.current_example.full_description
      else
        '(no current spec example)'
      end
    "#{example_desc} → MockLLMService##{method_name}"
  end

  def extract_chapter_number(prompt)
    prompt.to_s.match(/chapter\s*(\d+)/i)&.captures&.first
  end

  FORM_PROMPT_SIGNATURES = {
    'form_vignette' => /You are writing a short vignette/i,
    'form_haiku' => /You are writing a haiku/i,
    'form_portrait' => /image-generation prompt for a single character portrait/i,
    'form_illustration' => /image-generation prompt for a single scene illustration/i,
    'form_social_post' => /drafting a single social-media post/i,
    'form_short_story' => /You are writing a short story/i,
    'form_comic_script' => /You are writing a comic-panel script/i
  }.freeze

  def extract_form_hint(prompt)
    text = prompt.to_s
    FORM_PROMPT_SIGNATURES.each do |key, pattern|
      return key if pattern.match?(text)
    end
    nil
  end
end
