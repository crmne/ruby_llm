# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::Streaming do
  include_context 'with configured RubyLLM'

  let(:protocol) do
    RubyLLM::Protocols::Anthropic.allocate.tap do |object|
      object.instance_variable_set(:@model, instance_double(RubyLLM::Model::Info, id: 'claude-sonnet-4-5'))
    end
  end

  it 'preserves raw stop_reason from message_delta events' do
    chunk = protocol.send(
      :build_chunk,
      {
        'type' => 'message_delta',
        'delta' => { 'stop_reason' => 'end_turn' },
        'usage' => { 'output_tokens' => 10 }
      }
    )

    expect(chunk.finish_reason).to eq('end_turn')
  end

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
