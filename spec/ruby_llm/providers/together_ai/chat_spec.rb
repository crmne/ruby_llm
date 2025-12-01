# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::TogetherAI::Chat do
  describe '.render_payload' do
    let(:messages) { [instance_double(RubyLLM::Message, role: :user, content: 'Hello')] }
    let(:model) { instance_double(RubyLLM::Model::Info, id: 'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo') }

    before do
      allow(described_class).to receive(:format_messages).and_return([{ role: 'user', content: 'Hello' }])
    end

    it 'creates a basic payload' do
      payload = described_class.render_payload(
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false
      )

      expect(payload).to include(
        model: 'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo',
        messages: [{ role: 'user', content: 'Hello' }],
        stream: false
      )
    end

    it 'includes temperature when provided' do
      payload = described_class.render_payload(
        messages,
        tools: {},
        temperature: 0.7,
        model: model,
        stream: false
      )

      expect(payload[:temperature]).to eq(0.7)
    end

    it 'includes tools when provided' do
      tool = instance_double(RubyLLM::Tool, name: 'test_function', description: 'Test', parameters: {})
      tools = { 'test_function' => tool }

      allow(described_class).to receive(:tool_for).with(tool).and_return({
                                                                           type: 'function',
                                                                           function: { name: 'test_function',
                                                                                       description: 'Test',
                                                                                       parameters: {} }
                                                                         })

      payload = described_class.render_payload(
        messages,
        tools: tools,
        temperature: nil,
        model: model,
        stream: false
      )

      expect(payload[:tools]).to eq([{
                                      type: 'function',
                                      function: { name: 'test_function', description: 'Test', parameters: {} }
                                    }])
    end

    it 'includes JSON schema for structured output' do
      schema = { type: 'object', properties: { answer: { type: 'string' } } }

      payload = described_class.render_payload(
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: schema
      )

      expect(payload[:response_format]).to eq({
                                                type: 'json_schema',
                                                json_schema: {
                                                  name: 'response',
                                                  schema: schema
                                                }
                                              })
    end

    it 'includes stream options for streaming' do
      payload = described_class.render_payload(
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: true
      )

      expect(payload[:stream_options]).to eq({ include_usage: true })
    end
  end

  describe '.parse_completion_response' do
    it 'parses a successful response' do
      response_body = {
        'model' => 'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => 'Hello! How can I help you today?'
            }
          }
        ],
        'usage' => {
          'prompt_tokens' => 10,
          'completion_tokens' => 8
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      allow(described_class).to receive(:parse_tool_calls).and_return([])

      message = described_class.parse_completion_response(response)

      expect(message.role).to eq(:assistant)
      expect(message.content).to eq('Hello! How can I help you today?')
      expect(message.input_tokens).to eq(10)
      expect(message.output_tokens).to eq(8)
      expect(message.model_id).to eq('meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo')
    end

    it 'handles empty response body' do
      response = instance_double(Faraday::Response, body: {})

      result = described_class.parse_completion_response(response)

      expect(result).to be_nil
    end

    it 'raises error for API errors' do
      response_body = {
        'error' => {
          'message' => 'Invalid API key'
        }
      }

      response = instance_double(Faraday::Response, body: response_body)

      expect do
        described_class.parse_completion_response(response)
      end.to raise_error(RubyLLM::Error, 'Invalid API key')
    end

    it 'handles tool calls in response' do
      tool_call_data = {
        'id' => 'call_123',
        'function' => {
          'name' => 'get_weather',
          'arguments' => '{"location": "London"}'
        }
      }

      response_body = {
        'model' => 'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => nil,
              'tool_calls' => [tool_call_data]
            }
          }
        ],
        'usage' => {
          'prompt_tokens' => 10,
          'completion_tokens' => 8
        }
      }

      expected_tool_call = instance_double(RubyLLM::ToolCall)
      response = instance_double(Faraday::Response, body: response_body)
      allow(described_class).to receive(:parse_tool_calls).with([tool_call_data]).and_return([expected_tool_call])

      message = described_class.parse_completion_response(response)

      expect(message.tool_calls).to eq([expected_tool_call])
    end
  end

  describe '.format_content' do
    it 'returns string content as-is' do
      result = described_class.format_content('Hello world')
      expect(result).to eq('Hello world')
    end

    it 'extracts text from multimodal content' do
      content = [
        { 'type' => 'text', 'text' => 'Hello' },
        { 'type' => 'image_url', 'image_url' => { 'url' => 'data:image/jpeg;base64,xyz' } },
        { 'type' => 'text', 'text' => 'world' }
      ]

      result = described_class.format_content(content)
      expect(result).to eq('Hello world')
    end

    it 'converts other content to string' do
      result = described_class.format_content(123)
      expect(result).to eq('123')
    end
  end

  describe '.parse_tool_calls' do
    it 'parses tool calls with valid JSON arguments' do
      tool_calls_data = [
        {
          'id' => 'call_123',
          'function' => {
            'name' => 'get_weather',
            'arguments' => '{"location": "London", "units": "metric"}'
          }
        }
      ]

      result = described_class.parse_tool_calls(tool_calls_data)

      expect(result.length).to eq(1)
      expect(result[0].id).to eq('call_123')
      expect(result[0].name).to eq('get_weather')
      expect(result[0].arguments).to eq({ 'location' => 'London', 'units' => 'metric' })
    end

    it 'handles invalid JSON arguments gracefully' do
      tool_calls_data = [
        {
          'id' => 'call_123',
          'function' => {
            'name' => 'get_weather',
            'arguments' => 'invalid json'
          }
        }
      ]

      result = described_class.parse_tool_calls(tool_calls_data)

      expect(result.length).to eq(1)
      expect(result[0].id).to eq('call_123')
      expect(result[0].name).to eq('get_weather')
      expect(result[0].arguments).to eq({})
    end

    it 'returns empty array for nil input' do
      result = described_class.parse_tool_calls(nil)
      expect(result).to eq([])
    end
  end
end
