# frozen_string_literal: true

require 'spec_helper'
require 'eidos/agent_tools/story_bible_tools'

RSpec.describe Eidos::AgentTools::StoryBibleTools do
  describe '.definitions' do
    let(:definitions) { described_class.definitions }

    it 'returns an array of tool definitions' do
      expect(definitions).to be_an(Array)
      expect(definitions).not_to be_empty
    end

    it 'includes all expected tools' do
      tool_names = definitions.map { |d| d[:function][:name] }
      
      expect(tool_names).to include(
        'get_character',
        'list_characters',
        'get_location',
        'list_locations',
        'get_chapter_summaries',
        'get_plot_threads',
        'get_world_rules',
        'search_facts',
        'get_relationships',
        'submit_chapter'
      )
    end

    it 'has 10 tools total' do
      expect(definitions.length).to eq(10)
    end

    describe 'tool structure' do
      it 'each tool has type and function' do
        definitions.each do |tool|
          expect(tool).to have_key(:type)
          expect(tool[:type]).to eq('function')
          expect(tool).to have_key(:function)
        end
      end

      it 'each function has name, description, and parameters' do
        definitions.each do |tool|
          func = tool[:function]
          expect(func).to have_key(:name)
          expect(func).to have_key(:description)
          expect(func).to have_key(:parameters)
        end
      end
    end

    describe 'submit_chapter tool' do
      let(:submit_tool) { definitions.find { |d| d[:function][:name] == 'submit_chapter' } }

      it 'requires title, content, and summary' do
        required = submit_tool[:function][:parameters][:required]
        expect(required).to include('title', 'content', 'summary')
      end

      it 'has properties for new_characters and new_facts' do
        props = submit_tool[:function][:parameters][:properties]
        expect(props).to have_key(:new_characters)
        expect(props).to have_key(:new_facts)
        expect(props).to have_key(:characters_featured)
      end
    end

    describe 'get_character tool' do
      let(:get_char_tool) { definitions.find { |d| d[:function][:name] == 'get_character' } }

      it 'requires id parameter' do
        required = get_char_tool[:function][:parameters][:required]
        expect(required).to eq(['id'])
      end
    end

    describe 'search_facts tool' do
      let(:search_tool) { definitions.find { |d| d[:function][:name] == 'search_facts' } }

      it 'requires query parameter' do
        required = search_tool[:function][:parameters][:required]
        expect(required).to eq(['query'])
      end
    end
  end

  describe '.for_api' do
    let(:api_definitions) { described_class.for_api }

    it 'converts symbol keys to strings in function' do
      api_definitions.each do |tool|
        expect(tool[:function].keys).to all(be_a(String))
      end
    end

    it 'preserves tool type' do
      api_definitions.each do |tool|
        expect(tool[:type]).to eq('function')
      end
    end

    it 'returns same number of tools as definitions' do
      expect(api_definitions.length).to eq(described_class.definitions.length)
    end
  end
end
