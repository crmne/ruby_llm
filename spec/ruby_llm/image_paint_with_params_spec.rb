# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Image, '.paint' do
  describe 'OpenAI render_image_payload with params' do
    it 'merges custom params like quality, output_format, n' do
      payload = RubyLLM::Providers::OpenAI::Images.render_image_payload(
        'a cat',
        model: 'gpt-image-1',
        size: '1024x1024',
        params: { quality: 'medium', output_format: 'jpeg', output_compression: 80 }
      )
      expect(payload[:model]).to eq('gpt-image-1')
      expect(payload[:prompt]).to eq('a cat')
      expect(payload[:size]).to eq('1024x1024')
      expect(payload[:quality]).to eq('medium')
      expect(payload[:output_format]).to eq('jpeg')
      expect(payload[:output_compression]).to eq(80)
    end

    it 'default (no params) is unchanged' do
      payload = RubyLLM::Providers::OpenAI::Images.render_image_payload(
        'a cat',
        model: 'dall-e-3',
        size: '1024x1024'
      )
      expect(payload).to eq({ model: 'dall-e-3', prompt: 'a cat', n: 1, size: '1024x1024' })
    end

    it 'params override defaults when keys collide (e.g. n)' do
      payload = RubyLLM::Providers::OpenAI::Images.render_image_payload(
        'a cat',
        model: 'dall-e-3',
        size: '1024x1024',
        params: { n: 3 }
      )
      expect(payload[:n]).to eq(3)
    end
  end

  describe 'Gemini render_image_payload with params' do
    let(:provider) do
      Class.new do
        include RubyLLM::Providers::Gemini::Images
      end.new
    end

    it 'merges params into parameters hash (not top level)' do
      payload = provider.render_image_payload(
        'a cat',
        model: 'imagen-3',
        size: '1024x1024',
        params: { personGeneration: 'ALLOW_ADULT', aspectRatio: '16:9' }
      )
      expect(payload[:parameters][:personGeneration]).to eq('ALLOW_ADULT')
      expect(payload[:parameters][:aspectRatio]).to eq('16:9')
      expect(payload[:parameters][:sampleCount]).to eq(1)
    end
  end

  describe 'OpenRouter render_image_payload with params' do
    it 'merges params at top level of chat-completions-shaped payload' do
      payload = RubyLLM::Providers::OpenRouter::Images.render_image_payload(
        'a cat',
        model: 'anthropic/claude-3-opus',
        size: '1024x1024',
        params: { temperature: 0.5 }
      )
      expect(payload[:temperature]).to eq(0.5)
    end
  end
end
