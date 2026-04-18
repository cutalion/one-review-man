# frozen_string_literal: true

require 'bundler/setup'

# Coverage FIRST so SimpleCov can instrument lib/** before any eidos code
# loads. (Implementation of coverage_setup.rb lands in US2 / T014.)
require_relative 'support/coverage_setup'

# Ensure the library path is resolvable when specs are executed inside
# the eidos package.

# Package lib (eidos/lib)
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__)) unless $LOAD_PATH.include?(File.expand_path('../lib', __dir__))

# Runtime prompt-call assertion gate (US1). Installs a $stderr tee used by
# MockLLMService to drain warnings per mock call — must load before the
# mock file that depends on it.
require_relative 'support/prompt_assertion_harness'
require_relative 'support/mock_llm_service'

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
