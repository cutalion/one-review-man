# frozen_string_literal: true

require 'eidos/chapter'

RSpec.describe Eidos::Chapter do
  let(:chapter) do
    Eidos::Chapter.new(
      chapter_number: 1,
      title: 'The Code Review',
      content: "---\ntitle: The Code Review\n---\nOnce upon a time in a codebase far away.",
      summary: 'A hero appears',
      characters: %w[kenji kai],
      path: '/tmp/001-chapter.md'
    )
  end

  it 'exposes attributes' do
    expect(chapter.chapter_number).to eq(1)
    expect(chapter.title).to eq('The Code Review')
    expect(chapter.summary).to eq('A hero appears')
    expect(chapter.characters).to eq(%w[kenji kai])
  end

  it 'returns content body' do
    expect(chapter.content).to include('Once upon a time')
  end
end
