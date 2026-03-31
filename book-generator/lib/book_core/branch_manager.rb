# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'time'
require_relative 'models/branch'
require_relative 'models/conflict'

module BookCore
  # Creates, compares, merges, and manages branch lifecycle.
  class BranchManager
    ENTITY_DIRS = %w[characters locations].freeze
    ENTITY_FILES = %w[facts.yml relationships.yml plot_threads.yml].freeze

    attr_reader :story_bible_path

    def initialize(story_bible_path:, revision_store:, diff_engine:)
      @story_bible_path = File.expand_path(story_bible_path)
      @revision_store = revision_store
      @diff_engine = diff_engine
      @branches_path = File.join(@story_bible_path, 'branches')
      @index_path = File.join(@branches_path, '_index.yml')
      @state_path = File.join(@story_bible_path, '_branch_state.yml')
    end

    # Create a branch from current state or a specific point.
    # @return [Models::Branch]
    def create(name:, from_branch: 'main', at_revision: nil, description: nil)
      FileUtils.mkdir_p(@branches_path)

      index = load_index
      raise "Branch '#{name}' already exists" if index.any? { |b| b.name == name }

      source_path = branch_data_path(from_branch)
      dest_path = File.join(@branches_path, name)

      FileUtils.mkdir_p(dest_path)
      copy_canon_data(source_path, dest_path)

      branch = Models::Branch.new(
        name: name,
        parent_branch: from_branch,
        created_at: Time.now.iso8601,
        created_from: { 'branch' => from_branch, 'revision' => at_revision },
        status: 'active',
        description: description
      )

      index << branch
      save_index(index)

      branch
    end

    # List branches.
    # @return [Array<Models::Branch>]
    def list(include_archived: false)
      index = load_index
      return index if include_archived

      index.select(&:active?)
    end

    # Get current branch name.
    # @return [String]
    def current_branch
      return 'main' unless File.exist?(@state_path)

      state = YAML.safe_load(File.read(@state_path), permitted_classes: [Date, Time]) || {}
      state['current_branch'] || 'main'
    end

    # Switch branch context.
    # @return [Models::Branch]
    def checkout(name)
      if name == 'main'
        save_state('main')
        return Models::Branch.new(name: 'main', status: 'active', parent_branch: nil)
      end

      branch = find_branch(name)
      raise "Branch '#{name}' not found" unless branch
      raise "Branch '#{name}' is archived" if branch.archived?

      save_state(name)
      branch
    end

    # Compare two branches.
    # @return [Hash] { only_in_a:, only_in_b:, conflicts:, identical: }
    def compare(branch_a, branch_b)
      entities_a = load_all_entities(branch_a)
      entities_b = load_all_entities(branch_b)

      all_keys = (entities_a.keys + entities_b.keys).uniq
      only_in_a = []
      only_in_b = []
      conflicts = []
      identical = []

      all_keys.each do |key|
        a_data = entities_a[key]
        b_data = entities_b[key]

        if a_data && !b_data
          only_in_a << key
        elsif !a_data && b_data
          only_in_b << key
        elsif a_data == b_data
          identical << key
        else
          diffs = @diff_engine.diff(a_data, b_data)
          if diffs.empty?
            identical << key
          else
            conflicts << { entity: key, diffs: diffs }
          end
        end
      end

      { only_in_a: only_in_a, only_in_b: only_in_b,
        conflicts: conflicts, identical: identical }
    end

    # Merge source branch into target branch.
    # @return [Hash] { auto_merged:, conflicts: }
    def merge(source:, target:, resolutions: {})
      target_path = branch_data_path(target)
      source_entities = load_all_entities(source)
      target_entities = load_all_entities(target)

      # Find common ancestor (simplified: use target as base)
      # In a full implementation we'd trace back to the fork point
      base_entities = target_entities

      auto_merged = []
      merge_conflicts = []

      all_keys = (source_entities.keys + target_entities.keys).uniq

      all_keys.each do |key|
        source_data = source_entities[key]
        target_data = target_entities[key]
        base_data = base_entities[key]

        if source_data && !target_data
          # New in source, add to target
          write_entity(target_path, key, source_data)
          auto_merged << key
        elsif source_data && target_data && source_data != target_data
          result = @diff_engine.three_way_merge(
            base: base_data || {},
            ours: target_data,
            theirs: source_data
          )

          if result[:conflicts].empty?
            write_entity(target_path, key, result[:merged])
            auto_merged << key
          else
            entity_type, entity_id = key.split('/', 2)
            result[:conflicts].each do |c|
              c.entity_type = entity_type
              c.entity_id = entity_id

              resolution = resolutions[key]&.dig(c.field_path)
              if resolution
                c.resolution = resolution[:resolution]
                c.custom_value = resolution[:custom_value]
              end
            end

            resolved = result[:conflicts].select(&:resolved?)
            unresolved = result[:conflicts].reject(&:resolved?)

            # Apply resolved conflicts to merged
            merged = result[:merged]
            resolved.each do |c|
              set_nested_value(merged, c.field_path, c.resolved_value)
            end
            write_entity(target_path, key, merged) if unresolved.empty?

            merge_conflicts.concat(unresolved)
            auto_merged << key if unresolved.empty?
          end
        end
      end

      { auto_merged: auto_merged, conflicts: merge_conflicts }
    end

    # Archive a branch.
    def archive(name)
      branch = find_branch!(name)
      check_no_active_children(name)

      branch.status = 'archived'
      branch.archived_at = Time.now.iso8601
      update_branch_in_index(branch)
    end

    # Unarchive a branch.
    def unarchive(name)
      branch = find_branch!(name)
      branch.status = 'active'
      branch.archived_at = nil
      update_branch_in_index(branch)
    end

    # Delete a branch permanently.
    def delete(name)
      raise "Cannot delete the 'main' branch" if name == 'main'

      find_branch!(name)
      check_no_active_children(name)

      # Remove data
      dest = File.join(@branches_path, name)
      FileUtils.rm_rf(dest)

      # Remove from index
      index = load_index.reject { |b| b.name == name }
      save_index(index)

      # Reset current branch if it was the deleted one
      save_state('main') if current_branch == name
    end

    private

    def branch_data_path(name)
      if name == 'main'
        @story_bible_path
      else
        File.join(@branches_path, name)
      end
    end

    def copy_canon_data(source, dest)
      ENTITY_DIRS.each do |dir|
        src_dir = File.join(source, dir)
        next unless Dir.exist?(src_dir)

        dest_dir = File.join(dest, dir)
        FileUtils.mkdir_p(dest_dir)
        FileUtils.cp_r(Dir.glob(File.join(src_dir, '*')), dest_dir)
      end

      ENTITY_FILES.each do |file|
        src_file = File.join(source, file)
        FileUtils.cp(src_file, File.join(dest, file)) if File.exist?(src_file)
      end
    end

    def load_all_entities(branch_name)
      base = branch_data_path(branch_name)
      entities = {}

      ENTITY_DIRS.each do |dir|
        full_dir = File.join(base, dir)
        next unless Dir.exist?(full_dir)

        Dir.glob(File.join(full_dir, '*.yml')).each do |file|
          id = File.basename(file, '.yml')
          data = YAML.safe_load(File.read(file), permitted_classes: [Date, Time]) || {}
          entities["#{dir.chomp('s')}/#{id}"] = data
        end
      end

      ENTITY_FILES.each do |file|
        full_path = File.join(base, file)
        next unless File.exist?(full_path)

        data = YAML.safe_load(File.read(full_path), permitted_classes: [Date, Time]) || {}
        entity_type = File.basename(file, '.yml')
        entities["file/#{entity_type}"] = data
      end

      entities
    end

    def write_entity(base_path, key, data)
      type, id = key.split('/', 2)

      case type
      when 'character', 'location'
        dir = File.join(base_path, "#{type}s")
        FileUtils.mkdir_p(dir)
        File.write(File.join(dir, "#{id}.yml"), data.to_yaml)
      when 'file'
        File.write(File.join(base_path, "#{id}.yml"), data.to_yaml)
      end
    end

    def set_nested_value(hash, field_path, value)
      parts = field_path.split('.')
      current = hash
      parts[0..-2].each do |part|
        current[part] ||= {}
        current = current[part]
      end
      current[parts.last] = value
    end

    def load_index
      return [] unless File.exist?(@index_path)

      data = YAML.safe_load(File.read(@index_path), permitted_classes: [Date, Time])
      (data['branches'] || []).map { |h| Models::Branch.from_yaml(h) }
    end

    def save_index(branches)
      FileUtils.mkdir_p(@branches_path)
      data = { 'branches' => branches.map(&:to_yaml_hash) }
      File.write(@index_path, data.to_yaml)
    end

    def find_branch(name)
      load_index.find { |b| b.name == name }
    end

    def find_branch!(name)
      branch = find_branch(name)
      raise "Branch '#{name}' not found" unless branch

      branch
    end

    def check_no_active_children(name)
      children = load_index.select { |b| b.parent_branch == name && b.active? }
      raise "Branch '#{name}' has active children: #{children.map(&:name).join(', ')}" if children.any?
    end

    def update_branch_in_index(updated_branch)
      index = load_index.map { |b| b.name == updated_branch.name ? updated_branch : b }
      save_index(index)
    end

    def save_state(branch_name)
      File.write(@state_path, { 'current_branch' => branch_name }.to_yaml)
    end
  end
end
