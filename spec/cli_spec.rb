# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/book/cli/version'

RSpec.describe 'book CLI' do
  let(:cli_path) { File.expand_path('../bin/book', __dir__) }

  it 'prints version with --version' do
    stdout, stderr, status = Open3.capture3('ruby', cli_path, '--version')
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(stdout.strip).to eq(Book::CLI::VERSION)
  end
end 
