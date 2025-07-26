# frozen_string_literal: true
require_relative 'mock_llm_service'

# Replace both legacy and core LLM services with the deterministic mock
Object.send(:remove_const, :LLMService) if defined?(::LLMService)
Object.const_set(:LLMService, MockLLMService)

module BookCore; end unless defined?(BookCore)
BookCore.send(:remove_const, :LLMService) if defined?(BookCore::LLMService)
BookCore.const_set(:LLMService, MockLLMService)
