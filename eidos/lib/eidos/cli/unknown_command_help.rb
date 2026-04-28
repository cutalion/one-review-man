# frozen_string_literal: true

require 'thor'

module Eidos
  module CLI
    # Extend into a Thor class to replace the default "Could not find command X."
    # error with a friendly "Unknown command" line followed by the class's own
    # help output (list of available commands).
    module UnknownCommandHelp
      def handle_no_command_error(command_name, has_namespace = $thor_runner)
        shell = Thor::Base.shell.new
        shell.say "Unknown command: #{command_name.inspect}", :red
        shell.say
        help(shell, has_namespace)
        exit 1
      end
      alias_method :handle_no_task_error, :handle_no_command_error
    end
  end
end
