# frozen_string_literal: true

require 'spec_helper'
require 'eidos/storage/memory/entity_storage'
require 'eidos/storage/memory/snapshot_storage'
require_relative '../shared_snapshot_storage_examples'

RSpec.describe Eidos::Storage::Memory::SnapshotStorage do
  let(:entity_storage) { Eidos::Storage::Memory::EntityStorage.new }
  let(:snapshot_storage) { described_class.new(entity_storage: entity_storage) }

  it_behaves_like 'snapshot storage contract'
end
