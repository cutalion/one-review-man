# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe 'canon snapshot CLI' do
  let(:canon_path) { File.expand_path('../bin/canon', __dir__) }
  let(:world_path) { File.expand_path('../bin/world', __dir__) }
  let(:test_dir) { Dir.mktmpdir('snapshot_cli_test') }

  before do
    # Initialize a minimal world project
    stdin_data = "Test Book\nTest Author\nA test book\nen\nen\n"
    Open3.capture3('ruby', world_path, 'new', '--world-dir', test_dir, '--quick', stdin_data: stdin_data)
  end

  after { FileUtils.rm_rf(test_dir) }

  describe 'snapshot create' do
    it 'creates a snapshot and shows confirmation' do
      stdout, stderr, status = Open3.capture3('ruby', canon_path, 'snapshot', 'create', 'initial', '-w', test_dir)

      expect(status).to be_success
      expect(stderr).to be_empty
      expect(stdout).to include('Created snapshot "initial"')
      expect(stdout).to include('version 1')
    end

    it 'rejects duplicate names' do
      Open3.capture3('ruby', canon_path, 'snapshot', 'create', 'initial', '-w', test_dir)
      _stdout, stderr, status = Open3.capture3('ruby', canon_path, 'snapshot', 'create', 'initial', '-w', test_dir)

      expect(status).not_to be_success
      expect(stderr).to include('already exists')
    end

    it 'rejects invalid names' do
      _stdout, stderr, status = Open3.capture3('ruby', canon_path, 'snapshot', 'create', 'INVALID', '-w', test_dir)

      expect(status).not_to be_success
      expect(stderr).to include('Invalid snapshot name')
    end
  end

  describe 'snapshot list' do
    it 'shows "No snapshots found" when empty' do
      stdout, _stderr, status = Open3.capture3('ruby', canon_path, 'snapshot', 'list', '-w', test_dir)

      expect(status).to be_success
      expect(stdout).to include('No snapshots found')
    end

    it 'lists created snapshots' do
      Open3.capture3('ruby', canon_path, 'snapshot', 'create', 'first', '-w', test_dir)
      Open3.capture3('ruby', canon_path, 'snapshot', 'create', 'second', '-w', test_dir)

      stdout, _stderr, status = Open3.capture3('ruby', canon_path, 'snapshot', 'list', '-w', test_dir)

      expect(status).to be_success
      expect(stdout).to include('first')
      expect(stdout).to include('second')
      expect(stdout).to include('v1')
      expect(stdout).to include('v2')
    end
  end

  describe 'snapshot show' do
    it 'shows snapshot details' do
      Open3.capture3('ruby', canon_path, 'snapshot', 'create', 'initial', '-w', test_dir)

      stdout, _stderr, status = Open3.capture3('ruby', canon_path, 'snapshot', 'show', 'initial', '-w', test_dir)

      expect(status).to be_success
      expect(stdout).to include('initial')
      expect(stdout).to include('version 1')
      expect(stdout).to include('Characters')
    end

    it 'reports error for non-existent snapshot' do
      _stdout, stderr, status = Open3.capture3('ruby', canon_path, 'snapshot', 'show', 'nonexistent', '-w', test_dir)

      expect(status).not_to be_success
      expect(stderr).to include('not found')
    end
  end
end
