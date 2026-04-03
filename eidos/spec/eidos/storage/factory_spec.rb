# frozen_string_literal: true

require 'spec_helper'
require 'eidos/storage/factory'
require 'tmpdir'

RSpec.describe Eidos::Storage::Factory do
  let(:tmpdir) { Dir.mktmpdir('factory_test') }

  after { FileUtils.rm_rf(tmpdir) }

  describe '.backend_name_from_config' do
    it 'defaults to yaml_file when no settings exist' do
      expect(described_class.backend_name_from_config(tmpdir)).to eq('yaml_file')
    end

    it 'defaults to yaml_file when storage section is missing' do
      FileUtils.mkdir_p(File.join(tmpdir, 'data'))
      File.write(File.join(tmpdir, 'data', 'settings.yml'), { 'llm' => {} }.to_yaml)

      expect(described_class.backend_name_from_config(tmpdir)).to eq('yaml_file')
    end

    it 'reads backend from settings.yml' do
      FileUtils.mkdir_p(File.join(tmpdir, 'data'))
      File.write(File.join(tmpdir, 'data', 'settings.yml'),
                 { 'storage' => { 'backend' => 'memory' } }.to_yaml)

      expect(described_class.backend_name_from_config(tmpdir)).to eq('memory')
    end
  end

  describe '.resolve_backend' do
    it 'raises ArgumentError for unknown backend' do
      expect { described_class.build_entity_storage('nonexistent') }
        .to raise_error(ArgumentError, /Unknown storage backend 'nonexistent'/)
    end

    it 'lists available backends in error message' do
      expect { described_class.build_entity_storage('bad') }
        .to raise_error(ArgumentError, /Available backends:/)
    end
  end

  describe '.available_backends' do
    it 'returns list of registered backend names' do
      backends = described_class.available_backends
      expect(backends).to be_an(Array)
    end
  end
end
