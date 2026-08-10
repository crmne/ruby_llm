# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::XAI::Images do
  describe '.render_image_payload' do
    it 'drops the size parameter xAI rejects' do
      payload = described_class.render_image_payload('a cute cat', model: 'grok-imagine-image', size: '1024x1024')

      expect(payload).to eq(model: 'grok-imagine-image', prompt: 'a cute cat')
    end

    it 'merges provider options' do
      payload = described_class.render_image_payload('a cute cat', model: 'grok-imagine-image', size: nil,
                                                                   provider_options: { n: 2 })

      expect(payload[:n]).to eq(2)
    end
  end
end
