# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Anthropic API Request Headers' do # rubocop:disable RSpec/DescribeClass
  include_context 'with configured RubyLLM'

  before do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  after do
    WebMock.allow_net_connect!
  end

  it 'includes the beta header for claude-3-7-sonnet-20250219' do # rubocop:disable RSpec/ExampleLength
    # Setup the expected request with the beta header
    stub_request(:post, 'https://api.anthropic.com/v1/messages')
      .with(
        headers: {
          'Anthropic-Beta' => 'output-128k-2025-02-19'
        }
      )
      .to_return(
        status: 200,
        body: {
          id: 'msg_123',
          model: 'claude-3-7-sonnet-20250219',
          type: 'message',
          role: 'assistant',
          content: [{ type: 'text', text: 'Hello!' }],
          usage: { input_tokens: 10, output_tokens: 20 }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Make a request with the specific model
    chat = RubyLLM.chat(model: 'claude-3-7-sonnet-20250219')
    chat.ask('Hello')

    # Verify that the request was made with the expected headers
    expect(
      a_request(:post, 'https://api.anthropic.com/v1/messages')
        .with(headers: { 'Anthropic-Beta' => 'output-128k-2025-02-19' })
    ).to have_been_made
  end

  it 'does not include the beta header for other Claude models' do # rubocop:disable RSpec/ExampleLength
    # Setup the expected request without the beta header
    stub_request(:post, 'https://api.anthropic.com/v1/messages')
      .with { |request| !request.headers.key?('Anthropic-Beta') }
      .to_return(
        status: 200,
        body: {
          id: 'msg_456',
          model: 'claude-3-5-sonnet-20241022',
          type: 'message',
          role: 'assistant',
          content: [{ type: 'text', text: 'Hello!' }],
          usage: { input_tokens: 10, output_tokens: 20 }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Make a request with a different model
    chat = RubyLLM.chat(model: 'claude-3-5-sonnet-20241022')
    chat.ask('Hello')

    # Verify that the request was made without the beta header
    expect(
      a_request(:post, 'https://api.anthropic.com/v1/messages')
        .with { |request| !request.headers.key?('Anthropic-Beta') }
    ).to have_been_made
  end

  it 'includes the beta header in streaming responses for claude-3-7-sonnet-20250219' do # rubocop:disable RSpec/ExampleLength
    streaming_body = <<~STREAM_DATA
      event: content_block_delta
      data: {"type":"content_block_delta","delta":{"type":"text","text":"Hello"}}

      event: content_block_delta
      data: {"type":"content_block_delta","delta":{"type":"text","text":"!"}}

      event: message_stop
      data: {}
    STREAM_DATA

    # Setup the expected streaming request with the beta header
    stub_request(:post, 'https://api.anthropic.com/v1/messages')
      .with(
        headers: {
          'Anthropic-Beta' => 'output-128k-2025-02-19'
        },
        body: hash_including('stream' => true)
      )
      .to_return(
        status: 200,
        body: streaming_body,
        headers: { 'Content-Type' => 'text/event-stream' }
      )

    # Make a streaming request with the specific model
    chat = RubyLLM.chat(model: 'claude-3-7-sonnet-20250219')
    chunks = []
    chat.ask('Hello') { |chunk| chunks << chunk }

    # Verify that the streaming request was made with the expected headers
    expect(
      a_request(:post, 'https://api.anthropic.com/v1/messages')
        .with(
          headers: { 'Anthropic-Beta' => 'output-128k-2025-02-19' },
          body: hash_including('stream' => true)
        )
    ).to have_been_made
  end
end
