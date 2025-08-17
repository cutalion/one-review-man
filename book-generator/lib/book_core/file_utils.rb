# frozen_string_literal: true

require 'fileutils'
require 'tempfile'

module BookCore
  # Safe file operation utilities to prevent race conditions and data loss
  module SafeFileUtils
    # Atomically write content to a file using a temporary file
    # @param file_path [String] Path to the target file
    # @param content [String] Content to write
    # @param backup [Boolean] Whether to create a backup if file exists
    # @return [Boolean] true if successful
    def self.atomic_write(file_path, content, backup: false)
      dir = File.dirname(file_path)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      
      # Create backup if requested and file exists
      if backup && File.exist?(file_path)
        backup_path = "#{file_path}.backup.#{Time.now.to_i}"
        FileUtils.cp(file_path, backup_path)
      end
      
      # Write to temporary file first
      temp_file = Tempfile.new(['atomic_write', '.tmp'], dir)
      begin
        temp_file.write(content)
        temp_file.flush
        temp_file.fsync  # Ensure data is written to disk
        temp_file.close
        
        # Atomically move the temporary file to the target
        FileUtils.mv(temp_file.path, file_path)
        true
      rescue StandardError => e
        # Clean up temp file if something went wrong
        File.unlink(temp_file.path) if temp_file && File.exist?(temp_file.path)
        raise e
      ensure
        temp_file.close unless temp_file.closed?
      end
    rescue StandardError => e
      puts "⚠️  Warning: Failed to write file '#{file_path}': #{e.message}"
      false
    end

    # Safely copy a file only if the destination doesn't exist
    # @param source [String] Source file path
    # @param destination [String] Destination file path
    # @param overwrite [Boolean] Whether to overwrite existing files
    # @return [Boolean] true if file was copied
    def self.safe_copy(source, destination, overwrite: false)
      return false unless File.exist?(source)
      return false if !overwrite && File.exist?(destination)
      
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source, destination)
      true
    rescue StandardError => e
      puts "⚠️  Warning: Failed to copy '#{source}' to '#{destination}': #{e.message}"
      false
    end

    # Safely create directory structure
    # @param path [String] Directory path to create
    # @return [Boolean] true if successful
    def self.safe_mkdir_p(path)
      FileUtils.mkdir_p(path)
      true
    rescue StandardError => e
      puts "⚠️  Warning: Failed to create directory '#{path}': #{e.message}"
      false
    end

    # Read file with error handling
    # @param file_path [String] Path to file to read
    # @param default_content [String] Content to return if file doesn't exist or read fails
    # @return [String] File content or default content
    def self.safe_read(file_path, default_content: '')
      return default_content unless File.exist?(file_path)
      File.read(file_path)
    rescue StandardError => e
      puts "⚠️  Warning: Failed to read file '#{file_path}': #{e.message}"
      default_content
    end
  end
end