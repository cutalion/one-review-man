# frozen_string_literal: true

require_relative 'form'

module Eidos
  class FormNotFound < StandardError
    attr_reader :name, :available

    def initialize(name, available)
      @name = name
      @available = available
      super("Form '#{name}' not registered. Available forms in this world: #{available.sort.join(', ')}")
    end
  end

  # Merges built-in form definitions (shipped with the gem) and optional
  # world-local forms (under worlds/<name>/data/forms/) into the set of
  # forms available for one CLI invocation. Rebuilt per invocation — no
  # cross-invocation caching. See contracts/form-definition.md.
  class FormRegistry
    BUILTIN_DIR = File.expand_path('forms', __dir__)

    attr_reader :overrides

    def initialize(world_path: nil, builtin_dir: BUILTIN_DIR, world_forms_dir: nil)
      @world_path = world_path
      @builtin_dir = builtin_dir
      @world_forms_dir = world_forms_dir || (world_path && File.join(world_path, 'data', 'forms'))
      @forms = {}
      @overrides = {}
      load_builtins
      load_world_local if @world_forms_dir && Dir.exist?(@world_forms_dir)
    end

    def find(name)
      key = name.to_s
      return @forms[key] if @forms.key?(key)

      raise FormNotFound.new(key, @forms.keys)
    end

    def registered?(name)
      @forms.key?(name.to_s)
    end

    def each(&)
      @forms.values.each(&)
    end

    def list
      @forms.keys.sort
    end

    def categories
      @forms.values.map(&:category).uniq.sort
    end

    # True when a world-local form replaced a built-in with the same name.
    # Used by the CLI to print the override notice on first line of stdout
    # (FR-013, contracts/form-definition.md).
    def override?(name)
      !@overrides[name.to_s].nil?
    end

    private

    def load_builtins
      load_dir(@builtin_dir, origin: :builtin)
    end

    def load_world_local
      load_dir(@world_forms_dir, origin: :world_local, track_overrides: true)
    end

    def load_dir(dir, origin:, track_overrides: false)
      Dir.glob(File.join(dir, '*.yml')).each do |path|
        form = Form.from_file(path, origin: origin)
        next if form.nil?

        @overrides[form.name] = @forms[form.name] if track_overrides && @forms.key?(form.name)
        @forms[form.name] = form
      end
    end
  end
end
