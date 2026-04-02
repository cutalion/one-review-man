# frozen_string_literal: true

require 'spec_helper'
require 'eidos/writer_agent'
require 'eidos/llm_service'
require 'eidos/story_bible'

RSpec.describe Eidos::WriterAgent do
  let(:test_dir) { File.join(Dir.tmpdir, "writer_agent_test_#{SecureRandom.hex(4)}") }
  let(:chapters_dir) { File.join(test_dir, 'content', 'chapters') }
  let(:data_dir) { File.join(test_dir, 'data') }

  # Mock LLM service
  let(:llm_service) do
    instance_double(Eidos::LLMService).tap do |service|
      allow(service).to receive(:instance_variable_get).with(:@settings).and_return({
        'agent' => {
          'provider' => 'openrouter',
          'model' => 'google/gemini-3-flash-preview',
          'max_completion_tokens' => 8000
        }
      })
      allow(service).to receive(:get_provider_for_task).and_return('openrouter')
      allow(service).to receive(:get_client).and_return(nil)
    end
  end

  # Mock Story Bible
  let(:story_bible) do
    instance_double(Eidos::StoryBible).tap do |bible|
      allow(bible).to receive(:get_character).and_return({ 'name' => 'Test Character' })
      allow(bible).to receive(:list_characters).and_return([{ 'id' => 'test', 'name' => 'Test' }])
      allow(bible).to receive(:locations).and_return({})
      allow(bible).to receive(:active_plot_threads).and_return([])
      allow(bible).to receive(:world_rules).and_return({})
      allow(bible).to receive(:search_facts).and_return([])
      allow(bible).to receive(:get_relationships_for).and_return([])
    end
  end

  before do
    FileUtils.mkdir_p(chapters_dir)
    FileUtils.mkdir_p(data_dir)
    
    # Create minimal config files
    File.write(File.join(data_dir, 'world_config.yml'), {
      'localized' => { 'en' => { 'title' => 'Test Book' } }
    }.to_yaml)
    
    File.write(File.join(data_dir, 'story_bible.yml'), {
      'characters' => {},
      'locations' => {},
      'facts' => {}
    }.to_yaml)
  end

  after do
    FileUtils.rm_rf(test_dir)
  end

  describe '#initialize' do
    it 'accepts required parameters' do
      agent = described_class.new(
        llm_service: llm_service,
        story_bible: story_bible,
        project_root: test_dir
      )
      
      expect(agent).to be_a(described_class)
    end

    it 'uses default debug setting' do
      agent = described_class.new(
        llm_service: llm_service,
        story_bible: story_bible,
        project_root: test_dir
      )
      
      # Agent should initialize without error
      expect(agent.chapter_result).to be_nil
    end
  end

  describe '#generate_chapter' do
    context 'in MOCK_AI mode' do
      before do
        allow(Eidos::EnvUtils).to receive(:mock_ai_enabled?).and_return(true)
      end

      it 'returns mock chapter data' do
        agent = described_class.new(
          llm_service: llm_service,
          story_bible: story_bible,
          project_root: test_dir
        )
        
        result = agent.generate_chapter(5)
        
        expect(result).to be_a(Hash)
        expect(result['title']).to eq('Mock Chapter 5')
        expect(result['content']).to include('mock content')
        expect(result['summary']).to include('Mock summary')
        expect(result['characters_featured']).to eq(['kenji_yamamoto'])
      end

      it 'includes chapter number in mock data' do
        agent = described_class.new(
          llm_service: llm_service,
          story_bible: story_bible,
          project_root: test_dir
        )
        
        result = agent.generate_chapter(42)
        
        expect(result['title']).to eq('Mock Chapter 42')
        expect(result['summary']).to include('42')
      end
    end
  end

  describe '#tool_calls_log' do
    it 'returns empty array initially' do
      agent = described_class.new(
        llm_service: llm_service,
        story_bible: story_bible,
        project_root: test_dir
      )
      
      expect(agent.tool_calls_log).to eq([])
    end

    it 'returns a copy to prevent external modification' do
      agent = described_class.new(
        llm_service: llm_service,
        story_bible: story_bible,
        project_root: test_dir
      )
      
      log = agent.tool_calls_log
      log << { test: true }
      
      expect(agent.tool_calls_log).to eq([])
    end
  end

  describe 'DEFAULT_MODEL' do
    it 'is set to gemini-3-flash-preview' do
      expect(described_class::DEFAULT_MODEL).to eq('google/gemini-3-flash-preview')
    end
  end

  describe 'MAX_ITERATIONS' do
    it 'has a reasonable limit' do
      expect(described_class::MAX_ITERATIONS).to be_between(10, 50)
    end
  end
end
