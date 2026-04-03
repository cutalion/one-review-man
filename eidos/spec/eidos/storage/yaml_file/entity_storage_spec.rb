# frozen_string_literal: true

require 'spec_helper'
require 'eidos/storage/yaml_file/entity_storage'
require 'tmpdir'
require_relative '../shared_entity_storage_examples'

RSpec.describe Eidos::Storage::YamlFile::EntityStorage do
  let(:tmpdir) { Dir.mktmpdir('yaml_entity_test') }
  let(:entity_storage) { described_class.new(project_root: tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  it_behaves_like 'entity storage contract'
end
