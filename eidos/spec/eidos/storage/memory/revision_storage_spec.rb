# frozen_string_literal: true

require 'spec_helper'
require 'eidos/storage/memory/revision_storage'
require_relative '../shared_revision_storage_examples'

RSpec.describe Eidos::Storage::Memory::RevisionStorage do
  let(:revision_storage) { described_class.new }

  it_behaves_like 'revision storage contract'
end
