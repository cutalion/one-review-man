# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'eidos/form_registry'

# T025 / T026 — US2 / feature 014-storyworld-pivot.
#
# FormRegistry merges built-in forms (shipped with the gem) with world-local
# forms under `worlds/<name>/data/forms/`. World-local wins on name collision;
# unknown canon_context values cause the form to be skipped with a warning.
RSpec.describe Eidos::FormRegistry do
  let(:world_path) { Dir.mktmpdir('form_registry_spec') }
  let(:forms_dir)  { File.join(world_path, 'data', 'forms') }

  before { FileUtils.mkdir_p(forms_dir) }
  after  { FileUtils.rm_rf(world_path) }

  def write_form(yaml_name, yaml_body, template_name: nil, template_body: nil)
    File.write(File.join(forms_dir, yaml_name), yaml_body)
    return unless template_name

    File.write(File.join(forms_dir, template_name), template_body || "Template for #{template_name}\n{USER_PROMPT}\n{LENGTH_TARGET}\n{CANON_CONTEXT}\n")
  end

  describe 'world-local discovery (T025)' do
    it 'loads world-local forms on top of built-ins' do
      write_form(
        'novella.yml',
        <<~YAML,
          name: novella
          category: text
          default_length: 20000
          prompt_template_path: ./novella.prompt.txt
          canon_context:
            - all_characters
        YAML
        template_name: 'novella.prompt.txt'
      )

      registry = described_class.new(world_path: world_path)

      expect(registry.registered?('novella')).to be true
      expect(registry.registered?('haiku')).to be true # built-in still present
      expect(registry.find('novella').world_local?).to be true
      expect(registry.find('haiku').builtin?).to be true
    end

    it 'tracks overrides when a world-local form shadows a built-in' do
      write_form(
        'haiku.yml',
        <<~YAML,
          name: haiku
          category: text
          default_length: 5
          default_shape: "5 lines, tanka style"
          prompt_template_path: ./haiku.prompt.txt
          canon_context:
            - all_characters
        YAML
        template_name: 'haiku.prompt.txt'
      )

      registry = described_class.new(world_path: world_path)

      expect(registry.override?('haiku')).to be true
      expect(registry.find('haiku').world_local?).to be true
      expect(registry.find('haiku').default_length).to eq(5)
    end

    it 'does not mark override? when no shadowing occurs' do
      write_form(
        'novella.yml',
        <<~YAML,
          name: novella
          category: text
          default_length: 20000
          prompt_template_path: ./novella.prompt.txt
        YAML
        template_name: 'novella.prompt.txt'
      )

      registry = described_class.new(world_path: world_path)
      expect(registry.override?('novella')).to be false
    end
  end

  describe 'unknown canon_context (T026)' do
    it 'warns and skips the form rather than crashing' do
      write_form(
        'bogus.yml',
        <<~YAML,
          name: bogus
          category: text
          default_length: 10
          prompt_template_path: ./bogus.prompt.txt
          canon_context:
            - all_characters
            - fabricated_slice
        YAML
        template_name: 'bogus.prompt.txt'
      )

      registry = nil
      expect { registry = described_class.new(world_path: world_path) }
        .to output(/Unknown canon_context values/).to_stderr

      expect(registry.registered?('bogus')).to be false
      # Built-ins still load.
      expect(registry.registered?('haiku')).to be true
    end

    it 'does not crash when the template file is missing' do
      File.write(
        File.join(forms_dir, 'missing.yml'),
        <<~YAML
          name: missing
          category: text
          default_length: 10
          prompt_template_path: ./nonexistent.prompt.txt
        YAML
      )

      registry = nil
      expect { registry = described_class.new(world_path: world_path) }
        .to output(/prompt template not found/).to_stderr

      expect(registry.registered?('missing')).to be false
    end
  end

  describe 'registry listing' do
    it '#list includes all loaded form names, sorted' do
      registry = described_class.new(world_path: world_path)
      names = registry.list

      expect(names).to include('chapter', 'haiku', 'vignette', 'portrait')
      expect(names).to eq(names.sort)
    end
  end
end
