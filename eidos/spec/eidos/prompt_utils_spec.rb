# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'eidos/prompt_utils'

RSpec.describe Eidos::PromptUtils do
  # T006 / US1 / feature 012-fix-ux-unify-bible.
  # When the characters list is empty, the character section of the template
  # is elided entirely and no placeholder warnings are emitted that mention
  # CHARACTER_NAME or CHARACTER_DESCRIPTION.

  describe '.build_prompt with empty characters list' do
    it 'strips {{#CHARACTER_SECTION}}...{{/CHARACTER_SECTION}} blocks when characters: is empty' do
      template = <<~TPL
        Story opens:
        {{#CHARACTER_SECTION}}Char: {{CHARACTER_NAME}} — {{CHARACTER_DESCRIPTION}}{{/CHARACTER_SECTION}}
        End.
      TPL

      result = described_class.build_prompt(template, {}, characters: [])

      expect(result).not_to include('CHARACTER_NAME')
      expect(result).not_to include('CHARACTER_DESCRIPTION')
      expect(result).to include('Story opens:')
      expect(result).to include('End.')
    end

    it 'keeps the character section when characters: has entries' do
      template = <<~TPL
        Story:
        {{#CHARACTER_SECTION}}- {{CHARACTER_NAME}}{{/CHARACTER_SECTION}}
      TPL

      result = described_class.build_prompt(
        template,
        { 'CHARACTER_NAME' => 'Jax' },
        characters: [{ 'name' => 'Jax' }]
      )

      expect(result).to include('Jax')
      expect(result).not_to include('{{#CHARACTER_SECTION}}')
      expect(result).not_to include('{{/CHARACTER_SECTION}}')
    end

    it 'does not warn about unused CHARACTER_NAME / CHARACTER_DESCRIPTION placeholders' do
      template = 'Plain template with {{CHAPTER_NUMBER}} only.'
      placeholders = {
        'CHAPTER_NUMBER' => '1',
        'CHARACTER_NAME' => '',
        'CHARACTER_DESCRIPTION' => ''
      }

      expect do
        described_class.build_prompt(template, placeholders, warn_unused: true)
      end.not_to output(/CHARACTER_NAME|CHARACTER_DESCRIPTION/).to_stderr
    end
  end
end
