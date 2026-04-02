# frozen_string_literal: true

require 'spec_helper'
require 'eidos/cli/version'

RSpec.describe 'CLI help system' do
  describe 'world help' do
    let(:cli_path) { File.expand_path('../bin/world', __dir__) }

    it 'shows help with help command' do
      stdout, stderr, status = Open3.capture3('ruby', cli_path, 'help')
      expect(status).to be_success
      expect(stderr).to be_empty
      expect(stdout).to include('Commands:')
      expect(stdout).to include('world new')
      expect(stdout).to include('world version')
    end

    it 'shows help with --help flag' do
      stdout, stderr, status = Open3.capture3('ruby', cli_path, '--help')
      expect(status).to be_success
      expect(stderr).to be_empty
      expect(stdout).to include('Commands:')
    end
  end

  describe 'produce help' do
    let(:cli_path) { File.expand_path('../bin/produce', __dir__) }

    it 'shows produce command help' do
      stdout, stderr, status = Open3.capture3('ruby', cli_path, 'help')
      expect(status).to be_success
      expect(stderr).to be_empty
      expect(stdout).to include('Commands:')
      expect(stdout).to include('produce chapter')
      expect(stdout).to include('produce prompt')
    end

    it 'shows chapter subcommand help with --help flag' do
      stdout, stderr, status = Open3.capture3('ruby', cli_path, 'help', 'chapter')
      expect(status).to be_success
      expect(stderr).to be_empty
      expect(stdout).to include('produce chapter')
      expect(stdout).to include('--auto')
      expect(stdout).to include('--content-model')
    end
  end
end
