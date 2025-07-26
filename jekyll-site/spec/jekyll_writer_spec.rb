require 'spec_helper'
require 'tmpdir'
require 'book/jekyll_writer'

RSpec.describe Book::JekyllWriter do
  let(:writer) { described_class.new }

  describe '#write_file' do
    it 'writes markdown file with YAML front-matter and body' do
      Dir.mktmpdir do |dir|
        file_path = File.join(dir, 'sample.md')
        front = { 'layout' => 'chapter', 'title' => 'Sample' }
        body  = 'Hello, world!'

        writer.write_file(file_path, front, body)

        content = File.read(file_path)
        expect(content).to start_with("---\n")
        expect(content).to include('layout: chapter')
        expect(content).to include('title: Sample')
        expect(content).to include(body)
      end
    end
  end

  describe '#write_character_page' do
    it 'creates a character page in _characters folder with correct data' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          slug = 'test_char'
          character_data = {
            'name' => 'Test Char',
            'description' => 'Just testing',
            'programming_skills' => 'Ruby',
            'first_appearance' => 'Chapter 1'
          }

          writer.write_character_page(slug, character_data)

          path = File.join(dir, '_characters', "#{slug}.md")
          expect(File).to exist(path)
          text = File.read(path)

          expect(text).to include('layout: character')
          expect(text).to include('Test Char')
          expect(text).to include('Just testing')
        end
      end
    end
  end

  describe 'update helpers' do
    it 'updates body while preserving front-matter' do
      Dir.mktmpdir do |dir|
        file = File.join(dir, 'file.md')
        front = { 'layout' => 'chapter', 'title' => 'Initial' }
        writer.write_file(file, front, 'Old body')

        writer.update_body(file, 'New body')

        text = File.read(file)
        expect(text).to include('title: Initial')
        expect(text).to include('New body')
        expect(text).not_to include('Old body')
      end
    end

    it 'merges front-matter changes when updating' do
      Dir.mktmpdir do |dir|
        file = File.join(dir, 'file.md')
        front = { 'layout' => 'chapter', 'title' => 'Old' }
        writer.write_file(file, front, 'Body')

        writer.update_front_matter_and_body(file, { 'title' => 'New' }, 'Body2')

        txt = File.read(file)
        expect(txt).to include('title: New')
        expect(txt).not_to include('title: Old')
        expect(txt).to include('Body2')
      end
    end
  end
end 
