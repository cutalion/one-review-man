# frozen_string_literal: true

# SimpleCov bootstrap for the Eidos test suite.
#
# Contract: specs/013-spec-coverage-backfill/contracts/coverage-cli.md
# Background: specs/013-spec-coverage-backfill/research.md (R1, R6)
#
# This file is required from the TOP of spec_helper.rb, before any
# eidos/** code is loaded, so SimpleCov can instrument it from the start.

# Committed baseline floor. Originally measured on commit 4966b5f at
# 46.81% → rounded down to 46. Bumped to 52 after feature 014-storyworld-pivot
# (measured 52.21% with the new piece/canon-delta/audit-log coverage).
EIDOS_DEFAULT_COVERAGE_FLOOR = 52

def coverage_enabled?
  return false if ENV['SIMPLECOV'] == 'false'
  return false if ENV['COVERAGE'] == 'false'

  # Single-file / directory invocations skip coverage entirely — running
  # one spec file never reflects total lib/ coverage, so threshold checks
  # would be misleading (FR-004).
  has_file_arg = ARGV.any? { |a| a.end_with?('_spec.rb') || File.directory?(a) }
  !has_file_arg
end

if coverage_enabled?
  require 'simplecov'

  configured_floor = Integer(ENV.fetch('EIDOS_COVERAGE_FLOOR', EIDOS_DEFAULT_COVERAGE_FLOOR.to_s))
  override         = ENV['COVERAGE_THRESHOLD']
  effective        = override ? Integer(override) : configured_floor

  if override && Integer(override) < configured_floor
    warn "⚠️  COVERAGE FLOOR OVERRIDDEN: configured=#{configured_floor}, this run=#{override}"
  end

  SimpleCov.start do
    enable_coverage :line
    track_files 'lib/**/*.rb'
    add_filter '/spec/'
    add_filter '/exe/'
    add_filter '/bin/'
    add_filter %r{lib/eidos/version\.rb\z}
    minimum_coverage effective unless effective.zero?
    formatter SimpleCov::Formatter::MultiFormatter.new([
                                                         SimpleCov::Formatter::SimpleFormatter,
                                                         SimpleCov::Formatter::HTMLFormatter
                                                       ])
  end
end
