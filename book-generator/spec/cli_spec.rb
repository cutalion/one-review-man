# frozen_string_literal: true

require 'spec_helper'
require 'book/cli/version'

RSpec.describe 'book CLI' do
  let(:cli_path) { File.expand_path('../bin/book', __dir__) }

  it 'prints version with --version' do
    stdout, stderr, status = Open3.capture3('ruby', cli_path, '--version')
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(stdout.strip).to eq(Book::CLI::VERSION)
  end

  it 'shows help for init command' do
    stdout, stderr, status = Open3.capture3('ruby', cli_path, 'help', 'init')
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(stdout).to include('Initialize a new book project')
    expect(stdout).to include('--book-dir')
    expect(stdout).to include('--quick')
  end

  it 'recognizes init as a direct command' do
    # Test that init command is recognized (we don't want to actually run it with prompts)
    stdout, stderr, status = Open3.capture3('ruby', cli_path, 'init', '--help')
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(stdout).to include('Initialize a new book project')
  end
end 
