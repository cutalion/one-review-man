# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'yaml'
require_relative '../lib/book_core/jekyll_adapter'

RSpec.describe BookCore::JekyllAdapter do
  let(:tmpdir) { Dir.mktmpdir('jekyll_adapter_test') }
  let(:adapter) { described_class.new }

  before { adapter.setup_project(tmpdir) }
  after { FileUtils.rm_rf(tmpdir) }

  describe '#setup_project' do
    it 'creates _layouts and _includes directories' do
      expect(Dir.exist?(File.join(tmpdir, '_layouts'))).to be true
      expect(Dir.exist?(File.join(tmpdir, '_includes'))).to be true
    end
  end

  describe '#write_chapter' do
    it 'writes a chapter file with front matter and content' do
      adapter.write_chapter(1, 'Chapter content here', { title: 'Test Chapter' })
      path = File.join(tmpdir, '_chapters', '001-chapter.md')

      expect(File.exist?(path)).to be true
      content = File.read(path)
      expect(content).to include('title: Test Chapter')
      expect(content).to include('layout: chapter')
      expect(content).to include('Chapter content here')
    end
  end

  describe '#write_character_page' do
    it 'writes a character page with front matter and body sections' do
      character_data = {
        'name' => 'Kenji Yamamoto',
        'slug' => 'kenji_yamamoto',
        'description' => 'A senior developer',
        'personality_traits' => %w[diligent focused],
        'programming_skills' => 'Ruby, Go',
        'first_appearance' => 'Chapter 1',
        'backstory' => 'Worked at BigCorp for 10 years',
        'catchphrase' => 'Ship it!'
      }

      adapter.send(:write_character_page, 'kenji_yamamoto', character_data)
      path = File.join(tmpdir, '_characters', 'kenji_yamamoto.md')

      expect(File.exist?(path)).to be true
      content = File.read(path)
      expect(content).to include('name: Kenji Yamamoto')
      expect(content).to include('layout: character')
      expect(content).to include('/characters/kenji-yamamoto/')
      expect(content).to include('## About Kenji Yamamoto')
      expect(content).to include('## Backstory')
      expect(content).to include('## Catchphrase')
    end
  end

  describe 'complete site from book with chapters and characters' do
    it 'produces a site directory with chapters and character collections' do
      # Write multiple chapters
      adapter.write_chapter(1, 'First chapter content', { title: 'The Beginning' })
      adapter.write_chapter(2, 'Second chapter content', { title: 'The Middle' })

      # Write a character
      adapter.send(:write_character_page, 'test_char', {
        'name' => 'Test Character',
        'slug' => 'test_char',
        'description' => 'A test character',
        'first_appearance' => 'Chapter 1'
      })

      # Verify chapters exist
      chapters = Dir.glob(File.join(tmpdir, '_chapters', '*.md'))
      expect(chapters.length).to eq(2)

      # Verify character exists
      characters = Dir.glob(File.join(tmpdir, '_characters', '*.md'))
      expect(characters.length).to eq(1)

      # Verify front matter is valid YAML
      chapters.each do |chapter_path|
        content = File.read(chapter_path)
        parts = content.split(/^---\s*$/, 3)
        expect(parts.length).to eq(3)
        front_matter = YAML.safe_load(parts[1], permitted_classes: [Symbol])
        expect(front_matter).to be_a(Hash)
        expect(front_matter['layout']).to eq('chapter')
      end
    end
  end
end
