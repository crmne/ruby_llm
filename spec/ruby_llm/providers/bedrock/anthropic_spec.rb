# frozen_string_literal: true

require 'spec_helper'
require 'aws-eventstream'

class BedrockAnthropicWeather < RubyLLM::Tool
  description 'Looks up the current weather for a city'
  parameter :city, description: 'City name'

  def execute(city:)
    "Sunny in #{city}"
  end
end

RSpec.describe RubyLLM::Providers::Bedrock::Anthropic do
  let(:context) do
    RubyLLM.context do |config|
      config.bedrock_api_key = 'key'
      config.bedrock_secret_key = 'secret'
      config.bedrock_region = 'eu-central-1'
      config.max_retries = 0
    end
  end
  let(:model_id) { 'eu.anthropic.claude-sonnet-5-5' }
  let(:runtime) { 'https://bedrock-runtime.eu-central-1.amazonaws.com' }
  let(:chat) { context.chat(model: model_id, provider: :bedrock, assume_model_exists: true) }
  let(:reply) do
    { id: 'msg_1', type: 'message', role: 'assistant', model: 'claude-sonnet-5-5', stop_reason: 'end_turn',
      content: [{ type: 'text', text: 'Hi' }],
      usage: { input_tokens: 3, output_tokens: 1, cache_read_input_tokens: 2, cache_creation_input_tokens: 4 } }
  end

  def stub_invoke(&matcher)
    matcher ||= proc { true }
    stub_request(:post, "#{runtime}/model/#{model_id}/invoke")
      .with(&matcher)
      .to_return(body: reply.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def frame(event)
    message = Aws::EventStream::Message.new(
      headers: { ':message-type' => 'event', ':event-type' => 'chunk' }.transform_values do |value|
        Aws::EventStream::HeaderValue.new(value:, type: 'string')
      end,
      payload: StringIO.new({ bytes: Base64.strict_encode64(event.to_json) }.to_json)
    )
    Aws::EventStream::Encoder.new.encode_message(message)
  end

  describe 'request body' do
    it 'renders an InvokeModel body without the model or stream fields' do
      chat.ask_later('Say OK.')
      payload = chat.render

      expect(payload).to include(anthropic_version: 'bedrock-2023-05-31', max_tokens: be_positive)
      expect(payload).not_to include(:model, :stream)
      expect(payload[:messages].first[:role]).to eq('user')
    end

    it 'sends deferred tools with the tool search tool and its Bedrock beta in the body' do
      body = nil
      request = stub_invoke { |req| body = JSON.parse(req.body) }

      chat.with_tools(BedrockAnthropicWeather, defer: true).ask('Weather in Berlin?')

      expect(request).to have_been_requested
      expect(body['tools']).to include(
        include('name' => 'bedrock_anthropic_weather', 'defer_loading' => true),
        'type' => 'tool_search_tool_bm25_20251119', 'name' => 'tool_search_tool_bm25'
      )
      expect(body['anthropic_beta']).to eq(['tool-search-tool-2025-10-19'])
      expect(body).not_to include('model', 'stream')
    end

    it 'moves betas from headers into the body' do
      body = nil
      headers = nil
      stub_invoke do |req|
        body = JSON.parse(req.body)
        headers = req.headers
      end

      chat.with_headers('anthropic-beta' => 'compact-2026-01-12').ask('Hi')

      expect(body['anthropic_beta']).to eq(['compact-2026-01-12'])
      expect(headers.keys.map(&:downcase)).not_to include('anthropic-beta')
    end

    it 'sends remote images as bytes because Bedrock does not fetch URLs' do
      image = File.binread(File.expand_path('../../../fixtures/ruby.png', __dir__))
      stub_request(:get, 'https://example.com/ruby').to_return(body: image, headers: { 'Content-Type' => 'image/png' })
      chat.ask_later('What is this?', with: 'https://example.com/ruby')

      source = chat.render[:messages].first[:content].find { |block| block[:type] == 'image' }[:source]

      expect(source).to eq(type: 'base64', media_type: 'image/png', data: Base64.strict_encode64(image))
    end
  end

  describe 'responses' do
    it 'parses usage, including cache reads and writes' do
      stub_invoke

      response = chat.ask('Hi')

      expect(response.content).to eq('Hi')
      expect(response.tokens).to have_attributes(input: 3, output: 1, cache_read: 2, cache_write: 4)
    end

    it 'decodes Anthropic events from the InvokeModel event stream' do
      events = [
        { type: 'message_start',
          message: { model: 'claude-sonnet-5-5', usage: { input_tokens: 5, output_tokens: 0 } } },
        { type: 'content_block_start', index: 0, content_block: { type: 'text', text: '' } },
        { type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: 'Hel' } },
        { type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: 'lo' } },
        { type: 'content_block_stop', index: 0 },
        { type: 'message_delta', delta: { stop_reason: 'end_turn' }, usage: { output_tokens: 2 } },
        { type: 'message_stop' }
      ]
      stub_request(:post, "#{runtime}/model/#{model_id}/invoke-with-response-stream")
        .with { |req| !JSON.parse(req.body).key?('stream') }
        .to_return(body: events.map { |event| frame(event) }.join,
                   headers: { 'Content-Type' => 'application/vnd.amazon.eventstream' })
      chunks = []

      response = chat.ask('Hi') { |chunk| chunks << chunk.content }

      expect(chunks.compact.join).to eq('Hello')
      expect(response).to have_attributes(content: 'Hello', finish_reason: :stop)
      expect(response.tokens).to have_attributes(input: 5, output: 2)
    end

    it 'raises the exception a stream reports' do
      message = Aws::EventStream::Message.new(
        headers: { ':message-type' => 'exception', ':exception-type' => 'throttlingException' }.transform_values do |v|
          Aws::EventStream::HeaderValue.new(value: v, type: 'string')
        end,
        payload: StringIO.new({ message: 'Too many requests' }.to_json)
      )
      stub_request(:post, "#{runtime}/model/#{model_id}/invoke-with-response-stream")
        .to_return(body: Aws::EventStream::Encoder.new.encode_message(message))

      expect { chat.ask('Hi') { |_chunk| nil } }.to raise_error(RubyLLM::RateLimitError, /Too many requests/)
    end
  end

  describe 'token counting' do
    it 'counts against the foundation model with an InvokeModel body' do
      sent = nil
      stub_request(:post, "#{runtime}/model/anthropic.claude-sonnet-5-5/count-tokens")
        .with { |req| sent = JSON.parse(Base64.decode64(JSON.parse(req.body).dig('input', 'invokeModel', 'body'))) }
        .to_return(body: { inputTokens: 42 }.to_json, headers: { 'Content-Type' => 'application/json' })

      count = chat.with_tools(BedrockAnthropicWeather, defer: true).count_tokens('Weather in Berlin?')

      expect(count).to eq(42)
      expect(sent).to include('anthropic_version' => 'bedrock-2023-05-31', 'max_tokens' => 1,
                              'anthropic_beta' => ['tool-search-tool-2025-10-19'])
      expect(sent).not_to include('model')
    end
  end

  describe 'protocol override' do
    it 'keeps Converse available for Claude' do
      converse = context.chat(model: model_id, provider: :bedrock, protocol: :converse, assume_model_exists: true)
      converse.ask_later('Say OK.')

      expect(converse.render).to include(:messages, :inferenceConfig)
      expect(converse.render).not_to include(:anthropic_version)
    end
  end

  describe 'batches' do # rubocop:disable RSpec/MultipleMemoizedHelpers
    let(:provider) { RubyLLM::Providers::Bedrock.new(context.config) }
    let(:protocol) { provider.protocols[:anthropic].new(provider) }
    let(:payload) { { anthropic_version: 'bedrock-2023-05-31', max_tokens: 10, messages: [] } }

    it 'routes Anthropic payloads to InvokeModel jobs' do
      requests = [{ custom_id: '0', model: model_id, payload: payload }]

      expect(provider.send(:batch_protocol_for, requests)).to eq(provider.protocols[:anthropic])
      expect(provider.invoke_model_batch_protocol("arn:aws:bedrock:eu-central-1:123:inference-profile/#{model_id}"))
        .to eq(provider.protocols[:anthropic])
    end

    it 'writes InvokeModel records with the betas the request needs' do
      jsonl = protocol.send(:bedrock_batch_jsonl, [
                              { custom_id: '0', payload: payload.merge(stream: false),
                                headers: { 'anthropic-beta' => 'compact-2026-01-12' } }
                            ])

      expect(JSON.parse(jsonl)).to eq(
        'recordId' => '0',
        'modelInput' => { 'anthropic_version' => 'bedrock-2023-05-31', 'max_tokens' => 10, 'messages' => [],
                          'anthropic_beta' => ['compact-2026-01-12'] }
      )
      expect(protocol.send(:bedrock_invocation_type)).to eq('InvokeModel')
    end

    it 'parses Anthropic message outputs' do
      index, message = protocol.send(:parse_bedrock_record,
                                     { 'recordId' => '3', 'modelOutput' => JSON.parse(reply.to_json) }, model: model_id)

      expect(index).to eq(3)
      expect(message).to have_attributes(content: 'Hi', role: :assistant)
    end
  end
end
