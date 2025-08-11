# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "book-generator-jekyll"
  spec.version       = "1.0.0"
  spec.authors       = ["One Review Man Contributors"]
  spec.email         = ["book-generator@example.com"]

  spec.summary       = "Jekyll site template for the book-generator CLI"
  spec.description   = "Provides Jekyll layouts, includes, and assets for generating book websites. No Ruby API is exposed."
  spec.homepage      = "https://github.com/yourusername/one-review-man"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[
    site_template/**/*
    LICENSE.txt
    README.md
  ], File::FNM_DOTMATCH).reject { |f| File.directory?(f) }

  spec.require_paths = []

  # Runtime dependencies
  # No runtime dependency on book-generator; this gem only ships a template.
  spec.add_dependency "jekyll", "~> 4.3"
  spec.add_dependency "jekyll-polyglot", "~> 1.8"
  spec.add_dependency "jekyll-feed", "~> 0.17"
  spec.add_dependency "minima", "~> 2.5"
  spec.add_dependency "webrick", "~> 1.8"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "pry", "~> 0.14"
  spec.add_development_dependency "rake", "~> 13.0"
end
