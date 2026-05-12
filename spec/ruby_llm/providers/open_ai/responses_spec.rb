# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Responses do
  let(:config) do
    RubyLLM::Configuration.new.tap do |config|
      config.openai_api_key = 'test'
      config.max_retries = 0
    end
  end

  let(:provider) { RubyLLM::Providers::OpenAI.new(config) }
  let(:model) { instance_double(RubyLLM::Model::Info, id: 'gpt-5.5') }
  let(:messages) { [RubyLLM::Message.new(role: :user, content: 'Hello')] }
  let(:tools) { {} }

  def complete_with_capture(provider, messages, options)
    captured = {}
    tools = options.fetch(:tools)
    model = options.fetch(:model)
    params = options.fetch(:params, {})
    thinking = options[:thinking]

    allow(provider).to receive(:sync_response) do |_connection, payload, _headers|
      captured[:url] = provider.completion_url
      captured[:payload] = payload
      RubyLLM::Message.new(role: :assistant, content: 'ok')
    end

    provider.complete(
      messages,
      tools: tools,
      temperature: nil,
      model: model,
      params: params,
      thinking: thinking,
      tool_prefs: {}
    )

    captured
  end

  describe 'OpenAI protocol routing' do
    it 'uses Chat Completions by default in auto mode' do
      captured = complete_with_capture(provider, messages, tools: tools, model: model)

      expect(captured[:url]).to eq('chat/completions')
      expect(captured[:payload]).to include(:messages)
      expect(captured[:payload]).not_to include(:input)
    end

    it 'uses Responses when forced per request and removes the routing param' do
      captured = complete_with_capture(
        provider,
        messages,
        tools: tools,
        model: model,
        params: { openai_api_mode: :responses }
      )

      expect(captured[:url]).to eq('responses')
      expect(captured[:payload]).to include(input: [{ type: 'message', role: 'user', content: 'Hello' }])
      expect(captured[:payload]).to include(store: false)
      expect(captured[:payload]).not_to include(:openai_api_mode)
    end

    it 'uses Chat Completions when forced per request' do
      config.openai_api_mode = :responses

      captured = complete_with_capture(
        provider,
        messages,
        tools: tools,
        model: model,
        params: { openai_api_mode: :chat_completions }
      )

      expect(captured[:url]).to eq('chat/completions')
    end

    it 'uses Responses for deep research models' do
      deep_research_model = instance_double(RubyLLM::Model::Info, id: 'o4-mini-deep-research')

      captured = complete_with_capture(provider, messages, tools: tools, model: deep_research_model)

      expect(captured[:url]).to eq('responses')
    end

    it 'uses Responses for native Responses tools' do
      captured = complete_with_capture(
        provider,
        messages,
        tools: tools,
        model: model,
        params: { tools: [{ type: 'web_search', search_context_size: 'low' }] }
      )

      expect(captured[:url]).to eq('responses')
      expect(captured[:payload][:tools]).to eq([{ type: 'web_search', search_context_size: 'low' }])
    end

    it 'uses Responses for Responses-only params' do
      captured = complete_with_capture(
        provider,
        messages,
        tools: tools,
        model: model,
        params: { previous_response_id: 'resp_123' }
      )

      expect(captured[:url]).to eq('responses')
      expect(captured[:payload][:previous_response_id]).to eq('resp_123')
    end

    it 'uses Responses for GPT-5 tool calls with reasoning enabled' do
      weather_tool = instance_double(
        RubyLLM::Tool,
        name: 'weather',
        description: 'Looks up weather',
        params_schema: nil,
        parameters: {},
        provider_params: {}
      )

      captured = complete_with_capture(
        provider,
        messages,
        tools: { weather: weather_tool },
        model: model,
        thinking: RubyLLM::Thinking::Config.new(effort: :low)
      )

      expect(captured[:url]).to eq('responses')
    end

    it 'keeps audio input on Chat Completions in auto mode' do
      audio_message = RubyLLM::Message.new(
        role: :user,
        content: RubyLLM::Content.new('Transcribe this', 'spec/fixtures/ruby.wav')
      )

      captured = complete_with_capture(provider, [audio_message], tools: tools, model: model)

      expect(captured[:url]).to eq('chat/completions')
    end

    it 'rejects forced Responses mode with audio input' do
      audio_message = RubyLLM::Message.new(
        role: :user,
        content: RubyLLM::Content.new('Transcribe this', 'spec/fixtures/ruby.wav')
      )

      expect do
        complete_with_capture(
          provider,
          [audio_message],
          tools: tools,
          model: model,
          params: { openai_api_mode: :responses }
        )
      end.to raise_error(RubyLLM::UnsupportedAttachmentError, /does not support audio/)
    end

    it 'keeps OpenAI-compatible providers on their existing Chat Completions path' do
      openrouter_config = RubyLLM::Configuration.new.tap do |config|
        config.openrouter_api_key = 'test'
        config.openai_api_mode = :responses
        config.max_retries = 0
      end
      openrouter = RubyLLM::Providers::OpenRouter.new(openrouter_config)
      openrouter_model = instance_double(RubyLLM::Model::Info, id: 'openai/gpt-5.5')

      captured = complete_with_capture(
        openrouter,
        messages,
        tools: tools,
        model: openrouter_model,
        params: {
          openai_api_mode: :responses,
          tools: [{ type: 'web_search', search_context_size: 'low' }]
        }
      )

      expect(captured[:url]).to eq('chat/completions')
      expect(captured[:payload]).to include(:messages)
      expect(captured[:payload]).not_to include(:input)
      expect(captured[:payload]).not_to include(:openai_api_mode)
    end
  end

  describe '#render_response_payload' do
    before do
      stub_const(
        'OpenAIResponsesWeatherTool',
        Class.new(RubyLLM::Tool) do
          description 'Looks up weather'
          param :city, desc: 'City name'

          def execute(city:)
            city
          end
        end
      )
    end

    it 'maps messages, files, schema, reasoning, and native tools to Responses shape' do
      content = RubyLLM::Content.new(
        'Inspect these files',
        ['spec/fixtures/ruby.png', 'spec/fixtures/sample.pdf', 'spec/fixtures/ruby.txt']
      )
      schema = {
        name: 'WeatherAnswer',
        schema: { type: 'object', properties: { answer: { type: 'string' } }, required: ['answer'] },
        strict: true
      }

      payload = provider.send(
        :render_response_payload,
        [RubyLLM::Message.new(role: :user, content: content)],
        tools: { weather: OpenAIResponsesWeatherTool.new },
        native_tools: [{ type: 'web_search', search_context_size: 'low' }],
        temperature: 0.2,
        model: model,
        stream: true,
        schema: schema,
        thinking: RubyLLM::Thinking::Config.new(effort: :low),
        tool_prefs: { choice: :auto, calls: :many }
      )

      expect(payload[:model]).to eq('gpt-5.5')
      expect(payload[:stream]).to be(true)
      expect(payload[:store]).to be(false)
      expect(payload[:temperature]).to eq(0.2)
      expect(payload[:reasoning]).to eq(effort: 'low')
      expect(payload[:text][:format]).to include(type: 'json_schema', name: 'WeatherAnswer', strict: true)
      expect(payload[:tool_choice]).to eq(:auto)
      expect(payload[:parallel_tool_calls]).to be(true)
      expect(payload[:tools]).to include(hash_including(type: 'function', name: 'open_ai_responses_weather'))
      expect(payload[:tools]).to include(type: 'web_search', search_context_size: 'low')
      expect(payload[:input].first[:content].map { |part| part[:type] }).to eq(
        %w[input_text input_image input_file input_text]
      )
    end

    it 'maps previous assistant tool calls and tool outputs to Responses items' do
      tool_call = RubyLLM::ToolCall.new(id: 'call_123', name: 'weather', arguments: { 'city' => 'Kyiv' })
      assistant = RubyLLM::Message.new(role: :assistant, content: nil, tool_calls: { 'call_123' => tool_call })
      tool_result = RubyLLM::Message.new(
        role: :tool,
        content: RubyLLM::Content::Raw.new({ forecast: 'sunny' }),
        tool_call_id: 'call_123'
      )

      payload = provider.send(
        :render_response_payload,
        [assistant, tool_result],
        tools: {},
        native_tools: [],
        temperature: nil,
        model: model
      )

      expect(payload[:input]).to eq(
        [
          {
            type: 'function_call',
            call_id: 'call_123',
            name: 'weather',
            arguments: '{"city":"Kyiv"}'
          },
          {
            type: 'function_call_output',
            call_id: 'call_123',
            output: '{"forecast":"sunny"}'
          }
        ]
      )
    end
  end

  describe '#parse_response_response' do
    it 'parses text, reasoning summaries, function calls, and usage' do
      response = instance_double(
        Faraday::Response,
        body: {
          'model' => 'gpt-5.5',
          'output_text' => 'Sunny.',
          'output' => [
            {
              'type' => 'reasoning',
              'summary' => [{ 'type' => 'summary_text', 'text' => 'checked the weather' }]
            },
            {
              'type' => 'web_search_call',
              'id' => 'ws_123'
            },
            {
              'type' => 'function_call',
              'call_id' => 'call_123',
              'name' => 'weather',
              'arguments' => '{"city":"Kyiv"}'
            },
            {
              'type' => 'message',
              'content' => [{ 'type' => 'output_text', 'text' => 'Sunny.' }]
            }
          ],
          'usage' => {
            'input_tokens' => 100,
            'input_tokens_details' => { 'cached_tokens' => 25 },
            'output_tokens' => 12,
            'output_tokens_details' => { 'reasoning_tokens' => 5 }
          }
        }
      )

      message = provider.send(:parse_response_response, response)

      expect(message.content).to eq('Sunny.')
      expect(message.thinking.text).to eq('checked the weather')
      expect(message.tool_calls.values.first).to have_attributes(
        id: 'call_123',
        name: 'weather',
        arguments: { 'city' => 'Kyiv' }
      )
      expect(message.input_tokens).to eq(100)
      expect(message.cached_tokens).to eq(25)
      expect(message.output_tokens).to eq(12)
      expect(message.thinking_tokens).to eq(5)
      expect(message.raw).to eq(response)
    end

    it 'raises provider errors' do
      response = instance_double(Faraday::Response, body: { 'error' => { 'message' => 'bad request' } })

      expect { provider.send(:parse_response_response, response) }.to raise_error(RubyLLM::Error, /bad request/)
    end
  end
end
