# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Capabilities do
  describe '.model_family' do
    {
      'gpt-image-1.5' => 'gpt_image15',
      'gpt-image-1-mini' => 'gpt_image_mini',
      'gpt-image-1' => 'gpt_image',
      'gpt-4.1' => 'gpt41',
      'gpt-4.1-mini' => 'gpt41_mini',
      'gpt-4.1-nano' => 'gpt41_nano',
      'gpt-4' => 'gpt4',
      'gpt-4-turbo' => 'gpt4_turbo',
      'gpt-3.5-turbo' => 'gpt35_turbo',
      'gpt-4o' => 'gpt4o',
      'gpt-4o-audio-preview' => 'gpt4o_audio',
      'gpt-4o-mini' => 'gpt4o_mini',
      'gpt-4o-mini-audio-preview' => 'gpt4o_mini_audio',
      'gpt-4o-mini-realtime-preview' => 'gpt4o_mini_realtime',
      'gpt-4o-mini-transcribe' => 'gpt4o_mini_transcribe',
      'gpt-4o-mini-tts' => 'gpt4o_mini_tts',
      'gpt-4o-realtime-preview' => 'gpt4o_realtime',
      'gpt-4o-search-preview' => 'gpt4o_search',
      'gpt-4o-transcribe' => 'gpt4o_transcribe',
      'gpt-5' => 'gpt5',
      'gpt-5-mini' => 'gpt5_mini',
      'gpt-5-nano' => 'gpt5_nano',
      'o1' => 'o1',
      'o1-mini' => 'o1_mini',
      'o1-pro' => 'o1_pro',
      'o3-mini' => 'o3_mini',
      'babbage-002' => 'babbage',
      'davinci-002' => 'davinci',
      'text-embedding-3-large' => 'embedding3_large',
      'text-embedding-3-small' => 'embedding3_small',
      'text-embedding-ada-002' => 'embedding_ada',
      'tts-1' => 'tts1',
      'tts-1-hd' => 'tts1_hd',
      'whisper-1' => 'whisper',
      'omni-moderation-latest' => 'moderation',
      'chatgpt-4o-latest' => 'other'
    }.each do |model_id, expected|
      it "groups #{model_id} under #{expected}" do
        expect(described_class.model_family(model_id)).to eq(expected)
      end
    end
  end

  describe '.context_window_for' do
    {
      'gpt-4.1' => 1_047_576,
      'gpt-5' => 128_000,
      'gpt-4' => 8_192,
      'gpt-4o-mini-transcribe' => 16_000,
      'o1' => 200_000,
      'o1-pro' => 200_000,
      'o3-mini' => 200_000,
      'gpt-3.5-turbo' => 16_385,
      'chatgpt-4o-latest' => 4_096,
      'tts-1' => nil,
      'whisper-1' => nil,
      'gpt-image-1' => nil
    }.each do |model_id, expected|
      it "reports #{expected.inspect} for #{model_id}" do
        expect(described_class.context_window_for(model_id)).to eq(expected)
      end
    end
  end

  describe '.max_tokens_for' do
    {
      'gpt-5' => 400_000,
      'gpt-4.1' => 32_768,
      'gpt-4' => 8_192,
      'gpt-3.5-turbo' => 4_096,
      'gpt-4o-mini-transcribe' => 2_000,
      'o1' => 100_000,
      'o1-mini' => 65_536,
      'gpt-4o' => 16_384,
      'text-embedding-3-small' => nil
    }.each do |model_id, expected|
      it "reports #{expected.inspect} for #{model_id}" do
        expect(described_class.max_tokens_for(model_id)).to eq(expected)
      end
    end
  end

  describe '.critical_capabilities_for' do
    it 'reports the tool and structured-output set for a chat model' do
      expect(described_class.critical_capabilities_for('gpt-4o')).to eq(
        %w[function_calling tool_choice parallel_tool_calls structured_output vision]
      )
    end

    it 'adds reasoning for the o-series and GPT-5' do
      expect(described_class.critical_capabilities_for('o1')).to include('reasoning')
      expect(described_class.critical_capabilities_for('gpt-5')).to include('reasoning')
    end

    it 'omits vision for the plain GPT-4 family' do
      %w[gpt-4 gpt-4-0613 gpt-4-0314].each do |model_id|
        expect(described_class.critical_capabilities_for(model_id)).not_to include('vision')
      end
    end

    it 'keeps vision for the turbo, omni and 4.1 families' do
      %w[gpt-4-turbo gpt-4o gpt-4o-mini gpt-4.1].each do |model_id|
        expect(described_class.critical_capabilities_for(model_id)).to include('vision')
      end
    end

    it 'adds citations for the web-search models' do
      expect(described_class.critical_capabilities_for('gpt-4o-search-preview')).to include('citations')
    end

    it 'adds transcription for speech-to-text models' do
      %w[whisper-1 gpt-4o-transcribe gpt-4o-mini-transcribe].each do |model_id|
        expect(described_class.critical_capabilities_for(model_id)).to include('transcription')
      end
    end

    it 'reports nothing for an embedding model' do
      expect(described_class.critical_capabilities_for('text-embedding-3-small')).to eq([])
    end
  end

  describe '.pricing_for' do
    it 'reports text pricing with the cached input tier' do
      expect(described_class.pricing_for('gpt-5-nano')).to eq(
        text_tokens: {
          standard: {
            input_per_million: 0.05,
            output_per_million: 0.4,
            cache_read_input_per_million: 0.005
          }
        }
      )
    end

    it 'omits the cached tier when the family has no cached price' do
      expect(described_class.pricing_for('gpt-4')).to eq(
        text_tokens: { standard: { input_per_million: 10.0, output_per_million: 30.0 } }
      )
    end

    it 'spreads a single price across input and output' do
      expect(described_class.pricing_for('whisper-1')).to eq(
        text_tokens: { standard: { input_per_million: 0.006, output_per_million: 0.006 } }
      )
    end

    it 'falls back to the default rates for unknown families' do
      expect(described_class.pricing_for('chatgpt-4o-latest')).to eq(
        text_tokens: { standard: { input_per_million: 0.5, output_per_million: 1.5 } }
      )
    end

    it 'reports separate text and image tiers for image models' do
      expect(described_class.pricing_for('gpt-image-1')).to eq(
        text_tokens: {
          standard: { input_per_million: 5.0, cache_read_input_per_million: 1.25 }
        },
        images: {
          standard: {
            input_per_million: 10.0,
            output_per_million: 40.0,
            cache_read_input_per_million: 2.5
          }
        }
      )
    end

    it 'reports the text output price when the image family charges for it' do
      expect(described_class.pricing_for('gpt-image-1.5')[:text_tokens][:standard]).to include(
        input_per_million: 5.0
      )
      expect(described_class.output_price_for('gpt-image-1.5')).to eq(10.0)
    end
  end

  describe '.image_model?' do
    it 'recognizes only the image families' do
      expect(described_class.image_model?('gpt-image-1')).to be(true)
      expect(described_class.image_model?('gpt-image-1-mini')).to be(true)
      expect(described_class.image_model?('gpt-image-1.5')).to be(true)
      expect(described_class.image_model?('gpt-4o')).to be(false)
    end
  end

  describe '.cached_input_price_for' do
    it 'returns nil when the family has no cached tier' do
      expect(described_class.cached_input_price_for('gpt-4')).to be_nil
    end

    it 'reads the text tier for image models' do
      expect(described_class.cached_input_price_for('gpt-image-1-mini')).to eq(0.2)
    end
  end
end
