# frozen_string_literal: true

require 'spec_helper'
require 'eidos/storage/memory/entity_storage'
require_relative '../shared_entity_storage_examples'

RSpec.describe Eidos::Storage::Memory::EntityStorage do
  let(:entity_storage) { described_class.new }

  it_behaves_like 'entity storage contract'
end
