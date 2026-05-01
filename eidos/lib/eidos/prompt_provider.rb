# frozen_string_literal: true

module Eidos
  # PromptProvider resolves prompt templates by name, first looking inside the
  # current book project (./prompts) and then falling back to the core library
  # templates (lib/eidos/prompts). Call `load(name)` to obtain the template
  # string or raise if not found.
  class PromptProvider
    CORE_PROMPTS_PATH = File.expand_path('prompts', __dir__)

    def initialize(book_root: Dir.pwd)
      @book_root = book_root
    end

    # @param name [String] filename of the prompt template (e.g.
    #        "chapter_prompts.txt")
    # @return [String] template contents
    # @raise [RuntimeError] when the template cannot be found in any location
    def load(name)
      candidate_paths(name).each do |path|
        return File.read(path, encoding: 'UTF-8') if File.exist?(path)
      end
      raise "Prompt template not found: #{name}. Searched: #{candidate_paths(name).join(', ')}"
    end

    private

    def candidate_paths(name)
      [File.join(@book_root, 'prompts', name),
       File.join(CORE_PROMPTS_PATH, name)]
    end
  end
end
