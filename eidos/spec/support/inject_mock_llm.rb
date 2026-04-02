# frozen_string_literal: true

require_relative 'mock_llm_service'

# Replace both legacy and core LLM services with the deterministic mock
Object.send(:remove_const, :LLMService) if defined?(LLMService)
Object.const_set(:LLMService, MockLLMService)

module Eidos; end unless defined?(Eidos)
Eidos.send(:remove_const, :LLMService) if defined?(Eidos::LLMService)
Eidos.const_set(:LLMService, MockLLMService)

# Prevent the real LLMService from being loaded and overwriting the mock
$LOADED_FEATURES << File.expand_path('../../lib/eidos/llm_service.rb', __dir__)
$LOADED_FEATURES << 'eidos/llm_service.rb'
