# frozen_string_literal: true

require 'eidos'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe 'SDK Integration' do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      @worlds_path = tmpdir
      @world_dir = File.join(tmpdir, 'my-world')
      setup_full_world(@world_dir)
      Eidos.configure { |c| c.worlds_path = tmpdir }
      example.run
      Eidos.reset_configuration!
    end
  end

  def setup_full_world(dir)
    FileUtils.mkdir_p(File.join(dir, 'data', 'story_bible', 'characters'))
    FileUtils.mkdir_p(File.join(dir, 'data', 'story_bible', 'locations'))
    FileUtils.mkdir_p(File.join(dir, 'data', 'story_bible', 'revisions'))
    FileUtils.mkdir_p(File.join(dir, 'data', 'story_bible', 'snapshots'))
    FileUtils.mkdir_p(File.join(dir, 'data', 'changesets'))
    FileUtils.mkdir_p(File.join(dir, 'content', 'chapters'))

    File.write(File.join(dir, 'data', 'world_config.yml'), {
      'localized' => { 'en' => { 'title' => 'My World', 'author' => 'Me', 'genre' => 'comedy' } }
    }.to_yaml)

    File.write(File.join(dir, 'data', 'world_state.yml'), {
      'world' => { 'current_chapter' => 2 }
    }.to_yaml)

    File.write(File.join(dir, 'content', 'chapters', '001-chapter.md'),
               "---\ntitle: First Chapter\nchapter_number: 1\n---\nHello world.")

    File.write(File.join(dir, 'content', 'chapters', '002-chapter.md'),
               "---\ntitle: Second Chapter\nchapter_number: 2\n---\nMore content.")

    File.write(File.join(dir, 'data', 'story_bible', 'characters', 'hero.yml'), {
      'name' => 'The Hero', 'role' => 'protagonist'
    }.to_yaml)

    File.write(File.join(dir, 'data', 'story_bible', 'locations', 'office.yml'), {
      'name' => 'The Office', 'description' => 'Where it all happens'
    }.to_yaml)

    File.write(File.join(dir, 'data', 'story_bible', 'facts.yml'), {}.to_yaml)
    File.write(File.join(dir, 'data', 'story_bible', 'relationships.yml'), { 'relationships' => [] }.to_yaml)
    File.write(File.join(dir, 'data', 'story_bible', 'plot_threads.yml'), { 'plot_threads' => [] }.to_yaml)
  end

  it 'provides the full SDK workflow' do
    # Find world by name
    world = Eidos::World.new('my-world')
    expect(world.name).to eq('my-world')

    # Status
    status = world.status
    expect(status[:title]).to eq('My World')
    expect(status[:chapters]).to eq(2)

    # Chapters
    expect(world.chapters.count).to eq(2)
    expect(world.chapters[1].title).to eq('First Chapter')
    expect(world.chapters.last.title).to eq('Second Chapter')

    # Bible - characters
    expect(world.bible.characters.count).to eq(1)
    hero = world.bible.characters['hero']
    expect(hero.name).to eq('The Hero')
    expect(hero.role).to eq('protagonist')

    # Bible - locations
    office = world.bible.locations['office']
    expect(office.name).to eq('The Office')

    # Canon
    expect(world.canon.current_branch).to eq('main')
    expect(world.canon.snapshots).to be_an(Array)
  end
end
