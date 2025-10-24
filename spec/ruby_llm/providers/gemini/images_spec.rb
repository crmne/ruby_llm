# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini::Images do
  let(:provider) do
    Class.new do
      include RubyLLM::Providers::Gemini::Images

      attr_accessor :model

      def initialize
        @model = nil
      end
    end.new
  end

  describe '#calculate_aspect_ratio' do
    context 'with standard landscape dimensions' do
      it 'maps 1920x1080 to 16:9' do
        expect(provider.send(:calculate_aspect_ratio, '1920x1080')).to eq('16:9')
      end

      it 'maps 1024x768 to 4:3' do
        expect(provider.send(:calculate_aspect_ratio, '1024x768')).to eq('4:3')
      end

      it 'maps 2560x1080 to 21:9' do
        expect(provider.send(:calculate_aspect_ratio, '2560x1080')).to eq('21:9')
      end
    end

    context 'with portrait dimensions' do
      it 'maps 1080x1920 to 9:16' do
        expect(provider.send(:calculate_aspect_ratio, '1080x1920')).to eq('9:16')
      end

      it 'maps 768x1024 to 3:4' do
        expect(provider.send(:calculate_aspect_ratio, '768x1024')).to eq('3:4')
      end
    end

    context 'with square dimensions' do
      it 'maps 1024x1024 to 1:1' do
        expect(provider.send(:calculate_aspect_ratio, '1024x1024')).to eq('1:1')
      end

      it 'maps 512x512 to 1:1' do
        expect(provider.send(:calculate_aspect_ratio, '512x512')).to eq('1:1')
      end
    end

    context 'with edge cases' do
      it 'defaults to 1:1 for nil size' do
        expect(provider.send(:calculate_aspect_ratio, nil)).to eq('1:1')
      end

      it 'defaults to 1:1 for empty string' do
        expect(provider.send(:calculate_aspect_ratio, '')).to eq('1:1')
      end

      it 'defaults to 1:1 for invalid format' do
        expect(provider.send(:calculate_aspect_ratio, 'invalid')).to eq('1:1')
      end

      it 'defaults to 1:1 for zero width' do
        expect(provider.send(:calculate_aspect_ratio, '0x1024')).to eq('1:1')
      end

      it 'defaults to 1:1 for zero height' do
        expect(provider.send(:calculate_aspect_ratio, '1024x0')).to eq('1:1')
      end

      it 'handles negative dimensions by calculating ratio from absolute values' do
        # Negative numbers are converted to float, so -100 becomes 100.0
        result = provider.send(:calculate_aspect_ratio, '-100x200')
        expect(described_class::SUPPORTED_ASPECT_RATIOS.keys).to include(result)
      end
    end

    context 'with alternative separators' do
      it 'handles uppercase X separator' do
        expect(provider.send(:calculate_aspect_ratio, '1920X1080')).to eq('16:9')
      end

      it 'handles × (multiplication sign) separator' do
        expect(provider.send(:calculate_aspect_ratio, '1920×1080')).to eq('16:9')
      end
    end

    context 'with custom dimensions that need closest match' do
      it 'finds closest ratio for 1280x720 (matches 16:9)' do
        expect(provider.send(:calculate_aspect_ratio, '1280x720')).to eq('16:9')
      end

      it 'finds closest ratio for 800x600 (matches 4:3)' do
        expect(provider.send(:calculate_aspect_ratio, '800x600')).to eq('4:3')
      end

      it 'finds closest ratio for unusual dimensions' do
        # 1000x1200 ratio is ~0.833, closest to 5:4 (0.8) or 3:4 (0.75)
        result = provider.send(:calculate_aspect_ratio, '1000x1200')
        expect(described_class::SUPPORTED_ASPECT_RATIOS.keys).to include(result)
      end
    end
  end

  describe '#uses_generate_content?' do
    context 'when model supports generateContent' do
      it 'returns true for models with generateContent support' do
        model = instance_double(
          RubyLLM::Model::Info,
          metadata: { supported_generation_methods: ['generateContent'] }
        )
        allow(RubyLLM::Models).to receive(:find)
          .with('imagen-4.0-generate-001', :vertexai)
          .and_return(model)

        expect(provider.send(:uses_generate_content?, 'imagen-4.0-generate-001')).to be true
      end

      it 'returns true when generateContent is among multiple methods' do
        model = instance_double(
          RubyLLM::Model::Info,
          metadata: { supported_generation_methods: %w[predict generateContent] }
        )
        allow(RubyLLM::Models).to receive(:find)
          .with('some-model', :vertexai)
          .and_return(model)

        expect(provider.send(:uses_generate_content?, 'some-model')).to be true
      end
    end

    context 'when model does not support generateContent' do
      it 'returns false for models with only predict support' do
        model = instance_double(
          RubyLLM::Model::Info,
          metadata: { supported_generation_methods: ['predict'] }
        )
        allow(RubyLLM::Models).to receive(:find)
          .with('imagen-3.0-generate-002', :vertexai)
          .and_return(model)

        expect(provider.send(:uses_generate_content?, 'imagen-3.0-generate-002')).to be false
      end

      it 'returns false when model is not found' do
        allow(RubyLLM::Models).to receive(:find)
          .with('unknown-model', :vertexai)
          .and_raise(RubyLLM::ModelNotFoundError)

        expect(provider.send(:uses_generate_content?, 'unknown-model')).to be false
      end
    end
  end

  describe '#images_url' do
    it 'returns generateContent URL for models that support it' do
      provider.model = 'imagen-4.0-generate-001'
      allow(provider).to receive(:uses_generate_content?).with('imagen-4.0-generate-001').and_return(true)

      expect(provider.images_url).to eq('models/imagen-4.0-generate-001:generateContent')
    end

    it 'returns predict URL for models that do not support generateContent' do
      provider.model = 'imagen-3.0-generate-002'
      allow(provider).to receive(:uses_generate_content?).with('imagen-3.0-generate-002').and_return(false)

      expect(provider.images_url).to eq('models/imagen-3.0-generate-002:predict')
    end
  end

  describe '#render_image_payload' do
    context 'when model uses generateContent' do
      before do
        allow(provider).to receive(:uses_generate_content?).and_return(true)
      end

      it 'returns generateContent payload with aspect ratio' do
        payload = provider.render_image_payload('a cat', model: 'imagen-4.0', size: '1024x1024')

        expect(payload).to include(:contents, :generationConfig)
        expect(payload[:contents]).to be_an(Array)
        expect(payload[:contents][0][:role]).to eq('user')
        expect(payload[:contents][0][:parts][0][:text]).to eq('a cat')
        expect(payload[:generationConfig][:responseModalities]).to eq(['IMAGE'])
        expect(payload[:generationConfig][:imageConfig][:aspectRatio]).to eq('1:1')
      end

      it 'calculates aspect ratio from size parameter' do
        payload = provider.render_image_payload('a landscape', model: 'imagen-4.0', size: '1920x1080')

        expect(payload[:generationConfig][:imageConfig][:aspectRatio]).to eq('16:9')
      end
    end

    context 'when model uses predict' do
      before do
        allow(provider).to receive(:uses_generate_content?).and_return(false)
      end

      it 'returns predict payload' do
        payload = provider.render_image_payload('a cat', model: 'imagen-3.0', size: '1024x1024')

        expect(payload).to include(:instances, :parameters)
        expect(payload[:instances]).to be_an(Array)
        expect(payload[:instances][0][:prompt]).to eq('a cat')
        expect(payload[:parameters][:sampleCount]).to eq(1)
      end

      it 'does not include aspect ratio configuration' do
        payload = provider.render_image_payload('a cat', model: 'imagen-3.0', size: '1920x1080')

        expect(payload).not_to have_key(:generationConfig)
        expect(payload).not_to have_key(:imageConfig)
      end
    end
  end
end
