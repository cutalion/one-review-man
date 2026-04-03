# frozen_string_literal: true

require 'spec_helper'
require 'eidos/storage/yaml_file/revision_storage'
require 'tmpdir'
require_relative '../shared_revision_storage_examples'

RSpec.describe Eidos::Storage::YamlFile::RevisionStorage do
  let(:tmpdir) { Dir.mktmpdir('yaml_revision_test') }
  let(:revision_storage) { described_class.new(revisions_path: tmpdir) }

  after { FileUtils.rm_rf(tmpdir) }

  it_behaves_like 'revision storage contract'
end
