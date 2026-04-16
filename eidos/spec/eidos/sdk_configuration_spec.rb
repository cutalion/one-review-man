# frozen_string_literal: true

require 'eidos'

RSpec.describe Eidos do
  after { Eidos.reset_configuration! }

  describe '.configure' do
    it 'yields a configuration object' do
      Eidos.configure do |c|
        c.worlds_path = '/tmp/my-worlds'
      end

      expect(Eidos.configuration.worlds_path).to eq('/tmp/my-worlds')
    end

    it 'has a default worlds_path of ./worlds' do
      expect(Eidos.configuration.worlds_path).to eq('./worlds')
    end

    it 'has a default storage_backend of :yaml_file' do
      expect(Eidos.configuration.storage_backend).to eq(:yaml_file)
    end
  end

  describe '.reset_configuration!' do
    it 'restores defaults' do
      Eidos.configure { |c| c.worlds_path = '/custom' }
      Eidos.reset_configuration!
      expect(Eidos.configuration.worlds_path).to eq('./worlds')
    end
  end
end
