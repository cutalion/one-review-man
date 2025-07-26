# frozen_string_literal: true

require 'spec_helper'
require 'book/cli/version'

RSpec.describe 'book help system' do
  let(:cli_path) { File.expand_path('../bin/book', __dir__) }

  describe 'global help' do
    it 'shows help with help command' do
      stdout, stderr, status = Open3.capture3('ruby', cli_path, 'help')
      expect(status).to be_success
      expect(stderr).to be_empty
      expect(stdout).to include('Commands:')
      expect(stdout).to include('book generate')
      expect(stdout).to include('book version')
    end

    it 'shows help with --help flag' do
      stdout, stderr, status = Open3.capture3('ruby', cli_path, '--help')
      expect(status).to be_success
      expect(stderr).to be_empty
      expect(stdout).to include('Commands:')
      expect(stdout).to include('book generate')
    end
  end

  describe 'command-level help' do
    it 'shows generate command help' do
      stdout, stderr, status = Open3.capture3('ruby', cli_path, 'generate', 'help')
      expect(status).to be_success
      expect(stderr).to be_empty
      expect(stdout).to include('Commands:')
      expect(stdout).to include('book generate chapter')
      expect(stdout).to include('book generate prompt')
    end

    it 'shows generate command help with --help flag' do
      stdout, stderr, status = Open3.capture3('ruby', cli_path, 'generate', '--help')
      expect(status).to be_success
      expect(stderr).to be_empty
      expect(stdout).to include('Commands:')
      expect(stdout).to include('book generate chapter')
    end
  end

  describe 'subcommand-level help' do
    it 'shows chapter subcommand help with --help flag' do
      stdout, stderr, status = Open3.capture3('ruby', cli_path, 'generate', 'chapter', '--help')
      expect(status).to be_success
      expect(stderr).to be_empty
      expect(stdout).to include('book generate chapter')
      expect(stdout).to include('--auto')
      expect(stdout).to include('--model')
    end
  end
end 
