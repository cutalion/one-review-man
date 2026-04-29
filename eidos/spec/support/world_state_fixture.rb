# frozen_string_literal: true

# Test helper: scaffold the minimum world-state fixture that post-018a
# `Eidos::WorldState#current_revision` requires (data/world_state.yml with
# canon.revision + an empty data/canon_deltas/ directory).
#
# Specs that exercise `PieceProducer#produce` MUST call this on their
# tmp_dir BEFORE the producer runs — otherwise `WorldState` raises
# `CorruptWorldError` (correctly: per the FR-006 contract, missing
# `world_state.yml` is a corruption signal, not a silent default).
require 'fileutils'
require 'yaml'

module WorldStateFixture
  def scaffold_world_state(world_path, revision: 0)
    FileUtils.mkdir_p(File.join(world_path, 'data', 'canon_deltas'))
    File.write(
      File.join(world_path, 'data', 'world_state.yml'),
      { 'canon' => { 'revision' => revision } }.to_yaml
    )
  end
end

RSpec.configure do |config|
  config.include WorldStateFixture
end
