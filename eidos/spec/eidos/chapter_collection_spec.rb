# frozen_string_literal: true

require 'eidos/chapter_collection'
require 'tmpdir'
require 'fileutils'

RSpec.describe Eidos::ChapterCollection do
  around do |example|
    Dir.mktmpdir do |tmpdir|
      @chapters_dir = File.join(tmpdir, 'content', 'chapters')
      FileUtils.mkdir_p(@chapters_dir)

      [1, 2, 3].each do |n|
        File.write(
          File.join(@chapters_dir, format('%03d-chapter.md', n)),
          "---\ntitle: Chapter #{n}\nchapter_number: #{n}\nsummary: Summary #{n}\n---\nContent #{n}."
        )
      end

      File.write(
        File.join(@chapters_dir, '001-chapter.ru.md'),
        "---\ntitle: Glava 1\n---\nRussian content."
      )

      @collection = Eidos::ChapterCollection.new(world_path: tmpdir)
      example.run
    end
  end

  it 'is enumerable' do
    expect(@collection).to respond_to(:each)
    expect(@collection.count).to eq(3)
  end

  it 'returns chapters by index (1-based chapter number)' do
    chapter = @collection[2]
    expect(chapter).to be_a(Eidos::Chapter)
    expect(chapter.title).to eq('Chapter 2')
  end

  it 'returns nil for missing chapter' do
    expect(@collection[99]).to be_nil
  end

  it 'returns the last chapter' do
    expect(@collection.last.chapter_number).to eq(3)
  end

  it 'excludes translation files' do
    titles = @collection.map(&:title)
    expect(titles).not_to include('Glava 1')
  end
end
