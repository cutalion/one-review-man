# frozen_string_literal: true

require 'yaml'
require 'date'

module Eidos
  # A generated content artifact. Generalizes the book-era "chapter" concept:
  # every piece declares a form (chapter, haiku, vignette, ...), a category
  # (text/image/script), and carries a canon version + canon_status so we
  # can reason about its relationship to the world bible.
  #
  # Read-path: Piece.from_file(path) parses the YAML frontmatter of a piece
  # markdown file. Write-path: Piece.new(...).to_frontmatter returns the hash
  # the PieceProducer serializes into the file it writes.
  #
  # For chapter-form pieces, id is the zero-padded chapter number ("017");
  # for all other forms, id is a ULID produced at generation time.
  class Piece
    # Symbols carried in memory; serialized as plain strings in YAML.
    STATUSES = %i[applied reverted].freeze
    CATEGORIES = %i[text image script].freeze

    attr_reader :id, :form, :category, :generated_date, :canon_version,
                :canon_status, :length_measured, :canon_delta_ref,
                :content_path, :asset_path, :frontmatter,
                :title, :summary, :chapter_number

    def initialize(id:, form:, category:, generated_date:, canon_version:, # rubocop:disable Metrics/ParameterLists
                   length_measured:, canon_status: :applied,
                   canon_delta_ref: nil, content_path: nil, asset_path: nil,
                   frontmatter: nil, title: nil, summary: nil, chapter_number: nil)
      @id = id.to_s
      @form = form.to_s
      @category = coerce_symbol(category, CATEGORIES, :text)
      @generated_date = coerce_date(generated_date)
      # Preserve canon_version type. Post-018a: integer global revision
      # OR a snapshot-label string OR (legacy on-disk reads) the literal
      # string 'unversioned'. Drop only nil to a placeholder so the caller
      # never sees a missing field.
      @canon_version = canon_version.nil? ? 'unversioned' : canon_version
      @canon_status = coerce_symbol(canon_status, STATUSES, :applied)
      @length_measured = length_measured
      @canon_delta_ref = canon_delta_ref
      @content_path = content_path
      @asset_path = asset_path
      @frontmatter = frontmatter
      # 018a chapter-form-specific frontmatter (FR-002).
      @title = title
      @summary = summary
      @chapter_number = chapter_number
    end

    # Read a piece from disk. Works for both the legacy chapter-form layout
    # (content/chapters/NNN-chapter.md) and new piece files under
    # content/pieces/<form>/<id>.md. Pre-feature chapter files lack the
    # new fields (form/category/canon_status/canon_delta_ref); we synthesize
    # sensible defaults so old files remain readable (FR-002 subset).
    def self.from_file(file_path)
      raw = File.read(file_path)
      fm, _body = parse_front_matter(raw)

      form = fm['form'] || infer_form_from_path(file_path)
      category = fm['category'] || default_category_for(form)

      new(
        id: fm['id'] || fm['chapter_number']&.to_s || extract_id_from_path(file_path, form),
        form: form,
        category: category,
        generated_date: fm['generated_date'] || Date.today.iso8601,
        canon_version: fm['canon_version'] || 'unversioned',
        length_measured: fm['length_measured'] || fm['word_count'] || 0,
        canon_status: fm['canon_status'] || :applied,
        canon_delta_ref: fm['canon_delta_ref'],
        content_path: file_path,
        asset_path: fm['asset_path'],
        frontmatter: fm
      )
    end

    def self.parse_front_matter(raw)
      return [{}, raw.strip] unless raw.start_with?("---\n")

      parts = raw.split("---\n", 3)
      return [{}, raw.strip] unless parts.length >= 3

      [YAML.safe_load(parts[1], permitted_classes: [Date, Symbol, Time]) || {}, parts[2].strip]
    end

    # Serialize to a frontmatter hash suitable for writing back to a piece file.
    # Keys stay strings so the YAML output matches the hand-authored format
    # the rest of the system expects.
    def to_frontmatter
      {
        'id' => @id,
        'form' => @form,
        'category' => @category.to_s,
        'generated_date' => @generated_date.to_s,
        'canon_version' => @canon_version,
        'canon_status' => @canon_status.to_s,
        'length_measured' => @length_measured,
        'canon_delta_ref' => @canon_delta_ref,
        'content_path' => @content_path,
        'asset_path' => @asset_path,
        # 018a chapter-form-specific keys (FR-002). nil-stripped via .compact.
        'title' => @title,
        'summary' => @summary,
        'chapter_number' => @chapter_number
      }.compact
    end

    def applied?
      @canon_status == :applied
    end

    def reverted?
      @canon_status == :reverted
    end

    def self.default_category_for(form)
      case form
      when 'portrait', 'illustration' then :image
      when 'comic-script' then :script
      else :text
      end
    end

    def self.infer_form_from_path(file_path)
      parts = file_path.to_s.split('/')
      return 'chapter' if parts.include?('chapters')

      # content/pieces/<form>/<id>.md
      if (pi = parts.rindex('pieces')) && parts[pi + 1]
        return parts[pi + 1]
      end

      'chapter'
    end

    def self.extract_id_from_path(file_path, form)
      basename = File.basename(file_path, '.md')
      if form == 'chapter' && basename =~ /^(\d{3})-chapter$/
        Regexp.last_match(1).to_i.to_s
      else
        basename
      end
    end

    private

    def coerce_symbol(value, allowed, default)
      return default if value.nil? || value.to_s.empty?

      sym = value.to_s.to_sym
      allowed.include?(sym) ? sym : default
    end

    def coerce_date(value)
      return value if value.is_a?(Date)

      Date.parse(value.to_s) if value
    rescue ArgumentError
      Date.today
    end
  end
end
