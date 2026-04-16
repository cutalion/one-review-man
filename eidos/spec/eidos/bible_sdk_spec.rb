# frozen_string_literal: true

require 'eidos/bible'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Eidos::Bible do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      @world_path = tmpdir
      setup_story_bible(tmpdir)
      example.run
    end
  end

  def setup_story_bible(dir)
    bible_dir = File.join(dir, 'data', 'story_bible')
    chars_dir = File.join(bible_dir, 'characters')
    locs_dir = File.join(bible_dir, 'locations')
    FileUtils.mkdir_p(chars_dir)
    FileUtils.mkdir_p(locs_dir)

    File.write(File.join(chars_dir, 'kenji_yamamoto.yml'), {
      'name' => 'Kenji Yamamoto',
      'role' => 'senior dev'
    }.to_yaml)

    File.write(File.join(chars_dir, 'kai_nakamura.yml'), {
      'name' => 'Kai Nakamura',
      'role' => 'junior dev'
    }.to_yaml)

    File.write(File.join(locs_dir, 'server_room.yml'), {
      'name' => 'Server Room',
      'description' => 'A cold, dark place'
    }.to_yaml)

    File.write(File.join(bible_dir, 'facts.yml'), { 'events' => {} }.to_yaml)
    File.write(File.join(bible_dir, 'relationships.yml'), { 'relationships' => [] }.to_yaml)
    File.write(File.join(bible_dir, 'plot_threads.yml'), { 'plot_threads' => [] }.to_yaml)
  end

  describe '#characters' do
    it 'returns a CharacterCollection' do
      bible = Eidos::Bible.new(world_path: @world_path)
      expect(bible.characters).to be_a(Eidos::CharacterCollection)
    end

    it 'accesses characters by id' do
      bible = Eidos::Bible.new(world_path: @world_path)
      kenji = bible.characters['kenji_yamamoto']
      expect(kenji).to be_a(Eidos::Character)
      expect(kenji.name).to eq('Kenji Yamamoto')
    end

    it 'enumerates characters' do
      bible = Eidos::Bible.new(world_path: @world_path)
      names = bible.characters.map(&:name)
      expect(names).to contain_exactly('Kenji Yamamoto', 'Kai Nakamura')
    end
  end

  describe '#search' do
    it 'searches facts by keyword' do
      bible = Eidos::Bible.new(world_path: @world_path)
      results = bible.search('server')
      expect(results).to be_an(Array)
    end
  end
end
