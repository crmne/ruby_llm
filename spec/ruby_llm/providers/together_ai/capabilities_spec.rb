# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::TogetherAI::Capabilities do
  describe '.supports_streaming?' do
    it 'returns true for chat models' do
      expect(described_class.supports_streaming?('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')).to be true
    end

    it 'returns false for non-chat models' do
      expect(described_class.supports_streaming?('BAAI/bge-large-en-v1.5')).to be false
    end
  end

  describe '.supports_vision?' do
    it 'returns true for vision models' do
      expect(described_class.supports_vision?('meta-llama/Llama-4-Scout-17B-16E-Instruct')).to be true
    end

    it 'returns false for non-vision models' do
      expect(described_class.supports_vision?('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')).to be false
    end
  end

  describe '.supports_functions?' do
    it 'returns true for chat models' do
      expect(described_class.supports_functions?('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')).to be true
    end

    it 'returns false for non-tool models' do
      expect(described_class.supports_functions?('BAAI/bge-large-en-v1.5')).to be false
    end
  end

  describe '.supports_json_mode?' do
    it 'returns true for chat models' do
      expect(described_class.supports_json_mode?('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')).to be true
    end

    it 'returns false for non-chat models' do
      expect(described_class.supports_json_mode?('BAAI/bge-large-en-v1.5')).to be false
    end

    it 'returns false for audio models' do
      expect(described_class.supports_json_mode?('openai/whisper-large-v3')).to be false
    end
  end

  describe '.normalize_temperature' do
    it 'returns nil when temperature is nil' do
      expect(described_class.normalize_temperature(nil, 'model')).to be_nil
    end

    it 'clamps temperature to minimum 0.0' do
      expect(described_class.normalize_temperature(-0.5, 'model')).to eq(0.0)
    end

    it 'clamps temperature to maximum 2.0' do
      expect(described_class.normalize_temperature(2.5, 'model')).to eq(2.0)
    end

    it 'preserves valid temperature values' do
      expect(described_class.normalize_temperature(1.0, 'model')).to eq(1.0)
      expect(described_class.normalize_temperature(0.7, 'model')).to eq(0.7)
    end
  end

  describe '.format_display_name' do
    it 'formats model ID to display name' do
      expect(described_class.format_display_name('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo'))
        .to eq('Meta Llama 3.1 8 B Instruct Turbo')
      expect(described_class.format_display_name('Qwen/Qwen2.5-72B-Instruct-Turbo'))
        .to eq('Qwen2.5 72 B Instruct Turbo')
    end
  end

  describe '.model_family' do
    it 'identifies Llama models' do
      expect(described_class.model_family('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')).to eq('llama')
    end

    it 'identifies Qwen models' do
      expect(described_class.model_family('Qwen/Qwen2.5-72B-Instruct-Turbo')).to eq('qwen')
    end

    it 'identifies Mistral models' do
      expect(described_class.model_family('mistralai/Mistral-7B-Instruct-v0.3')).to eq('mistral')
    end

    it 'identifies DeepSeek models' do
      expect(described_class.model_family('deepseek-ai/deepseek-v3')).to eq('deepseek')
    end

    it 'defaults to other for unknown models' do
      expect(described_class.model_family('unknown/model')).to eq('other')
    end
  end

  describe '.context_window_for' do
    it 'returns appropriate context windows for different model sizes' do
      expect(described_class.context_window_for('meta-llama/Meta-Llama-3.1-405B-Instruct-Turbo')).to eq(130_815)
      expect(described_class.context_window_for('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')).to eq(131_072)
      expect(described_class.context_window_for('Qwen/Qwen2.5-72B-Instruct-Turbo')).to eq(32_768)
      expect(described_class.context_window_for('moonshotai/Kimi-K2-Instruct-0905')).to eq(262_144)
      expect(described_class.context_window_for('deepseek-ai/DeepSeek-V3.1')).to eq(128_000)
      expect(described_class.context_window_for('unknown/model')).to eq(16_384)
    end
  end

  describe '.supports_tools_for?' do
    it 'returns true for chat models' do
      expect(described_class.supports_tools_for?('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')).to be true
      expect(described_class.supports_tools_for?('Qwen/Qwen2.5-72B-Instruct-Turbo')).to be true
      expect(described_class.supports_tools_for?('deepseek-ai/DeepSeek-V3.1')).to be true
    end

    it 'returns false for non-chat models' do
      expect(described_class.supports_tools_for?('BAAI/bge-large-en-v1.5')).to be false
      expect(described_class.supports_tools_for?('black-forest-labs/FLUX.1-schnell')).to be false
      expect(described_class.supports_tools_for?('openai/whisper-large-v3')).to be false
      expect(described_class.supports_tools_for?('cartesia/sonic-2')).to be false
    end
  end

  describe '.supports_embeddings_for?' do
    it 'returns true for embedding models' do
      expect(described_class.supports_embeddings_for?('BAAI/bge-large-en-v1.5')).to be true
      expect(described_class.supports_embeddings_for?('togethercomputer/m2-bert-80M-32k-retrieval')).to be true
    end

    it 'returns false for non-embedding models' do
      expect(described_class.supports_embeddings_for?('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')).to be false
    end
  end

  describe '.supports_images_for?' do
    it 'returns true for image generation models' do
      expect(described_class.supports_images_for?('black-forest-labs/FLUX.1-schnell')).to be true
      expect(described_class.supports_images_for?('google/imagen-4.0-preview')).to be true
      expect(described_class.supports_images_for?('stabilityai/stable-diffusion-xl-base-1.0')).to be true
    end

    it 'returns false for non-image models' do
      expect(described_class.supports_images_for?('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')).to be false
    end
  end

  describe '.supports_vision_for?' do
    it 'returns true for vision models' do
      expect(described_class.supports_vision_for?('meta-llama/Llama-4-Scout-17B-16E-Instruct')).to be true
      expect(described_class.supports_vision_for?('Qwen/Qwen2.5-VL-72B-Instruct')).to be true
      expect(described_class.supports_vision_for?('arcee_ai/arcee-spotlight')).to be true
    end

    it 'returns false for non-vision models' do
      expect(described_class.supports_vision_for?('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')).to be false
    end
  end

  describe '.supports_audio_for?' do
    it 'returns true for audio models' do
      expect(described_class.supports_audio_for?('cartesia/sonic-2')).to be true
      expect(described_class.supports_audio_for?('openai/whisper-large-v3')).to be true
      expect(described_class.supports_audio_for?('canopylabs/orpheus-3b-0.1-ft')).to be true
    end

    it 'returns false for non-audio models' do
      expect(described_class.supports_audio_for?('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')).to be false
    end
  end

  describe '.supports_moderation_for?' do
    it 'returns true for moderation models' do
      expect(described_class.supports_moderation_for?('meta-llama/Llama-Guard-4-12B')).to be true
      expect(described_class.supports_moderation_for?('VirtueAI/VirtueGuard-Text-Lite')).to be true
    end

    it 'returns false for non-moderation models' do
      expect(described_class.supports_moderation_for?('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')).to be false
    end
  end

  describe '.modalities_for' do
    it 'returns text input/output for chat models' do
      result = described_class.modalities_for('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')
      expect(result[:input]).to eq(['text'])
      expect(result[:output]).to eq(['text'])
    end

    it 'includes image input for vision models' do
      result = described_class.modalities_for('meta-llama/Llama-4-Scout-17B-16E-Instruct')
      expect(result[:input]).to include('image')
    end

    it 'includes image output for image generation models' do
      result = described_class.modalities_for('black-forest-labs/FLUX.1-schnell')
      expect(result[:output]).to include('image')
    end

    it 'includes audio input for transcription models' do
      result = described_class.modalities_for('openai/whisper-large-v3')
      expect(result[:input]).to include('audio')
    end

    it 'includes audio output for TTS models' do
      result = described_class.modalities_for('cartesia/sonic-2')
      expect(result[:output]).to include('audio')
    end
  end

  describe '.capabilities_for' do
    it 'returns appropriate capabilities for chat models' do
      result = described_class.capabilities_for('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')
      expect(result).to include('chat', 'streaming', 'tools', 'json_mode')
      expect(result).not_to include('embeddings', 'images')
    end

    it 'returns appropriate capabilities for embedding models' do
      result = described_class.capabilities_for('BAAI/bge-large-en-v1.5')
      expect(result).to include('embeddings')
      expect(result).not_to include('chat', 'tools', 'streaming')
    end

    it 'returns appropriate capabilities for image models' do
      result = described_class.capabilities_for('black-forest-labs/FLUX.1-schnell')
      expect(result).to include('images')
      expect(result).not_to include('chat', 'embeddings', 'streaming')
    end

    it 'returns appropriate capabilities for vision models' do
      result = described_class.capabilities_for('meta-llama/Llama-4-Scout-17B-16E-Instruct')
      expect(result).to include('chat', 'streaming', 'tools', 'json_mode', 'vision')
    end
  end

  describe '.model_type' do
    it 'returns chat for chat models' do
      expect(described_class.model_type('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')).to eq('chat')
    end

    it 'returns embedding for embedding models' do
      expect(described_class.model_type('BAAI/bge-large-en-v1.5')).to eq('embedding')
    end

    it 'returns image for image generation models' do
      expect(described_class.model_type('black-forest-labs/FLUX.1-schnell')).to eq('image')
    end

    it 'returns audio for audio models' do
      expect(described_class.model_type('cartesia/sonic-2')).to eq('audio')
    end

    it 'returns moderation for moderation models' do
      expect(described_class.model_type('meta-llama/Llama-Guard-4-12B')).to eq('moderation')
    end
  end
end
