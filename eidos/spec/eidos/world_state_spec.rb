# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'eidos/world_state'

# Feature 018a — US2: the canon revision counter.
#
# Verifies the `Eidos::WorldState` contract from
# `specs/018-unify-piece-producer/contracts/world-state-migration.md`.
RSpec.describe Eidos::WorldState do
  let(:tmp_dir) { Dir.mktmpdir('world_state_spec') }
  let(:data_dir) { File.join(tmp_dir, 'data') }
  let(:state_path) { File.join(data_dir, 'world_state.yml') }
  let(:deltas_dir) { File.join(data_dir, 'canon_deltas') }

  before { FileUtils.mkdir_p(data_dir) }
  after  { FileUtils.rm_rf(tmp_dir) }

  def write_state(hash)
    File.write(state_path, hash.to_yaml)
  end

  describe '#current_revision (already-present field)' do
    it 'reads canon.revision from world_state.yml when present' do
      write_state({ 'canon' => { 'revision' => 42 } })

      ws = described_class.new(world_path: tmp_dir)

      output = capture_stderr { expect(ws.current_revision).to eq(42) }
      expect(output).to be_empty
    end

    it 'does not write to stderr when the field is already present' do
      write_state({ 'canon' => { 'revision' => 0 } })

      output = capture_stderr { described_class.new(world_path: tmp_dir).current_revision }

      expect(output).to be_empty
    end
  end

  describe '#current_revision (corrupt-world signals)' do
    # 018c retired FR-006a's in-place migration. Missing canon.revision
    # is now a corrupt-world signal — there's no auto-recovery path; an
    # affected world must be migrated explicitly via
    # `specs/018c-orm-migration/migrate.rb` or equivalent.
    it 'raises CorruptWorldError when canon.revision is missing' do
      write_state({ 'world' => { 'name' => 'whatever' } }) # no canon mapping

      expect { described_class.new(world_path: tmp_dir).current_revision }
        .to raise_error(Eidos::WorldState::CorruptWorldError, /canon\.revision missing/)
    end

    it 'raises CorruptWorldError when canon mapping is present but canon.revision is missing' do
      write_state({ 'canon' => { 'something_else' => true } })

      expect { described_class.new(world_path: tmp_dir).current_revision }
        .to raise_error(Eidos::WorldState::CorruptWorldError, /canon\.revision missing/)
    end

    it 'raises CorruptWorldError when world_state.yml is missing' do
      # data/ exists but world_state.yml does not.
      expect { described_class.new(world_path: tmp_dir).current_revision }
        .to raise_error(Eidos::WorldState::CorruptWorldError, /world_state\.yml/)
    end

    it 'raises CorruptWorldError when canon.revision is a non-integer' do
      write_state({ 'canon' => { 'revision' => 'seventeen' } })

      expect { described_class.new(world_path: tmp_dir).current_revision }
        .to raise_error(Eidos::WorldState::CorruptWorldError, /seventeen|non-integer|integer/i)
    end

    it 'raises CorruptWorldError when canon.revision is negative' do
      write_state({ 'canon' => { 'revision' => -1 } })

      expect { described_class.new(world_path: tmp_dir).current_revision }
        .to raise_error(Eidos::WorldState::CorruptWorldError, /-1|negative/i)
    end
  end

  describe '#advance_revision!' do
    it 'increments by exactly 1 and returns the new value' do
      write_state({ 'canon' => { 'revision' => 7 } })

      ws = described_class.new(world_path: tmp_dir)
      expect(ws.advance_revision!).to eq(8)

      reloaded = YAML.safe_load_file(state_path)
      expect(reloaded.dig('canon', 'revision')).to eq(8)
    end

    it 'is atomic — partial-write failure leaves the previous value' do
      write_state({ 'canon' => { 'revision' => 7 } })

      ws = described_class.new(world_path: tmp_dir)
      allow(File).to receive(:rename).and_raise(Errno::EACCES.new('boom'))

      expect { ws.advance_revision! }.to raise_error(Errno::EACCES)

      reloaded = YAML.safe_load_file(state_path)
      expect(reloaded.dig('canon', 'revision')).to eq(7)
    end

    it 'preserves other top-level keys in world_state.yml' do
      write_state({
                    'canon' => { 'revision' => 0 },
                    'world' => { 'current_chapter' => 0 },
                    'status' => { 'last_generated' => '' }
                  })

      ws = described_class.new(world_path: tmp_dir)
      ws.advance_revision!

      reloaded = YAML.safe_load_file(state_path)
      expect(reloaded.dig('canon', 'revision')).to eq(1)
      expect(reloaded['world']).to eq({ 'current_chapter' => 0 })
      expect(reloaded['status']).to eq({ 'last_generated' => '' })
    end
  end

  def capture_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original
  end
end
