# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#with_image_config' do
    let(:chat) { RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini) }

    it 'returns self for method chaining' do
      result = chat.with_image_config(aspect_ratio: '16:9')
      expect(result).to eq(chat)
    end

    it 'sets aspect_ratio as aspectRatio' do
      chat.with_image_config(aspect_ratio: '16:9')
      expect(chat.image_config).to eq({ aspectRatio: '16:9' })
    end

    it 'sets image_size as imageSize' do
      chat.with_image_config(image_size: '2K')
      expect(chat.image_config).to eq({ imageSize: '2K' })
    end

    it 'sets both aspect_ratio and image_size' do
      chat.with_image_config(aspect_ratio: '16:9', image_size: '2K')
      expect(chat.image_config).to eq({ aspectRatio: '16:9', imageSize: '2K' })
    end

    it 'sets image_config to nil when no options provided' do
      chat.with_image_config
      expect(chat.image_config).to be_nil
    end

    it 'can be chained with other methods' do
      result = chat
               .with_temperature(1.0)
               .with_image_config(aspect_ratio: '16:9', image_size: '2K')

      expect(result.image_config).to eq({ aspectRatio: '16:9', imageSize: '2K' })
    end
  end

  describe 'effective_params with image_config' do
    let(:chat) { RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini) }

    it 'merges image_config into generationConfig' do
      chat.with_image_config(aspect_ratio: '16:9')
      effective = chat.send(:effective_params)

      expect(effective[:generationConfig][:imageConfig]).to eq({ aspectRatio: '16:9' })
    end

    it 'preserves existing params when merging image_config' do
      chat.with_params(generationConfig: { temperature: 0.5 })
      chat.with_image_config(aspect_ratio: '16:9')
      effective = chat.send(:effective_params)

      expect(effective[:generationConfig][:temperature]).to eq(0.5)
      expect(effective[:generationConfig][:imageConfig]).to eq({ aspectRatio: '16:9' })
    end

    it 'returns params unchanged when image_config is nil' do
      chat.with_params(generationConfig: { temperature: 0.5 })
      effective = chat.send(:effective_params)

      expect(effective).to eq({ generationConfig: { temperature: 0.5 } })
      expect(effective[:generationConfig]).not_to have_key(:imageConfig)
    end
  end
end
