# frozen_string_literal: true

# User-scale integration harness for the 015-scaffold-hardening feature.
# Shells `exe/eidos` end-to-end via Open3.capture3 into a Dir.mktmpdir world.
# Asserts on disk artifacts — no direct Eidos::CLI::* invocations.
#
# Contract: specs/015-scaffold-hardening/data-model.md §5.

require 'open3'
require 'tmpdir'
require 'fileutils'

module Eidos
  module Spec
    module IntegrationWorldBuilder
      EIDOS_BIN = File.expand_path('../../exe/eidos', __dir__)

      Result = Struct.new(:world_path, :stdout, :stderr, :status, keyword_init: true) do
        def success?
          status&.success?
        end
      end

      module_function

      # Shell `eidos world new --quick` with the given flags into a fresh
      # temp directory. Yields the world_path; the tmpdir is auto-cleaned
      # on block exit.
      #
      # @param premise [String] the premise text (may be multi-line)
      # @param title [String] world title
      # @param author [String] author name
      # @param languages [String] CSV of ISO codes (default "en")
      # @param extra_flags [Hash] additional --flag => value pairs
      # @yieldparam result [Result] the Result record and the world path
      # @return [Result] if no block given
      def build_world(premise:, title: 'Test World', author: 'QA',
                      languages: 'en', extra_flags: {})
        if block_given?
          Dir.mktmpdir('orm-015-user-scale-') do |tmpdir|
            result = run_world_new(tmpdir, premise, title, author, languages, extra_flags)
            yield result
            result
          end
        else
          tmpdir = Dir.mktmpdir('orm-015-user-scale-')
          run_world_new(tmpdir, premise, title, author, languages, extra_flags)
        end
      end

      # Shell an arbitrary `eidos ...` invocation. Used by integration
      # specs that need to call `produce`, `world status`, `canon review`
      # after build_world.
      def run_eidos(*argv, env: {})
        stdout, stderr, status = Open3.capture3(env, 'ruby', EIDOS_BIN, *argv)
        Result.new(world_path: nil, stdout: stdout, stderr: stderr, status: status)
      end

      def run_world_new(tmpdir, premise, title, author, languages, extra_flags)
        argv = [
          'world', 'new', '--quick',
          '-w', tmpdir,
          '--title', title,
          '--author', author,
          '--premise', premise,
          '--languages', languages,
          '--no-seed'
        ]
        extra_flags.each do |flag, value|
          argv << flag.to_s
          argv << value.to_s unless value.nil?
        end

        stdout, stderr, status = Open3.capture3('ruby', EIDOS_BIN, *argv)
        Result.new(world_path: tmpdir, stdout: stdout, stderr: stderr, status: status)
      end
    end
  end
end
