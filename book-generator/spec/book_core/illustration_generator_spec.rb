# frozen_string_literal: true

require 'spec_helper'
require 'book_core/illustration_generator'
require 'book_core/book_config'
require 'openai'
require 'down'

RSpec.describe BookCore::IllustrationGenerator do
  let(:project_root) { Dir.mktmpdir }
  let(:client) { instance_double(OpenAI::Client) }
  let(:images) { instance_double(OpenAI::Client::Images) }
  let(:config) { BookCore::BookConfig.new }

  subject(:generator) { described_class.new(client: client, project_root: project_root, config: config) }

  before do
    allow(client).to receive(:images).and_return(images)
    allow(Down).to receive(:download).and_return(StringIO.new('image data'))
  end

  after do
    FileUtils.rm_rf(project_root)
  end

  describe '#generate' do
    let(:prompt) { 'a test prompt' }
    let(:chapter_number) { 1 }
    let(:image_response) do
      {
        'data' => [
          { 'url' => 'http://example.com/image.png' }
        ]
      }
    end

    before do
      allow(images).to receive(:generate).and_return(image_response)
      chapter_dir = File.join(project_root, 'content', 'chapters')
      FileUtils.mkdir_p(chapter_dir)
      File.write(File.join(chapter_dir, '001-chapter.md'), 'This is a chapter with anchor text.')
    end

    context 'when an anchor is provided' do
      it 'embeds the illustration in the chapter file' do
        generator.generate(prompt: prompt, chapter_number: chapter_number, anchor_text: 'anchor text')

        chapter_path = File.join(project_root, 'content', 'chapters', '001-chapter.md')
        content = File.read(chapter_path)
        expect(content).to include("anchor text\n\n![[illustration:")
      end
    end

    context 'when an anchor is not provided' do
      it 'prints the markdown tag to the console' do
        expect { generator.generate(prompt: prompt, chapter_number: chapter_number) }.to output(/!\[\[illustration:/).to_stdout
      end
    end

    it 'uses the configured model' do
      config.set('llm.task_options.illustration.model', 'dall-e-4')
      expect(images).to receive(:generate).with(hash_including(parameters: hash_including(model: 'dall-e-4')))
      generator.generate(prompt: prompt, chapter_number: chapter_number)
    end
  end
end
