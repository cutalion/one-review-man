# frozen_string_literal: true

# Thin wrapper that exposes the Jekyll Adapter via the canonical
# `book_generator/` namespace.  It loads the underlying implementation from
# BookCore to avoid code duplication at this stage of the extraction.

require 'book_core/jekyll_adapter'

module BookGenerator
  # Temporary thin wrapper delegating to the existing BookCore::JekyllAdapter.
  # During later phases we will move the full implementation here and rename
  # modules appropriately. This file allows external code to `require
  # 'book_generator/jekyll_adapter'` while preserving zero-breakage behaviour.
  class JekyllAdapter < BookCore::JekyllAdapter
  end
end 
