# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::MiniMax do # rubocop:disable RSpec/SpecFilePathFormat
  before { RubyLLM.config.minimax_api_key = 'test' }

  it 'registers the complete speech model catalog' do
    expect(described_class::MODELS).to eq(
      %w[
        speech-2.8-hd speech-2.8-turbo speech-2.6-hd speech-2.6-turbo
        speech-02-hd speech-02-turbo speech-01-hd speech-01-turbo
      ]
    )
  end

  it 'supports the global and China endpoints' do
    expect(described_class.new(RubyLLM.config).api_base).to eq('https://api.minimax.io/v1')

    RubyLLM.config.minimax_api_base = 'https://api.minimaxi.com/v1'
    provider = described_class.new(RubyLLM.config)
    expect(provider.api_base).to eq('https://api.minimaxi.com/v1')
    expect(provider.speech_websocket_url).to eq('wss://api.minimaxi.com/ws/v1/t2a_v2')
  end

  it 'registers as a speech-only provider with bearer authentication' do
    provider = described_class.new(RubyLLM.config)

    expect(RubyLLM::Provider.providers[:minimax]).to eq(described_class)
    expect(provider.headers).to eq('Authorization' => 'Bearer test')
    expect(described_class.configuration_options).to eq(%i[minimax_api_key minimax_api_base])
  end
end
