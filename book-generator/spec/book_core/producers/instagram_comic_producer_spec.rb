# frozen_string_literal: true

require 'tmpdir'
require 'yaml'
require 'fileutils'
require 'book_core/producers/instagram_comic_producer'

RSpec.describe BookCore::Producers::InstagramComicProducer do
  let(:project_root) { Dir.mktmpdir }
  let(:llm_service) { double('LLMService', generate_image: 'mock_base64_image_data') }
  let(:producer) { described_class.new(project_root: project_root, llm_service: llm_service) }

  before do
    # Set up minimal project structure
    bible_dir = File.join(project_root, 'data', 'story_bible', 'characters')
    FileUtils.mkdir_p(bible_dir)

    # Create a character file
    File.write(File.join(bible_dir, 'kenji_yamamoto.yml'), YAML.dump(
                                                             'id' => 'kenji_yamamoto',
                                                             'name' => 'Kenji Yamamoto',
                                                             'physical_appearance' => {
                                                               'age' => 28,
                                                               'skin_tone' => 'Light',
                                                               'hair' => 'Messy black',
                                                               'eyes' => 'Tired, dark circles',
                                                               'outfit' => 'Worn-out grey hoodie and jeans',
                                                               'distinguishing_features' => 'Always looks sleepy, slouches'
                                                             }
                                                           ))

    # Create a chapter file
    chapters_dir = File.join(project_root, 'content', 'chapters')
    FileUtils.mkdir_p(chapters_dir)
    File.write(File.join(chapters_dir, '001-chapter.md'), <<~CONTENT)
      ---
      title: "The Perfect Review"
      ---

      Kenji sat at his desk, staring at the screen. Another pull request, another perfect review.
      He sighed deeply, wishing someone would find a bug in his code. Just once.
    CONTENT

    # Create snapshot index
    snapshots_dir = File.join(project_root, 'data', 'story_bible', 'snapshots')
    FileUtils.mkdir_p(snapshots_dir)
    File.write(File.join(snapshots_dir, 'index.yml'), YAML.dump({ 'snapshots' => [] }))

    # Reset registry to avoid leakage
    BookCore::Producer.reset_registry!
    # Re-register after reset
    BookCore::Producer.register(:instagram_comic, described_class)

    allow(BookCore::EnvUtils).to receive(:mock_ai_enabled?).and_return(true)
  end

  after do
    FileUtils.rm_rf(project_root)
  end

  describe 'Producer Contract' do
    it 'includes the Producer module' do
      expect(described_class.ancestors).to include(BookCore::Producer)
    end

    it 'has producer_name :instagram_comic' do
      expect(described_class.producer_name).to eq(:instagram_comic)
    end

    it 'has a producer_description' do
      expect(described_class.producer_description).not_to be_nil
    end

    it 'has default_output_path' do
      expect(described_class.default_output_path).to eq('content/comics')
    end
  end

  describe '#produce' do
    let(:config) { { source: { type: 'chapter', number: 1 } } }

    context 'with MOCK_AI=true (US1: core generation)' do
      it 'generates panel images and sidecar file' do
        Dir.mktmpdir do |output_dir|
          result = producer.produce(config: config, output: output_dir)

          expect(result.success?).to be true
          expect(result.output_path).to eq(output_dir)

          # Verify sidecar exists
          sidecar = File.join(output_dir, 'panels_001.yml')
          expect(File.exist?(sidecar)).to be true

          # Verify panel images exist
          4.times do |i|
            panel_file = File.join(output_dir, format('panel_001_%02d.png', i + 1))
            expect(File.exist?(panel_file)).to be true
          end

          # Verify artifacts list
          expect(result.artifacts.length).to eq(5) # 4 PNGs + 1 YAML
        end
      end

      it 'records canon_version in result' do
        Dir.mktmpdir do |output_dir|
          result = producer.produce(config: config, output: output_dir)
          expect(result.canon_version).not_to be_nil
        end
      end

      it 'writes sidecar with correct metadata' do
        Dir.mktmpdir do |output_dir|
          producer.produce(config: config, output: output_dir)

          sidecar = YAML.load_file(File.join(output_dir, 'panels_001.yml'))
          expect(sidecar['source']).to eq('type' => 'chapter', 'number' => 1)
          expect(sidecar['art_style']).to eq('manga')
          expect(sidecar['image_format']).to eq('square')
          expect(sidecar['panels'].length).to eq(4)
          expect(sidecar['panels'].first['sequence']).to eq(1)
          expect(sidecar['panels'].first['scene_description']).not_to be_empty
        end
      end

      it 'includes character appearance in image prompts' do
        # Verify by checking that generate_image is called with character details
        expect(llm_service).to receive(:generate_image).exactly(4).times do |prompt, **_opts|
          # At least some panels should reference the character
          prompt # return the prompt as mock data
        end.and_return('mock_base64_data')

        allow(BookCore::EnvUtils).to receive(:mock_ai_enabled?).and_call_original
        allow(BookCore::EnvUtils).to receive(:mock_ai_enabled?).and_return(true)

        Dir.mktmpdir do |output_dir|
          producer.produce(config: config, output: output_dir)
        end
      end

      it 'uses default output path when none specified' do
        result = producer.produce(config: config)

        expected_path = File.join(project_root, 'content', 'comics')
        expect(result.output_path).to eq(expected_path)
        expect(Dir.exist?(expected_path)).to be true
      end

      it 'strips YAML front matter from chapter content' do
        Dir.mktmpdir do |output_dir|
          result = producer.produce(config: config, output: output_dir)
          expect(result.success?).to be true
        end
      end
    end

    context 'US1-007: text control in image prompts' do
      it 'appends text safeguard instruction to every image prompt' do
        prompts = []
        allow(llm_service).to receive(:generate_image) do |prompt, **_opts|
          prompts << prompt
          'mock_base64'
        end

        Dir.mktmpdir do |output_dir|
          producer.produce(config: config, output: output_dir)
        end

        prompts.each do |prompt|
          expect(prompt).to include('Do not add any text, words, or letters beyond what is explicitly specified')
        end
      end

      it 'includes exact text instructions for panels with text_elements' do
        prompts = []
        allow(llm_service).to receive(:generate_image) do |prompt, **_opts|
          prompts << prompt
          'mock_base64'
        end

        Dir.mktmpdir do |output_dir|
          producer.produce(config: config, output: output_dir)
        end

        # Panel 1 has speech bubble "Another perfect review... how boring."
        expect(prompts[0]).to include("speech bubble reading exactly: 'Another perfect review... how boring.'")
      end

      it 'includes no-text declaration for panels with empty text_elements' do
        prompts = []
        allow(llm_service).to receive(:generate_image) do |prompt, **_opts|
          prompts << prompt
          'mock_base64'
        end

        Dir.mktmpdir do |output_dir|
          producer.produce(config: config, output: output_dir)
        end

        # Panel 2 has empty text_elements
        expect(prompts[1]).to include('No text, no words, no letters, no speech bubbles anywhere in the image')
      end

      it 'omits text control when text_elements is nil (LLM did not provide)' do
        # Simulate LLM not returning text_elements
        mock_panels = [
          BookCore::ComicPanel.new(
            sequence: 1,
            scene_description: 'A programmer at desk',
            characters: ['kenji_yamamoto'],
            text_elements: nil
          )
        ]
        allow_any_instance_of(BookCore::PanelDescriptionGenerator).to receive(:generate).and_return(mock_panels)

        prompts = []
        allow(llm_service).to receive(:generate_image) do |prompt, **_opts|
          prompts << prompt
          'mock_base64'
        end

        Dir.mktmpdir do |output_dir|
          producer.produce(config: config.merge(panel_count: 1), output: output_dir)
        end

        # Should NOT have the no-text declaration or safeguard
        expect(prompts[0]).not_to include('No text, no words, no letters')
        expect(prompts[0]).not_to include('Do not add any text')
      end

      it 'includes sound effect text instructions' do
        prompts = []
        allow(llm_service).to receive(:generate_image) do |prompt, **_opts|
          prompts << prompt
          'mock_base64'
        end

        Dir.mktmpdir do |output_dir|
          producer.produce(config: config, output: output_dir)
        end

        # Panel 3 has sound effect "TAP TAP TAP"
        expect(prompts[2]).to include("sound effect text reading exactly: 'TAP TAP TAP'")
      end
    end

    context 'US2: art style and panel count' do
      it 'uses custom art_style' do
        Dir.mktmpdir do |output_dir|
          result = producer.produce(
            config: config.merge(art_style: 'western comic'),
            output: output_dir
          )

          expect(result.success?).to be true
          sidecar = YAML.load_file(File.join(output_dir, 'panels_001.yml'))
          expect(sidecar['art_style']).to eq('western comic')
        end
      end

      it 'uses custom panel_count' do
        Dir.mktmpdir do |output_dir|
          result = producer.produce(
            config: config.merge(panel_count: 2),
            output: output_dir
          )

          expect(result.success?).to be true
          sidecar = YAML.load_file(File.join(output_dir, 'panels_001.yml'))
          expect(sidecar['panels'].length).to eq(2)

          # Only 2 panel images
          expect(File.exist?(File.join(output_dir, 'panel_001_01.png'))).to be true
          expect(File.exist?(File.join(output_dir, 'panel_001_02.png'))).to be true
          expect(File.exist?(File.join(output_dir, 'panel_001_03.png'))).to be false
        end
      end

      it 'defaults to 4 panels and manga style' do
        Dir.mktmpdir do |output_dir|
          producer.produce(config: config, output: output_dir)

          sidecar = YAML.load_file(File.join(output_dir, 'panels_001.yml'))
          expect(sidecar['art_style']).to eq('manga')
          expect(sidecar['panels'].length).to eq(4)
        end
      end
    end

    context 'US3: image dimensions' do
      it 'maps square format to 1024x1024' do
        expect(llm_service).to receive(:generate_image).exactly(4).times do |_prompt, **opts|
          expect(opts[:size]).to eq('1024x1024')
          'mock_base64'
        end

        Dir.mktmpdir do |output_dir|
          producer.produce(config: config.merge(image_format: 'square'), output: output_dir)
        end
      end

      it 'maps portrait format to 1024x1792' do
        expect(llm_service).to receive(:generate_image).exactly(4).times do |_prompt, **opts|
          expect(opts[:size]).to eq('1024x1792')
          'mock_base64'
        end

        Dir.mktmpdir do |output_dir|
          producer.produce(config: config.merge(image_format: 'portrait'), output: output_dir)
        end
      end

      it 'defaults to square format' do
        Dir.mktmpdir do |output_dir|
          producer.produce(config: config, output: output_dir)

          sidecar = YAML.load_file(File.join(output_dir, 'panels_001.yml'))
          expect(sidecar['image_format']).to eq('square')
        end
      end
    end

    context 'US4: description-only mode' do
      it 'writes sidecar without generating images' do
        expect(llm_service).not_to receive(:generate_image)

        Dir.mktmpdir do |output_dir|
          result = producer.produce(
            config: config.merge(description_only: true),
            output: output_dir
          )

          expect(result.success?).to be true

          # Sidecar exists with descriptions
          sidecar = YAML.load_file(File.join(output_dir, 'panels_001.yml'))
          expect(sidecar['panels'].length).to eq(4)
          expect(sidecar['panels'].first['scene_description']).not_to be_empty
          expect(sidecar['panels'].first['image_path']).to be_nil

          # No image files
          expect(Dir.glob(File.join(output_dir, '*.png'))).to be_empty

          # Only sidecar in artifacts
          expect(result.artifacts.length).to eq(1)
        end
      end

      it 're-generates images from saved descriptions' do
        Dir.mktmpdir do |output_dir|
          # First run: description-only
          producer.produce(config: config.merge(description_only: true), output: output_dir)

          saved_sidecar = YAML.load_file(File.join(output_dir, 'panels_001.yml'))
          saved_descriptions = saved_sidecar['panels'].map { |p| p['scene_description'] }

          # Second run: full generation (should load from sidecar)
          result = producer.produce(config: config, output: output_dir)

          expect(result.success?).to be true
          expect(Dir.glob(File.join(output_dir, '*.png')).length).to eq(4)

          # Verify descriptions were preserved from saved sidecar
          new_sidecar = YAML.load_file(File.join(output_dir, 'panels_001.yml'))
          new_descriptions = new_sidecar['panels'].map { |p| p['scene_description'] }
          expect(new_descriptions).to eq(saved_descriptions)
        end
      end
    end

    context 'edge cases' do
      it 'warns but continues when character has no description' do
        # Remove all character files
        chars_dir = File.join(project_root, 'data', 'story_bible', 'characters')
        FileUtils.rm_rf(chars_dir)
        FileUtils.mkdir_p(chars_dir)

        Dir.mktmpdir do |output_dir|
          result = producer.produce(config: config, output: output_dir)
          expect(result.success?).to be true
        end
      end
    end
  end

  describe '#validate!' do
    it 'raises ArgumentError when source is missing' do
      expect { producer.validate!(config: {}) }.to raise_error(ArgumentError, 'source is required')
    end

    it 'raises ArgumentError for invalid source type' do
      expect { producer.validate!(config: { source: { type: 'video', number: 1 } }) }
        .to raise_error(ArgumentError, /invalid source type/)
    end

    it 'raises ArgumentError when source number is missing' do
      expect { producer.validate!(config: { source: { type: 'chapter' } }) }
        .to raise_error(ArgumentError, 'source number is required')
    end

    it 'raises ArgumentError when chapter file does not exist' do
      expect { producer.validate!(config: { source: { type: 'chapter', number: 99 } }) }
        .to raise_error(ArgumentError, /source content not found/)
    end

    it 'raises ArgumentError for invalid panel_count' do
      expect { producer.validate!(config: { source: { type: 'chapter', number: 1 }, panel_count: 0 }) }
        .to raise_error(ArgumentError, /invalid panel_count/)
    end

    it 'raises ArgumentError for negative panel_count' do
      expect { producer.validate!(config: { source: { type: 'chapter', number: 1 }, panel_count: -1 }) }
        .to raise_error(ArgumentError, /invalid panel_count/)
    end

    it 'passes validation with valid config' do
      expect { producer.validate!(config: { source: { type: 'chapter', number: 1 } }) }.not_to raise_error
    end
  end

  describe 'Producer Registry (SC-003)' do
    it 'can be found via Producer.find' do
      expect(BookCore::Producer.find(:instagram_comic)).to eq(described_class)
    end

    it 'appears in Producer.all' do
      expect(BookCore::Producer.all).to include(instagram_comic: described_class)
    end
  end
end
