# frozen_string_literal: true

require 'thor'
require 'eidos/cli/helpers'

module Eidos
  module CLI
    # CLI commands for canon history, diffing, and rollback
    class Canon < Thor
      include Helpers

      class_option 'world-dir', aliases: ['-w'], type: :string, desc: 'Path to the world directory'
      class_option :branch, type: :string, default: 'main', desc: 'Branch context'

      desc 'history ENTITY_TYPE ENTITY_ID', 'Show revision history for a canon entry'
      method_option :limit, type: :numeric, desc: 'Show last N revisions'
      method_option :format, type: :string, default: 'text', desc: 'Output format: text, json'
      def history(entity_type, entity_id)
        abs_root = resolve_project_root!(options['world-dir'])
        store = build_revision_store(abs_root)

        revisions = store.history(
          entity_type: entity_type,
          entity_id: entity_id,
          branch: options[:branch]
        )

        if revisions.empty?
          say "No revisions found for #{entity_type}/#{entity_id}.", :yellow
          exit 1
        end

        revisions = revisions.last(options[:limit]) if options[:limit]

        if options[:format] == 'json'
          require 'json'
          say JSON.pretty_generate(revisions.map(&:to_yaml_hash))
        else
          revisions.reverse_each do |rev|
            say "Rev ##{rev.sequence} | #{rev.timestamp} | #{rev.operation}", :cyan
            say "Reason: #{rev.change_reason}" if rev.change_reason
            if rev.parent_seq
              parent = store.get(entity_type: entity_type, entity_id: entity_id,
                                sequence: rev.parent_seq, branch: options[:branch])
              if parent
                require 'eidos/diff_engine'
                changes = Eidos::DiffEngine.new.diff(parent.snapshot, rev.snapshot)
                say "Changed: #{changes.keys.join(', ')}" unless changes.empty?
              end
            end
            say '---'
          end
        end
      end

      desc 'diff ENTITY_TYPE ENTITY_ID REV1 REV2', 'Compare two revisions of a canon entry'
      method_option :format, type: :string, default: 'text', desc: 'Output format: text, json'
      def diff(entity_type, entity_id, rev1, rev2)
        abs_root = resolve_project_root!(options['world-dir'])
        store = build_revision_store(abs_root)

        r1 = store.get(entity_type: entity_type, entity_id: entity_id,
                       sequence: rev1.to_i, branch: options[:branch])
        r2 = store.get(entity_type: entity_type, entity_id: entity_id,
                       sequence: rev2.to_i, branch: options[:branch])

        unless r1 && r2
          say "Revision not found.", :red
          exit 1
        end

        require 'eidos/diff_engine'
        changes = Eidos::DiffEngine.new.diff(r1.snapshot, r2.snapshot)

        if changes.empty?
          say "No differences between Rev ##{rev1} and Rev ##{rev2}.", :green
          return
        end

        if options[:format] == 'json'
          require 'json'
          say JSON.pretty_generate(changes)
        else
          say "Comparing #{entity_type}/#{entity_id}: Rev ##{rev1} -> Rev ##{rev2}\n", :cyan
          changes.each do |field, vals|
            say "#{field}:"
            say "- #{vals[:old].inspect}", :red
            say "+ #{vals[:new].inspect}", :green
            say ''
          end
        end
      end

      desc 'rollback ENTITY_TYPE ENTITY_ID REVISION', 'Restore a canon entry to a previous revision'
      method_option :reason, type: :string, desc: 'Reason for rollback'
      method_option :auto, type: :boolean, default: false, desc: 'Skip confirmation'
      def rollback(entity_type, entity_id, revision)
        abs_root = resolve_project_root!(options['world-dir'])
        store = build_revision_store(abs_root)

        target = store.get(entity_type: entity_type, entity_id: entity_id,
                           sequence: revision.to_i, branch: options[:branch])

        unless target
          say "Revision ##{revision} not found for #{entity_type}/#{entity_id}.", :red
          exit 1
        end

        unless options[:auto]
          unless yes?("Rollback #{entity_type}/#{entity_id} to revision ##{revision}? (y/n)")
            say 'Cancelled.', :yellow
            exit 3
          end
        end

        bible = Eidos::StoryBible.new(project_root: abs_root, revision_store: store)

        case entity_type
        when 'character'
          bible.save_character(entity_id, target.snapshot,
                               change_reason: options[:reason] || "Rollback to revision ##{revision}")
        when 'location'
          bible.save_location(entity_id, target.snapshot,
                               change_reason: options[:reason] || "Rollback to revision ##{revision}")
        else
          say "Rollback not yet supported for #{entity_type}.", :red
          exit 1
        end

        latest = store.latest(entity_type: entity_type, entity_id: entity_id, branch: options[:branch])
        say "Rolled back #{entity_type}/#{entity_id} to revision ##{revision}", :green
        say "New revision: ##{latest.sequence} (rollback)"
      end

      desc 'update ENTITY_TYPE ENTITY_ID [FIELD=VALUE...]', 'Update a canon entry'
      method_option :reason, type: :string, desc: 'Reason for the change'
      def update(entity_type, entity_id, *field_values)
        abs_root = resolve_project_root!(options['world-dir'])
        store = build_revision_store(abs_root)
        bible = Eidos::StoryBible.new(project_root: abs_root, revision_store: store)

        changes = {}
        field_values.each do |fv|
          key, value = fv.split('=', 2)
          changes[key] = value if key && value
        end

        case entity_type
        when 'character'
          existing = bible.get_character(entity_id) || {}
          bible.save_character(entity_id, existing.merge(changes), change_reason: options[:reason])
        when 'location'
          existing = bible.get_location(entity_id) || {}
          bible.save_location(entity_id, existing.merge(changes), change_reason: options[:reason])
        else
          say "Update not yet supported for #{entity_type}.", :red
          exit 1
        end

        say "Updated #{entity_type}/#{entity_id}", :green

        # Automatic non-blocking impact analysis
        analyzer = build_impact_analyzer(abs_root)
        latest_rev = store.latest(entity_type: entity_type, entity_id: entity_id)
        if latest_rev
          report = analyzer.analyze(
            entity_type: entity_type,
            entity_id: entity_id,
            revision: latest_rev,
            branch: options[:branch] || 'main'
          )
          if report.affected_items.any?
            say "Impact: #{report.affected_items.length} content file(s) reference this entity", :yellow
            say "Run 'canon impact --latest' for details"
          else
            say "No content references found for this entity."
          end
        end
      end

      desc 'impact', 'View impact reports'
      method_option :latest, type: :boolean, default: false, desc: 'Show most recent report'
      method_option 'report-id', type: :string, desc: 'Show specific report'
      method_option 'pending-only', type: :boolean, default: false, desc: 'Show only pending items'
      method_option :format, type: :string, default: 'text', desc: 'Output format: text, json'
      def impact
        abs_root = resolve_project_root!(options['world-dir'])
        analyzer = build_impact_analyzer(abs_root)

        if options['report-id']
          report = analyzer.load_report(options['report-id'])
          unless report
            say "Report not found.", :red
            exit 1
          end
          display_impact_report(report, options)
        elsif options[:latest]
          reports = analyzer.list_reports(branch: options[:branch])
          if reports.empty?
            say "No impact reports found.", :yellow
            exit 1
          end
          display_impact_report(reports.first, options)
        else
          reports = analyzer.list_reports(branch: options[:branch])
          if reports.empty?
            say "No impact reports found.", :yellow
            return
          end
          reports.each { |r| display_impact_report_summary(r) }
        end
      end

      desc 'impact_review REPORT_ID ITEM_INDEX STATUS', 'Update review status of an affected item'
      def impact_review(report_id, item_index, status)
        abs_root = resolve_project_root!(options['world-dir'])
        analyzer = build_impact_analyzer(abs_root)

        valid_statuses = %w[reviewed needs_update deferred]
        unless valid_statuses.include?(status)
          say "Invalid status. Use: #{valid_statuses.join(', ')}", :red
          exit 2
        end

        report = analyzer.update_review_status(
          report_id: report_id,
          item_index: item_index.to_i - 1,
          status: status
        )

        unless report
          say "Report or item not found.", :red
          exit 1
        end

        say "Updated item ##{item_index} to '#{status}'.", :green
      end

      private

      def build_revision_store(abs_root)
        revisions_path = File.join(abs_root, 'data', 'story_bible', 'revisions')
        require 'eidos/revision_store'
        Eidos::RevisionStore.new(revisions_path: revisions_path)
      end

      def build_impact_analyzer(abs_root)
        store = build_revision_store(abs_root)
        require 'eidos/impact_analyzer'
        Eidos::ImpactAnalyzer.new(
          content_path: File.join(abs_root, 'content'),
          reference_index_path: File.join(abs_root, 'data', 'story_bible', 'references.yml'),
          revision_store: store,
          reports_path: File.join(abs_root, 'data', 'story_bible', 'impact_reports')
        )
      end

      def display_impact_report(report, opts)
        if opts[:format] == 'json'
          require 'json'
          say JSON.pretty_generate(report.to_yaml_hash)
          return
        end

        say "Impact Report #{report.id}", :cyan
        say "Trigger: #{report.trigger['entity_type']}/#{report.trigger['entity_id']} Rev ##{report.trigger['revision_seq']}"
        say ''

        items = report.affected_items
        items = items.select { |i| i.review_status == 'pending' } if opts['pending-only']

        if items.empty?
          say "No affected items#{' pending' if opts['pending-only']}.", :green
          return
        end

        items.each_with_index do |item, _idx|
          color = case item.severity
                  when 'high' then :red
                  when 'medium' then :yellow
                  else :white
                  end
          say "#{item.severity.upcase}: #{item.content_path} [#{item.review_status}]", color
          item.references.each do |ref|
            say "  Line #{ref['line']}: #{ref['text']}"
          end
        end

        say "\nSummary: #{report.summary['total']} items " \
            "(#{report.summary.dig('by_severity', 'high') || 0} high, " \
            "#{report.summary.dig('by_severity', 'medium') || 0} medium, " \
            "#{report.summary.dig('by_severity', 'low') || 0} low)"
      end

      def display_impact_report_summary(report)
        say "#{report.id} | #{report.trigger['entity_type']}/#{report.trigger['entity_id']} | " \
            "#{report.summary['total']} items", :cyan
      end
    end

    # CLI commands for world branching
    class BranchCli < Thor
      include Helpers

      class_option 'world-dir', aliases: ['-w'], type: :string, desc: 'Path to the world directory'

      desc 'create NAME', 'Create a new branch'
      method_option :from, type: :string, default: 'main', desc: 'Parent branch'
      method_option 'at-revision', type: :numeric, desc: 'Branch from a specific revision point'
      method_option :description, type: :string, desc: 'Purpose of this branch'
      def create(name)
        abs_root = resolve_project_root!(options['world-dir'])
        manager = build_branch_manager(abs_root)

        branch = manager.create(
          name: name,
          from_branch: options[:from],
          at_revision: options['at-revision'],
          description: options[:description]
        )

        say "Created branch \"#{branch.name}\" from #{branch.parent_branch}", :green
        say "Switch to it with: canon branch checkout #{branch.name}"
      rescue RuntimeError => e
        say e.message, :red
        exit 1
      end

      desc 'list', 'List all branches'
      method_option :all, type: :boolean, default: false, desc: 'Include archived branches'
      method_option :format, type: :string, default: 'text', desc: 'Output format: text, json'
      def list
        abs_root = resolve_project_root!(options['world-dir'])
        manager = build_branch_manager(abs_root)

        branches = manager.list(include_archived: options[:all])
        current = manager.current_branch

        if options[:format] == 'json'
          require 'json'
          say JSON.pretty_generate(branches.map(&:to_yaml_hash))
          return
        end

        say "* main (active)", current == 'main' ? :green : :white
        branches.each do |b|
          prefix = current == b.name ? '* ' : '  '
          color = current == b.name ? :green : :white
          status = b.archived? ? 'archived' : 'active'
          say "#{prefix}#{b.name} (#{status}) <- #{b.parent_branch}", color
        end
      end

      desc 'checkout NAME', 'Switch active branch context'
      def checkout(name)
        abs_root = resolve_project_root!(options['world-dir'])
        manager = build_branch_manager(abs_root)
        manager.checkout(name)
        say "Switched to branch \"#{name}\"", :green
      rescue RuntimeError => e
        say e.message, :red
        exit 1
      end

      desc 'compare BRANCH1 BRANCH2', 'Compare two branches'
      method_option :format, type: :string, default: 'text', desc: 'Output format: text, json'
      def compare(branch_a, branch_b)
        abs_root = resolve_project_root!(options['world-dir'])
        manager = build_branch_manager(abs_root)
        result = manager.compare(branch_a, branch_b)

        if options[:format] == 'json'
          require 'json'
          say JSON.pretty_generate(result)
          return
        end

        say "Comparing \"#{branch_a}\" <-> \"#{branch_b}\"\n", :cyan

        unless result[:only_in_a].empty?
          say "Only in #{branch_a} (#{result[:only_in_a].length}):"
          result[:only_in_a].each { |k| say "  #{k}" }
        end

        unless result[:only_in_b].empty?
          say "Only in #{branch_b} (#{result[:only_in_b].length}):"
          result[:only_in_b].each { |k| say "  #{k}" }
        end

        unless result[:conflicts].empty?
          say "\nConflicts (#{result[:conflicts].length}):", :red
          result[:conflicts].each do |c|
            say "  #{c[:entity]}: #{c[:diffs].keys.join(', ')}"
          end
        end

        say "\nIdentical: #{result[:identical].length}" unless result[:identical].empty?
      end

      desc 'merge SOURCE TARGET', 'Merge changes from source into target'
      method_option :auto, type: :boolean, default: false, desc: 'Skip confirmation'
      method_option 'dry-run', type: :boolean, default: false, desc: 'Show what would be merged'
      def merge(source, target)
        abs_root = resolve_project_root!(options['world-dir'])
        manager = build_branch_manager(abs_root)

        if options['dry-run']
          result = manager.compare(source, target)
          say "Dry run: merge \"#{source}\" -> \"#{target}\"", :cyan
          say "Would merge #{result[:only_in_b].length} new entries"
          say "Potential conflicts: #{result[:conflicts].length}"
          return
        end

        unless options[:auto]
          unless yes?("Merge \"#{source}\" into \"#{target}\"? (y/n)")
            say 'Cancelled.', :yellow
            exit 4
          end
        end

        result = manager.merge(source: source, target: target)

        say "Auto-merged: #{result[:auto_merged].length} changes", :green
        if result[:conflicts].any?
          say "Conflicts: #{result[:conflicts].length}", :red
          result[:conflicts].each_with_index do |c, i|
            say "\nConflict #{i + 1}: #{c.entity_type}/#{c.entity_id}.#{c.field_path}"
            say "  OURS (#{target}):   #{c.ours_value.inspect}"
            say "  THEIRS (#{source}): #{c.theirs_value.inspect}"
          end
          exit 3
        end
      end

      desc 'archive NAME', 'Archive a branch'
      method_option :auto, type: :boolean, default: false, desc: 'Skip confirmation'
      def archive(name)
        abs_root = resolve_project_root!(options['world-dir'])
        manager = build_branch_manager(abs_root)

        unless options[:auto]
          unless yes?("Archive branch \"#{name}\"? (y/n)")
            say 'Cancelled.', :yellow
            exit 3
          end
        end

        manager.archive(name)
        say "Archived branch \"#{name}\".", :green
      rescue RuntimeError => e
        say e.message, :red
        exit 1
      end

      desc 'delete NAME', 'Delete a branch permanently'
      method_option :auto, type: :boolean, default: false, desc: 'Skip confirmation'
      def delete(name)
        abs_root = resolve_project_root!(options['world-dir'])
        manager = build_branch_manager(abs_root)

        unless options[:auto]
          unless yes?("Permanently delete branch \"#{name}\"? This cannot be undone. (y/n)")
            say 'Cancelled.', :yellow
            exit 3
          end
        end

        manager.delete(name)
        say "Deleted branch \"#{name}\".", :green
      rescue RuntimeError => e
        say e.message, :red
        exit 1
      end

      private

      def build_branch_manager(abs_root)
        story_bible_path = File.join(abs_root, 'data', 'story_bible')
        revisions_path = File.join(story_bible_path, 'revisions')
        require 'eidos/revision_store'
        require 'eidos/diff_engine'
        require 'eidos/branch_manager'
        Eidos::BranchManager.new(
          story_bible_path: story_bible_path,
          revision_store: Eidos::RevisionStore.new(revisions_path: revisions_path),
          diff_engine: Eidos::DiffEngine.new
        )
      end
    end

    # CLI commands for batch changesets
    class ChangesetCli < Thor
      include Helpers

      class_option 'world-dir', aliases: ['-w'], type: :string, desc: 'Path to the world directory'

      desc 'create', 'Start a new batch changeset'
      method_option :branch, type: :string, default: 'main', desc: 'Target branch'
      def create
        abs_root = resolve_project_root!(options['world-dir'])
        manager = build_changeset_manager(abs_root)
        cs = manager.create(branch: options[:branch])
        say "Created changeset #{cs.id} on branch '#{cs.branch}'", :green
      rescue RuntimeError => e
        say e.message, :red
        exit 1
      end

      desc 'add OPERATION ENTITY_TYPE ENTITY_ID [FIELD=VALUE...]', 'Add an operation to the active changeset'
      method_option :reason, type: :string, desc: 'Reason for this change'
      def add(operation, entity_type, entity_id, *field_values)
        abs_root = resolve_project_root!(options['world-dir'])
        manager = build_changeset_manager(abs_root)

        active_cs = manager.active
        unless active_cs
          say "No active changeset. Create one first with: canon changeset create", :red
          exit 1
        end

        changes = parse_field_values(field_values)

        manager.add_operation(
          changeset_id: active_cs.id,
          operation: operation,
          entity_type: entity_type,
          entity_id: entity_id,
          changes: changes,
          change_reason: options[:reason]
        )

        say "Added #{operation} #{entity_type}/#{entity_id} to changeset #{active_cs.id}", :green
      end

      desc 'preview', 'Preview aggregate impact of the changeset'
      method_option :format, type: :string, default: 'text', desc: 'Output format: text, json'
      def preview
        abs_root = resolve_project_root!(options['world-dir'])
        manager = build_changeset_manager(abs_root)

        active_cs = manager.active
        unless active_cs
          say "No active changeset.", :red
          exit 1
        end

        result = manager.preview(changeset_id: active_cs.id)

        if options[:format] == 'json'
          require 'json'
          say JSON.pretty_generate(result[:report])
          return
        end

        say "Changeset #{active_cs.id} preview:", :cyan
        say "Operations: #{result[:report]['operations_count']}"

        if result[:conflicts].any?
          say "\nIntra-batch conflicts (#{result[:conflicts].length}):", :red
          result[:conflicts].each do |c|
            say "  #{c.entity_type}/#{c.entity_id}: #{c.field_path}"
          end
          exit 3
        else
          say "No conflicts detected.", :green
        end
      end

      desc 'commit', 'Commit the active changeset'
      method_option :reason, type: :string, desc: 'Overall changeset reason'
      method_option :auto, type: :boolean, default: false, desc: 'Skip confirmation'
      def commit
        abs_root = resolve_project_root!(options['world-dir'])
        manager = build_changeset_manager(abs_root)

        active_cs = manager.active
        unless active_cs
          say "No active changeset.", :red
          exit 1
        end

        unless options[:auto]
          unless yes?("Commit changeset #{active_cs.id} with #{active_cs.operations.length} operations? (y/n)")
            say 'Cancelled.', :yellow
            exit 3
          end
        end

        revisions = manager.commit(changeset_id: active_cs.id, reason: options[:reason])
        say "Committed changeset #{active_cs.id} (#{revisions.length} revisions created)", :green
      rescue Eidos::ChangesetManager::ChangesetConflictError => e
        say "Cannot commit: #{e.message}", :red
        exit 3
      end

      desc 'discard', 'Discard the active changeset'
      method_option :auto, type: :boolean, default: false, desc: 'Skip confirmation'
      def discard
        abs_root = resolve_project_root!(options['world-dir'])
        manager = build_changeset_manager(abs_root)

        active_cs = manager.active
        unless active_cs
          say "No active changeset.", :red
          exit 1
        end

        unless options[:auto]
          unless yes?("Discard changeset #{active_cs.id}? (y/n)")
            say 'Cancelled.', :yellow
            exit 3
          end
        end

        manager.discard(changeset_id: active_cs.id)
        say "Discarded changeset #{active_cs.id}.", :green
      end

      private

      def build_changeset_manager(abs_root)
        changesets_path = File.join(abs_root, 'data', 'changesets')
        revisions_path = File.join(abs_root, 'data', 'story_bible', 'revisions')
        require 'eidos/revision_store'
        require 'eidos/story_bible'
        require 'eidos/changeset_manager'
        store = Eidos::RevisionStore.new(revisions_path: revisions_path)
        bible = Eidos::StoryBible.new(project_root: abs_root, revision_store: store)
        Eidos::ChangesetManager.new(
          changesets_path: changesets_path,
          story_bible: bible,
          revision_store: store
        )
      end

      def parse_field_values(field_values)
        changes = {}
        field_values.each do |fv|
          key, value = fv.split('=', 2)
          changes[key] = value if key && value
        end
        changes
      end
    end

    # CLI subcommand for canon snapshot management
    class SnapshotCli < Thor
      include Helpers

      class_option 'world-dir', aliases: ['-w'], type: :string, desc: 'Path to the world directory'

      desc 'create NAME', 'Create a named snapshot of the current Story Bible state'
      def create(name)
        abs_root = resolve_project_root!(options['world-dir'])
        require 'eidos/snapshot_store'
        require 'eidos/story_bible'

        bible_path = File.join(abs_root, Eidos::StoryBible::STORY_BIBLE_DIR)
        store = Eidos::SnapshotStore.new(story_bible_path: bible_path)
        manifest = store.create(name: name)

        say "Created snapshot \"#{manifest['name']}\" (version #{manifest['version']})", :green
        counts = manifest['entity_counts']
        say "  Characters: #{counts['characters']}"
        say "  Locations: #{counts['locations']}"
        say "  Facts: #{counts['facts']} categories"
        say "  Relationships: #{counts['relationships']}"
        say "  Plot threads: #{counts['plot_threads']}"
      rescue Eidos::DuplicateSnapshotError => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      rescue Eidos::InvalidSnapshotNameError => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      end

      desc 'list', 'List all snapshots'
      def list
        abs_root = resolve_project_root!(options['world-dir'])
        require 'eidos/snapshot_store'
        require 'eidos/story_bible'

        bible_path = File.join(abs_root, Eidos::StoryBible::STORY_BIBLE_DIR)
        store = Eidos::SnapshotStore.new(story_bible_path: bible_path)
        snapshots = store.list

        if snapshots.empty?
          say 'No snapshots found.'
          return
        end

        say 'Snapshots:'
        snapshots.each do |s|
          counts = s['entity_counts']
          date = s['timestamp'].to_s[0, 10]
          say format('  v%-3d %-20s %s  %s  (%d chars, %d locs, %d facts, %d rels, %d threads)',
                     s['version'], s['name'], date, s['branch'],
                     counts['characters'], counts['locations'], counts['facts'],
                     counts['relationships'], counts['plot_threads'])
        end
      end

      desc 'show NAME', 'Show detailed metadata for a snapshot'
      def show(name)
        abs_root = resolve_project_root!(options['world-dir'])
        require 'eidos/snapshot_store'
        require 'eidos/story_bible'

        bible_path = File.join(abs_root, Eidos::StoryBible::STORY_BIBLE_DIR)
        store = Eidos::SnapshotStore.new(story_bible_path: bible_path)
        manifest = store.get(name)

        unless manifest
          $stderr.puts "Error: Snapshot \"#{name}\" not found"
          exit 1
        end

        say "Snapshot: #{manifest['name']} (version #{manifest['version']})"
        say "Created: #{manifest['timestamp']}"
        say "Branch: #{manifest['branch']}"
        say 'Entities:'
        counts = manifest['entity_counts']
        say "  Characters: #{counts['characters']}"
        say "  Locations: #{counts['locations']}"
        say "  Facts: #{counts['facts']} categories"
        say "  Relationships: #{counts['relationships']}"
        say "  Plot threads: #{counts['plot_threads']}"
      end
    end

    # Register subcommands on Canon after all sub-classes are defined
    Canon.desc 'snapshot SUBCOMMAND ...ARGS', 'Manage canon snapshots'
    Canon.subcommand 'snapshot', SnapshotCli

    Canon.desc 'branch SUBCOMMAND ...ARGS', 'Manage world branches'
    Canon.subcommand 'branch', BranchCli

    Canon.desc 'changeset SUBCOMMAND ...ARGS', 'Manage batch changesets'
    Canon.subcommand 'changeset', ChangesetCli
  end
end
