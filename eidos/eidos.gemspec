# frozen_string_literal: true

require_relative 'lib/eidos/version'

Gem::Specification.new do |spec|
  spec.name          = 'eidos'
  spec.version       = Eidos::VERSION
  spec.authors       = ['One Review Man Contributors']
  spec.email         = ['eidos@example.com']

  spec.summary       = 'IP world engine for AI-powered content creation'
  spec.description   = 'A flexible and extensible engine for building and managing IP worlds (storyworlds). ' \
                       'Supports multiple LLM providers, dependency injection, and pluggable producers.'
  spec.homepage      = 'https://github.com/yourusername/one-review-man'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.3.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[
                          lib/**/*.rb
                          templates/**/*
                          bin/*
                          LICENSE.txt
                          README.md
                        ], File::FNM_DOTMATCH).reject { |f| File.directory?(f) }

  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'dotenv', '~> 3.1'
  spec.add_dependency 'rainbow', '~> 3.1'
  spec.add_dependency 'reline'
  spec.add_dependency 'ruby-openai', '~> 7.3'
  spec.add_dependency 'base64' # Silence Ruby 3.4 deprecation warnings
  spec.add_dependency 'thor', '~> 1.3'
  spec.add_dependency 'tty-prompt', '~> 0.23'
  spec.add_dependency 'tty-spinner', '~> 0.9'
end
