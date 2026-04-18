# frozen_string_literal: true

# Scripted-stdin subprocess driver for interactive-flow specs.
#
# Background: specs/013-spec-coverage-backfill/research.md (R3)
#
# Shells out to exe/eidos via Open3.popen3, pipes scripted input lines
# to stdin, enforces a per-call timeout so misordered scripts can't hang
# the suite.

require 'open3'
require 'timeout'

module Eidos
  module Spec
    module StdinDriver
      # Path to the unified `eidos` CLI binary in the repo worktree.
      EIDOS_BIN = File.expand_path('../../exe/eidos', __dir__)

      Result = Struct.new(:stdout, :stderr, :status, keyword_init: true) do
        def success?
          status.success?
        end
      end

      # Drive the `eidos` CLI as a real subprocess with a scripted stdin
      # stream. Each entry of `input_lines` is written followed by a newline.
      #
      # @param argv [Array<String>] arguments to pass to the eidos binary
      #   (e.g. `['world', 'new', '-w', '/tmp/x', '--quick', '--no-seed']`)
      # @param input_lines [Array<String>] answers to feed, one per prompt.
      #   An entry of `""` accepts the default (bare newline).
      # @param timeout [Integer] hard limit in seconds; kills the subprocess
      #   and raises if exceeded. Default 15 s.
      # @return [Result] captured stdout / stderr / Process::Status.
      def self.drive_cli(argv:, input_lines:, timeout: 15)
        Open3.popen3('ruby', EIDOS_BIN, *argv) do |stdin, stdout, stderr, wait_thr|
          input_lines.each { |line| stdin.puts(line.to_s) }
          stdin.close

          begin
            Timeout.timeout(timeout) do
              out = stdout.read
              err = stderr.read
              status = wait_thr.value
              return Result.new(stdout: out, stderr: err, status: status)
            end
          rescue Timeout::Error
            Process.kill('KILL', wait_thr.pid) rescue nil
            last_line = input_lines.last.inspect
            raise "StdinDriver timed out after #{timeout}s (argv=#{argv.inspect}, last input=#{last_line})"
          end
        end
      end
    end
  end
end
