# frozen_string_literal: true

require 'yaml'
require 'date'
require_relative 'yaml_file/entity_storage'
require_relative 'yaml_file/revision_storage'
require_relative 'yaml_file/snapshot_storage'
require_relative 'memory/entity_storage'
require_relative 'memory/revision_storage'
require_relative 'memory/snapshot_storage'

module Eidos
  module Storage
    # Reads storage configuration and returns appropriate adapter instances.
    class Factory
      BACKENDS = {}.freeze

      class << self
        def register(name, entity_class:, revision_class:, snapshot_class:)
          validate_contract!(entity_class, EntityStorage, 'EntityStorage')
          validate_contract!(revision_class, RevisionStorage, 'RevisionStorage')
          validate_contract!(snapshot_class, SnapshotStorage, 'SnapshotStorage')

          @backends ||= {}
          @backends[name.to_s] = {
            entity: entity_class,
            revision: revision_class,
            snapshot: snapshot_class
          }
        end

        def backends
          @backends ||= {}
        end

        def build_entity_storage(backend_name, **opts)
          classes = resolve_backend(backend_name)
          classes[:entity].new(**opts)
        end

        def build_revision_storage(backend_name, **opts)
          classes = resolve_backend(backend_name)
          classes[:revision].new(**opts)
        end

        def build_snapshot_storage(backend_name, entity_storage:, **opts)
          classes = resolve_backend(backend_name)
          classes[:snapshot].new(entity_storage: entity_storage, **opts)
        end

        def backend_name_from_config(project_root)
          settings_path = File.join(project_root, 'data', 'settings.yml')
          return 'yaml_file' unless File.exist?(settings_path)

          settings = YAML.safe_load(File.read(settings_path), permitted_classes: [Date, Time]) || {}
          storage_config = settings['storage'] || {}
          storage_config['backend'] || 'yaml_file'
        end

        def available_backends
          (@backends || {}).keys
        end

        private

        def resolve_backend(name)
          backend = (@backends || {})[name.to_s]
          return backend if backend

          available = available_backends.join(', ')
          raise ArgumentError,
                "Unknown storage backend '#{name}'. Available backends: #{available}"
        end

        def validate_contract!(klass, contract_module, contract_name)
          unless klass.ancestors.include?(contract_module)
            raise ArgumentError,
                  "#{klass} must include #{contract_name} contract module (Eidos::Storage::#{contract_name})"
          end

          missing = contract_module::REQUIRED_METHODS.reject do |method|
            klass.method_defined?(method) || klass.private_method_defined?(method)
          end

          return if missing.empty?

          raise ArgumentError,
                "#{klass} does not fully implement #{contract_name}. " \
                "Missing methods: #{missing.join(', ')}"
        end
      end
    end

    # Register built-in backends
    Factory.register('yaml_file',
                     entity_class: YamlFile::EntityStorage,
                     revision_class: YamlFile::RevisionStorage,
                     snapshot_class: YamlFile::SnapshotStorage)

    Factory.register('memory',
                     entity_class: Memory::EntityStorage,
                     revision_class: Memory::RevisionStorage,
                     snapshot_class: Memory::SnapshotStorage)
  end
end
