# frozen_string_literal: true

require 'eidos/character'

RSpec.describe Eidos::Character do
  let(:data) do
    {
      'id' => 'kenji_yamamoto',
      'name' => 'Kenji Yamamoto',
      'role' => 'senior dev',
      'traits' => ['perfectionist', 'humble']
    }
  end

  let(:character) { Eidos::Character.new(data: data) }

  it 'exposes id and name' do
    expect(character.id).to eq('kenji_yamamoto')
    expect(character.name).to eq('Kenji Yamamoto')
  end

  it 'exposes arbitrary attributes via []' do
    expect(character['role']).to eq('senior dev')
    expect(character['traits']).to eq(['perfectionist', 'humble'])
  end

  it 'exposes attributes via method_missing' do
    expect(character.role).to eq('senior dev')
  end

  it 'responds_to? for existing attributes' do
    expect(character.respond_to?(:role)).to be true
    expect(character.respond_to?(:nonexistent)).to be false
  end

  it 'returns data as a hash via to_h' do
    expect(character.to_h).to eq(data)
  end
end
