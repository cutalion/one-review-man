# frozen_string_literal: true

require 'bundler/setup'
# Ensure the legacy library path is resolvable when specs are executed inside
# the book-generator package.  This keeps existing `require_relative '../lib/'`
# statements functional even after we moved the specs into a sub-directory.

# Package lib (book-generator/lib)
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__)) unless $LOAD_PATH.include?(File.expand_path('../lib', __dir__))

# Provide RUBYOPT to inject mock LLM in subprocess CLI invocations
ENV['RUBYOPT'] = [ENV.fetch('RUBYOPT', nil), "-r#{File.expand_path('support/inject_mock_llm', __dir__)}"].compact.join(' ')

require 'open3'

# The sandboxed execution environment used by the test runner may deny write
# access to the system-wide `/tmp` directory.  This causes Ruby's `Dir.mktmpdir`
# to raise `Errno::EACCES` when specs attempt to create temporary directories.
#
# To make the specs independent from the system tmp directory we redirect the
# temporary directory base to a writable location inside the project folder.
#
# NOTE: We intentionally set this before any specs are executed so that *all*
# calls to `Dir.mktmpdir` honour the new value.

require 'tmpdir'

unless ENV['TMPDIR'] && File.writable?(ENV['TMPDIR'])
  project_tmp = File.expand_path('../tmp', __dir__)
  require 'fileutils'
  FileUtils.mkdir_p(project_tmp)
  ENV['TMPDIR'] = project_tmp
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Run specs in random order to surface order dependencies.
  config.order = :random
  Kernel.srand config.seed
end
