# frozen_string_literal: true

require 'eidos/version'

RSpec.describe 'Eidos::VERSION' do
  it 'is a string in semver format' do
    expect(Eidos::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
