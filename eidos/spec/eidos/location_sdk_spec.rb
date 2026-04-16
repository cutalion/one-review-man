# frozen_string_literal: true

require 'eidos/location'
require 'eidos/location_collection'
require 'eidos/bible'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Eidos::Location do
  let(:data) { { 'id' => 'server_room', 'name' => 'Server Room', 'description' => 'Cold and dark' } }
  let(:location) { Eidos::Location.new(data: data) }

  it 'exposes id, name, description' do
    expect(location.id).to eq('server_room')
    expect(location.name).to eq('Server Room')
    expect(location['description']).to eq('Cold and dark')
  end
end

RSpec.describe Eidos::LocationCollection do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      @world_path = tmpdir
      locs_dir = File.join(tmpdir, 'data', 'story_bible', 'locations')
      FileUtils.mkdir_p(locs_dir)
      bible_dir = File.join(tmpdir, 'data', 'story_bible')
      FileUtils.mkdir_p(File.join(bible_dir, 'characters'))
      File.write(File.join(bible_dir, 'facts.yml'), { 'events' => {} }.to_yaml)
      File.write(File.join(bible_dir, 'relationships.yml'), { 'relationships' => [] }.to_yaml)
      File.write(File.join(bible_dir, 'plot_threads.yml'), { 'plot_threads' => [] }.to_yaml)

      File.write(File.join(locs_dir, 'server_room.yml'), {
        'name' => 'Server Room', 'description' => 'Cold'
      }.to_yaml)
      File.write(File.join(locs_dir, 'office.yml'), {
        'name' => 'Office', 'description' => 'Open plan'
      }.to_yaml)

      example.run
    end
  end

  it 'enumerates locations' do
    bible = Eidos::Bible.new(world_path: @world_path)
    names = bible.locations.map(&:name)
    expect(names).to contain_exactly('Server Room', 'Office')
  end

  it 'accesses by id' do
    bible = Eidos::Bible.new(world_path: @world_path)
    loc = bible.locations['server_room']
    expect(loc.name).to eq('Server Room')
  end
end
