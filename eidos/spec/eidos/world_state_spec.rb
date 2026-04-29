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

    it 'does not log a migration line when the field is already present' do
      write_state({ 'canon' => { 'revision' => 0 } })

      output = capture_stderr { described_class.new(world_path: tmp_dir).current_revision }

      expect(output).not_to include('Migrating')
    end
  end

  describe '#current_revision (in-place migration)' do
    it 'migrates and returns count(canon_deltas/*.yml) when canon.revision is missing' do
      write_state({ 'world' => { 'name' => 'whatever' } }) # no canon mapping
      FileUtils.mkdir_p(deltas_dir)
      5.times { |i| File.write(File.join(deltas_dir, "delta-#{i}.yml"), "---\nid: x#{i}\n") }

      output = capture_stderr do
        expect(described_class.new(world_path: tmp_dir).current_revision).to eq(5)
      end

      reloaded = YAML.safe_load_file(state_path)
      expect(reloaded.dig('canon', 'revision')).to eq(5)
      expect(output).to include("Migrating #{state_path}")
      expect(output).to include('canon.revision = 5')
    end

    it 'returns 0 (and migrates) when data/canon_deltas/ exists but is empty' do
      write_state({ 'world' => { 'name' => 'x' } })
      FileUtils.mkdir_p(deltas_dir)

      capture_stderr do
        expect(described_class.new(world_path: tmp_dir).current_revision).to eq(0)
      end

      reloaded = YAML.safe_load_file(state_path)
      expect(reloaded.dig('canon', 'revision')).to eq(0)
    end

    it 'raises CorruptWorldError when data/canon_deltas/ does not exist' do
      write_state({ 'world' => { 'name' => 'x' } })
      # do NOT create deltas_dir
      original = File.read(state_path)

      expect { described_class.new(world_path: tmp_dir).current_revision }
        .to raise_error(Eidos::WorldState::CorruptWorldError, /canon_deltas/)

      # Atomic — migration aborted, file unchanged.
      expect(File.read(state_path)).to eq(original)
    end

    it 'is idempotent — second call reads the persisted field with no log line' do
      write_state({ 'world' => { 'name' => 'x' } })
      FileUtils.mkdir_p(deltas_dir)
      File.write(File.join(deltas_dir, 'delta-1.yml'), "---\nid: x\n")

      ws = described_class.new(world_path: tmp_dir)
      capture_stderr { ws.current_revision } # first call migrates

      ws2 = described_class.new(world_path: tmp_dir)
      output2 = capture_stderr { expect(ws2.current_revision).to eq(1) }
      expect(output2).not_to include('Migrating')
    end
  end

  describe '#current_revision (corrupt-world signals)' do
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
