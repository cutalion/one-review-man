# frozen_string_literal: true

require 'spec_helper'
require 'eidos/storage/yaml_file/entity_storage'
require 'eidos/storage/yaml_file/snapshot_storage'
require 'tmpdir'
require_relative '../shared_snapshot_storage_examples'

RSpec.describe Eidos::Storage::YamlFile::SnapshotStorage do
  let(:tmpdir) { Dir.mktmpdir('yaml_snapshot_test') }
  let(:entity_storage) { Eidos::Storage::YamlFile::EntityStorage.new(project_root: tmpdir) }
  let(:snapshot_storage) { described_class.new(entity_storage: entity_storage) }

  after { FileUtils.rm_rf(tmpdir) }

  it_behaves_like 'snapshot storage contract'
end
