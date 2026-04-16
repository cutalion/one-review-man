# frozen_string_literal: true

require 'eidos'
require 'eidos/world'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Eidos::World do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      @worlds_path = tmpdir
      @world_dir = File.join(tmpdir, 'test-world')
      setup_test_world(@world_dir)
      Eidos.configure { |c| c.worlds_path = tmpdir }
      example.run
      Eidos.reset_configuration!
    end
  end

  def setup_test_world(dir)
    FileUtils.mkdir_p(File.join(dir, 'data'))
    FileUtils.mkdir_p(File.join(dir, 'content', 'chapters'))

    File.write(File.join(dir, 'data', 'world_config.yml'), {
      'localized' => {
        'en' => {
          'title' => 'Test World',
          'author' => 'Test Author',
          'genre' => 'comedy'
        }
      }
    }.to_yaml)

    File.write(File.join(dir, 'data', 'world_state.yml'), {
      'world' => { 'current_chapter' => 3 }
    }.to_yaml)

    [1, 2, 3].each do |n|
      File.write(
        File.join(dir, 'content', 'chapters', format('%03d-chapter.md', n)),
        "---\ntitle: Chapter #{n}\nchapter_number: #{n}\n---\nContent of chapter #{n}."
      )
    end
  end

  describe '.new with name' do
    it 'finds a world by name in worlds_path' do
      world = Eidos::World.new('test-world')
      expect(world.name).to eq('test-world')
    end

    it 'raises if world not found' do
      expect { Eidos::World.new('nonexistent') }.to raise_error(Eidos::WorldNotFoundError)
    end
  end

  describe '.new with explicit path' do
    it 'accepts a full path' do
      world = Eidos::World.new(@world_dir)
      expect(world.name).to eq('test-world')
    end
  end

  describe '#status' do
    it 'returns a hash with world stats' do
      world = Eidos::World.new('test-world')
      status = world.status
      expect(status[:title]).to eq('Test World')
      expect(status[:author]).to eq('Test Author')
      expect(status[:chapters]).to eq(3)
    end
  end

  describe '#chapters' do
    it 'returns a ChapterCollection' do
      world = Eidos::World.new('test-world')
      expect(world.chapters).to be_a(Eidos::ChapterCollection)
      expect(world.chapters.count).to eq(3)
    end

    it 'accesses chapters by number' do
      world = Eidos::World.new('test-world')
      chapter = world.chapters[1]
      expect(chapter.title).to eq('Chapter 1')
    end
  end
end
