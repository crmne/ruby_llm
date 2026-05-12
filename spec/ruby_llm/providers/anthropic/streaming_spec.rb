# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Streaming do
  include_context 'with configured RubyLLM'

  it 'sends Accept-Encoding: identity on streaming requests' do
    captured = nil

    stub_request(:post, %r{api\.anthropic\.com/v1/messages})
      .with { |req| captured = req.headers['Accept-Encoding'] }
      .to_return(
        status: 200,
        body: '',
        headers: { 'Content-Type' => 'text/event-stream' }
      )

    chat = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic)
    chat.ask('hi') { |_chunk| nil }

    expect(captured).to eq('identity')
  end
end
