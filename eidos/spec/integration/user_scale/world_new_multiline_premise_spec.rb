# frozen_string_literal: true

require 'spec_helper'
require 'yaml'
require 'support/integration_world_builder'

# T010 (feature 015 US3) — SC-001.
#
# Shells `exe/eidos world new --quick` end-to-end with a multi-line premise
# that contains commas, em-dashes, quotes, and a comma-delimited token that
# the pre-015 here-doc stdin flow would have truncated into the `languages`
# field. Asserts that the disk artifact preserves the premise verbatim and
# that `languages` contains only ISO codes.
#
# This suite is EXCLUDED from the fast rspec loop (see eidos/.rspec). Run
# explicitly:
#
#   cd eidos && MOCK_AI=true bundle exec rspec spec/integration/user_scale/
RSpec.describe 'world new --quick preserves a multi-line premise (015 US3)' do
  let(:premise) do
    <<~PREMISE.strip
      A 40-year-old programmer with 20+ years of experience quits his
      stable job, convinced that landing a new one will be quick. Instead he
      wakes up in the middle of the AI revolution — recruiters, inboxes,
      spam funnels, and "a framework from three years ago" all conspire.
      Deadpan, dry tone; observational humor, not slapstick.
    PREMISE
  end

  it 'lands the premise verbatim in subtitle/description and keeps languages clean' do
    result = Eidos::Spec::IntegrationWorldBuilder.build_world(
      title: 'Job Hunt',
      author: 'Demo',
      premise: premise,
      languages: 'en'
    )

    expect(result.success?).to be(true),
                               "world new failed\nstdout: #{result.stdout}\nstderr: #{result.stderr}"

    config_path = File.join(result.world_path, 'data', 'world_config.yml')
    expect(File.exist?(config_path)).to be(true)

    config = YAML.safe_load_file(config_path)

    # SC-001: premise lands verbatim in subtitle AND description.
    expect(config.dig('localized', 'en', 'subtitle')).to eq(premise)
    expect(config['description']).to eq(premise)

    # Languages is clean: only ["en"]. Pre-015 the here-doc bug left prose
    # fragments here like ["stable job", "convinced that landing..."].
    expect(config['languages']).to eq(['en'])
    expect(config['default_language']).to eq('en')

    # None of the language entries look like prose (contain spaces / quotes).
    config['languages'].each do |code|
      expect(code).to match(/\A[a-z]{2,3}(-[A-Za-z0-9]+)?\z/),
                      "language code #{code.inspect} does not look like an ISO tag"
    end
  end

  it 'preserves commas, em-dashes, and quotes embedded in the premise' do
    tricky_premise = "Line one, with a comma. — Em-dash line. \"Quoted line.\""

    result = Eidos::Spec::IntegrationWorldBuilder.build_world(
      title: 'Tricky',
      author: 'QA',
      premise: tricky_premise,
      languages: 'en,ru',
      extra_flags: { '--default-language' => 'ru' }
    )

    expect(result.success?).to be(true),
                               "world new failed\nstdout: #{result.stdout}\nstderr: #{result.stderr}"

    config = YAML.safe_load_file(File.join(result.world_path, 'data', 'world_config.yml'))

    expect(config.dig('localized', 'en', 'subtitle')).to eq(tricky_premise)
    expect(config['languages']).to eq(%w[en ru])
    expect(config['default_language']).to eq('ru')
  end
end
