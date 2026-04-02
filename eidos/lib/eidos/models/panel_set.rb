# frozen_string_literal: true

require 'yaml'
require 'time'
require 'fileutils'
require 'eidos/models/comic_panel'

module Eidos
  class PanelSet
    attr_reader :source, :art_style, :image_format, :canon_version, :panels, :generated_at

    def initialize(source:, art_style:, image_format:, canon_version:, panels: [], generated_at: nil)
      @source = source
      @art_style = art_style
      @image_format = image_format
      @canon_version = canon_version
      @panels = panels
      @generated_at = generated_at || Time.now.utc.iso8601
    end

    def fully_generated?
      panels.any? && panels.all? { |p| p.image_path }
    end

    def sidecar_filename
      identifier = source['number'] || source[:number] || 0
      format('panels_%03d.yml', identifier.to_i)
    end

    def save_sidecar(output_dir)
      FileUtils.mkdir_p(output_dir)
      path = File.join(output_dir, sidecar_filename)
      File.write(path, YAML.dump(to_h))
      path
    end

    def self.load_sidecar(path)
      data = YAML.load_file(path)
      panels = (data['panels'] || []).map do |p|
        ComicPanel.new(
          sequence: p['sequence'],
          scene_description: p['scene_description'],
          characters: p['characters'] || [],
          image_path: p['image_path'],
          text_elements: p['text_elements'] || []
        )
      end

      new(
        source: data['source'],
        art_style: data['art_style'],
        image_format: data['image_format'],
        canon_version: data['canon_version'],
        panels: panels,
        generated_at: data['generated_at']
      )
    end

    def to_h
      {
        'source' => normalize_hash(source),
        'art_style' => art_style,
        'image_format' => image_format,
        'canon_version' => canon_version,
        'generated_at' => generated_at,
        'panels' => panels.map(&:to_h)
      }
    end

    private

    def normalize_hash(hash)
      hash.transform_keys(&:to_s)
    end
  end
end
