# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'eidos/reset'

RSpec.describe Eidos::Reset do
  it 'uses the injected IO stream for prompts (non-blocking)' do
    input = StringIO.new("\n") # Simulate immediate newline (defaults to cancel)
    reset = described_class.new(io: input)

    # The method should exit cleanly without waiting for real user input.
    expect { reset.reset_characters }.not_to raise_error
  end
end
