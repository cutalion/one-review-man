# frozen_string_literal: true

require 'eidos/canon'
require 'tmpdir'
require 'fileutils'
require 'yaml'

RSpec.describe Eidos::Canon do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      @world_path = tmpdir
      bible_dir = File.join(tmpdir, 'data', 'story_bible')
      FileUtils.mkdir_p(File.join(bible_dir, 'characters'))
      FileUtils.mkdir_p(File.join(bible_dir, 'locations'))
      FileUtils.mkdir_p(File.join(bible_dir, 'revisions'))
      FileUtils.mkdir_p(File.join(bible_dir, 'snapshots'))
      FileUtils.mkdir_p(File.join(tmpdir, 'data', 'changesets'))
      File.write(File.join(bible_dir, 'facts.yml'), { 'events' => {} }.to_yaml)
      File.write(File.join(bible_dir, 'relationships.yml'), { 'relationships' => [] }.to_yaml)
      File.write(File.join(bible_dir, 'plot_threads.yml'), { 'plot_threads' => [] }.to_yaml)

      example.run
    end
  end

  it 'exposes snapshots' do
    canon = Eidos::Canon.new(world_path: @world_path)
    expect(canon.snapshots).to be_an(Array)
  end

  it 'exposes branches' do
    canon = Eidos::Canon.new(world_path: @world_path)
    expect(canon.branches).to be_an(Array)
  end

  it 'reports current branch' do
    canon = Eidos::Canon.new(world_path: @world_path)
    expect(canon.current_branch).to eq('main')
  end
end
