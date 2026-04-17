# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'tmpdir'

RSpec.describe 'First-run UX (feature 012-fix-ux-unify-bible)' do
  let(:cli_world)   { File.expand_path('../../../bin/world',   __dir__) }
  let(:cli_produce) { File.expand_path('../../../bin/produce', __dir__) }

  # SC-001: a fresh `world new --quick` followed by `produce chapter` must
  # produce zero occurrences of these substrings in combined stdout.
  FORBIDDEN_SUBSTRINGS = [
    'Migrated',
    'CHARACTER_NAME',
    'CHARACTER_DESCRIPTION',
    'Not specified'
  ].freeze

  it 'fresh world + produce chapter output contains no forbidden substrings (SC-001)' do
    Dir.mktmpdir('first_run_it') do |tmp|
      stdin = "Test Book\nTest Author\nA test book\nen\nen\n"
      out1, _err1, status1 = Open3.capture3(
        { 'MOCK_AI' => 'true' },
        'ruby', cli_world, 'new', '--world-dir', tmp, '--quick', stdin_data: stdin
      )
      expect(status1).to be_success

      out2, _err2, status2 = Open3.capture3(
        { 'MOCK_AI' => 'true' },
        'ruby', cli_produce, 'chapter', '--world-dir', tmp
      )
      expect(status2).to be_success

      combined = out1 + out2
      FORBIDDEN_SUBSTRINGS.each do |s|
        expect(combined).not_to include(s),
          "Expected combined first-run output to NOT include #{s.inspect}, but it did.\nOutput was:\n#{combined}"
      end
    end
  end
end
