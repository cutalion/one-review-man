# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'book_core/config'

RSpec.describe BookCore::Config do
  describe '.load_yaml' do
    it 'returns empty hash for missing file' do
      expect(described_class.load_yaml('nonexistent.yml')).to eq({})
    end

    it 'parses existing YAML file' do
      Tempfile.create(['config', '.yml']) do |file|
        file.write("key: value\n")
        file.rewind
        expect(described_class.load_yaml(file.path)).to eq({ 'key' => 'value' })
      end
    end
  end
end 
