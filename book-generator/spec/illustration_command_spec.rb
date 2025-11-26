# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tempfile'
require 'yaml'
require 'book/cli/version'

RSpec.describe 'book generate illustration command' do
  let(:cli_path) { File.expand_path('../bin/book', __dir__) }
  
  # Run each test in a fresh temporary directory
  around(:each) do |example|
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        example.run
      end
    end
  end

  def setup_book_structure
    FileUtils.mkdir_p('content/chapters')
    FileUtils.mkdir_p('data')
    
    # Create a sample chapter file
    chapter_content = <<~CHAPTER
      ---
      title: "Chapter 1: Test Chapter"
      ---
      
      # Chapter 1
      
      This is line 6.
      This is line 7.
      
      "This is a dialogue on line 9," said Character A.
      
      Character B responded with something interesting.
      
      More narrative description here.
      More content continues.
      
      The story goes on.
    CHAPTER
    
    File.write('content/chapters/001-chapter.md', chapter_content)
    
    # Create book metadata
    File.write('data/book_metadata.yml', "book:\n  current_chapter: 1\n")
    
    # Create settings
    settings = {
      'illustration' => {
        'provider' => 'openai',
        'model' => 'dall-e-3',
        'style' => 'comic book',
        'orientation' => 'landscape'
      }
    }
    File.write('data/settings.yml', settings.to_yaml)
  end

  context 'without book structure' do
    it 'fails when not in a book directory' do
      _, stderr, status = Open3.capture3('ruby', cli_path, 'generate', 'illustration', '--chapter', '1', '--content', '9:11')
      expect(status).not_to be_success
      expect(stderr).to include('book directory')
    end
  end

  context 'with book structure' do
    before { setup_book_structure }

    it 'validates content range format' do
      stdout, stderr, status = Open3.capture3('ruby', cli_path, 'generate', 'illustration', '--chapter', '1', '--content', 'invalid')
      expect(status).not_to be_success
      combined = stdout + stderr
      expect(combined).to include("must be in format 'START:END'")
    end

    it 'validates line range is within file bounds' do
      stdout, stderr, status = Open3.capture3('ruby', cli_path, 'generate', 'illustration', '--chapter', '1', '--content', '1:1000')
      expect(status).not_to be_success
      combined = stdout + stderr
      expect(combined).to include('Invalid line range')
    end

    it 'validates start line is before end line' do
      stdout, stderr, status = Open3.capture3('ruby', cli_path, 'generate', 'illustration', '--chapter', '1', '--content', '15:10')
      expect(status).not_to be_success
      combined = stdout + stderr
      expect(combined).to include('Invalid line range')
    end

    it 'fails when chapter file does not exist' do
      stdout, stderr, status = Open3.capture3('ruby', cli_path, 'generate', 'illustration', '--chapter', '99', '--content', '1:5')
      expect(status).not_to be_success
      combined = stdout + stderr
      expect(combined).to include('Chapter file not found')
    end

    it 'warns when anchor is outside content range' do
      stdout, stderr, status = Open3.capture3(
        { 'MOCK_AI' => 'true' },
        'ruby', cli_path, 'generate', 'illustration',
        '--chapter', '1', '--content', '9:11', '--anchor', '15'
      )
      
      # Should warn but not fail
      combined_output = stdout + stderr
      expect(combined_output).to include('Warning')
      expect(combined_output).to include('outside content range')
    end

    context 'with mock AI' do
      let(:env) { { 'MOCK_AI' => 'true' } }

      it 'extracts content from specified line range' do
        # We can't easily test the actual extraction without mocking the entire generator,
        # but we can verify the command runs successfully
        stdout, stderr, status = Open3.capture3(
          env,
          'ruby', cli_path, 'generate', 'illustration',
          '--chapter', '1', '--content', '9:11'
        )
        
        expect(status).to be_success
        expect(stderr).to be_empty
        expect(stdout).to include('Generating illustration')
      end

      it 'accepts additional prompt' do
        stdout, stderr, status = Open3.capture3(
          env,
          'ruby', cli_path, 'generate', 'illustration',
          '--chapter', '1', '--content', '9:11',
          '--prompt', 'dramatic lighting'
        )
        
        expect(status).to be_success
        expect(stderr).to be_empty
      end

      it 'accepts style override' do
        stdout, _stderr, status = Open3.capture3(
          env,
          'ruby', cli_path, 'generate', 'illustration',
          '--chapter', '1', '--content', '9:11',
          '--style', 'oil painting'
        )
        
        expect(status).to be_success
      end

      it 'accepts orientation override' do
        stdout, _stderr, status = Open3.capture3(
          env,
          'ruby', cli_path, 'generate', 'illustration',
          '--chapter', '1', '--content', '9:11',
          '--orientation', 'portrait'
        )
        
        expect(status).to be_success
      end

      it 'accepts provider and model overrides' do
        stdout, _stderr, status = Open3.capture3(
          env,
          'ruby', cli_path, 'generate', 'illustration',
          '--chapter', '1', '--content', '9:11',
          '--provider', 'openrouter',
          '--content-model', 'anthropic/claude-3-opus'
        )
        
        expect(status).to be_success
        expect(stdout).to include('Provider: openrouter')
        expect(stdout).to include('Model: anthropic/claude-3-opus')
      end

      it 'uses default anchor when not specified' do
        stdout, _stderr, status = Open3.capture3(
          env,
          'ruby', cli_path, 'generate', 'illustration',
          '--chapter', '1', '--content', '9:11'
        )
        
        expect(status).to be_success
      end

      it 'accepts custom anchor line' do
        stdout, _stderr, status = Open3.capture3(
          env,
          'ruby', cli_path, 'generate', 'illustration',
          '--chapter', '1', '--content', '9:11',
          '--anchor', '10'
        )
        
        expect(status).to be_success
      end
    end
  end
end
