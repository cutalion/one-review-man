# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'eidos/cli/canon'
require 'eidos/audit_log'
require 'eidos/audit_finding'

# T047 — US3 / feature 014-storyworld-pivot.
#
# Covers `eidos canon accept` and `eidos canon patch`: both close the
# referenced finding with the correct resolution.
RSpec.describe Eidos::CLI::Canon, 'canon accept / patch' do
  let(:tmp_dir) { Dir.mktmpdir('canon_accept_patch_spec') }
  let(:audit_log) { Eidos::AuditLog.new(world_path: tmp_dir) }

  before do
    FileUtils.mkdir_p(File.join(tmp_dir, 'data'))
    File.write(File.join(tmp_dir, 'data', 'world_config.yml'),
               { 'localized' => { 'en' => { 'title' => 'x' } } }.to_yaml)
  end

  after { FileUtils.rm_rf(tmp_dir) }

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def open_finding
    audit_log.append(Eidos::AuditFinding.open(
                       kind: 'conflict',
                       piece_id: 'VIG001',
                       canon_delta_id: 'DELTAID',
                       canon_version_before: 'v1',
                       canon_version_after: 'v2',
                       explanation: 'Sample.'
                     ))
  end

  describe 'accept' do
    it 'closes the finding with resolution: accept' do
      finding = open_finding
      capture_stdout { described_class.start(['accept', '-w', tmp_dir, '--finding', finding.id]) }

      reloaded = audit_log.find(finding.id)
      expect(reloaded.closed?).to be(true)
      expect(reloaded.resolution).to eq('accept')
    end

    it 'exits 1 when the finding does not exist' do
      stderr = $stderr
      $stderr = StringIO.new
      expect do
        capture_stdout { described_class.start(['accept', '-w', tmp_dir, '--finding', 'NOPE']) }
      end.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    ensure
      $stderr = stderr
    end
  end

  describe 'patch' do
    it 'closes the finding with resolution: patch-canon when editor succeeds' do
      finding = open_finding
      # Stub $EDITOR invocation — the command layer shells out; override
      # via an environment variable that the implementation reads.
      fake_editor = File.join(tmp_dir, 'fake_editor.sh')
      File.write(fake_editor, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, fake_editor)

      orig_editor = ENV.fetch('EDITOR', nil)
      ENV['EDITOR'] = fake_editor
      begin
        capture_stdout { described_class.start(['patch', '-w', tmp_dir, '--finding', finding.id]) }
      ensure
        ENV['EDITOR'] = orig_editor
      end

      reloaded = audit_log.find(finding.id)
      expect(reloaded.closed?).to be(true)
      expect(reloaded.resolution).to eq('patch-canon')
    end
  end
end
