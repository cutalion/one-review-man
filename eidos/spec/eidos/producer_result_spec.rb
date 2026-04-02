# frozen_string_literal: true

require 'eidos/producer_result'

RSpec.describe Eidos::ProducerResult do
  describe 'struct creation' do
    it 'creates with keyword arguments' do
      result = described_class.new(
        success: true,
        output_path: '/tmp/output',
        canon_version: { 'snapshot' => 'v1', 'version' => 1 },
        artifacts: ['/tmp/output/chapter_01.md'],
        error: nil
      )

      expect(result.success).to be true
      expect(result.output_path).to eq('/tmp/output')
      expect(result.canon_version).to eq({ 'snapshot' => 'v1', 'version' => 1 })
      expect(result.artifacts).to eq(['/tmp/output/chapter_01.md'])
      expect(result.error).to be_nil
    end

    it 'defaults fields to nil' do
      result = described_class.new
      expect(result.success).to be_nil
      expect(result.output_path).to be_nil
      expect(result.artifacts).to be_nil
      expect(result.error).to be_nil
    end
  end

  describe '#success?' do
    it 'returns true when success is true' do
      result = described_class.new(success: true)
      expect(result.success?).to be true
    end

    it 'returns false when success is false' do
      result = described_class.new(success: false)
      expect(result.success?).to be false
    end

    it 'returns false when success is nil' do
      result = described_class.new
      expect(result.success?).to be false
    end
  end

  describe '#failure?' do
    it 'returns true when success is false' do
      result = described_class.new(success: false)
      expect(result.failure?).to be true
    end

    it 'returns false when success is true' do
      result = described_class.new(success: true)
      expect(result.failure?).to be false
    end
  end
end
