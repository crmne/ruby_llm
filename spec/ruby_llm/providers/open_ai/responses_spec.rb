# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI::Responses do
  # reasoning_effort + function tools is rejected on /v1/chat/completions; the
  # OpenAI provider routes that combo to /v1/responses. These keyless unit tests
  # exercise the request/response translation directly on a provider instance
  # (where OpenAI::Chat + OpenAI::Responses + OpenAI::Tools are all mixed in).
  class RespWeatherTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Gets current weather for a city'
    param :city, desc: 'City name'

    def execute(city:)
      { city:, temp_c: 18 }
    end
  end

  # A bare OpenAI subclass that does NOT override render_payload, to prove the
  # instance_of?(OpenAI) guard keeps subclasses on chat/completions.
  class BareOpenAISub < RubyLLM::Providers::OpenAI # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
  end

  class RespParamsTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Tool carrying provider-specific params'
    with_params(metadata: { source: 'test' })
  end

  let(:provider) { RubyLLM::Providers::OpenAI.allocate }
  let(:model) { instance_double(RubyLLM::Model::Info, id: 'gpt-5.5') }
  let(:effort) { RubyLLM::Thinking::Config.new(effort: :high) }
  let(:tools) { { weather: RespWeatherTool.new } }

  describe '#responses_api?' do
    it 'is true with a reasoning effort and tools' do
      expect(provider.send(:responses_api?, tools: tools, thinking: effort)).to be(true)
    end

    it 'is false without thinking' do
      expect(provider.send(:responses_api?, tools: tools, thinking: nil)).to be(false)
    end

    it 'is false without tools' do
      expect(provider.send(:responses_api?, tools: {}, thinking: effort)).to be(false)
    end
  end

  describe '#render_payload routing' do
    let(:messages) { [RubyLLM::Message.new(role: :user, content: 'Weather in Paris?')] }

    it 'routes thinking + tools to the Responses payload and flips completion_url' do
      payload = provider.render_payload(messages, tools: tools, temperature: nil, model: model, thinking: effort)

      expect(payload).to include(:input, :tools, :store)
      expect(payload).not_to have_key(:messages)
      expect(payload[:reasoning]).to eq(effort: 'high')
      expect(provider.completion_url).to eq('responses')
    end

    it 'leaves plain (no-thinking) turns on chat/completions' do
      allow(provider).to receive(:format_messages).and_return([{ role: 'user', content: 'x' }])

      payload = provider.render_payload(messages, tools: tools, temperature: nil, model: model, thinking: nil)

      expect(payload).to have_key(:messages)
      expect(provider.completion_url).to eq('chat/completions')
    end

    it 'does NOT route on OpenAI subclasses (they have no /v1/responses)' do
      sub = BareOpenAISub.allocate
      allow(sub).to receive(:format_messages).and_return([{ role: 'user', content: 'x' }])

      payload = sub.render_payload(messages, tools: tools, temperature: nil, model: model, thinking: effort)

      expect(payload).to have_key(:messages)
      expect(sub.completion_url).to eq('chat/completions')
    end
  end

  describe '#render_responses_payload' do
    subject(:payload) do
      provider.send(
        :render_responses_payload,
        system_and_user, tools: tools, model: model, stream: false, schema: nil, thinking: effort, tool_prefs: {}
      )
    end

    let(:system_and_user) do
      [
        RubyLLM::Message.new(role: :system, content: 'You are helpful.'),
        RubyLLM::Message.new(role: :user, content: 'Weather in Paris?')
      ]
    end

    it 'sets model, store, reasoning and lifts system messages into instructions' do
      expect(payload[:model]).to eq('gpt-5.5')
      expect(payload[:store]).to be(false)
      expect(payload[:reasoning]).to eq(effort: 'high')
      expect(payload[:instructions]).to eq('You are helpful.')
    end

    it 'renders user messages as input_text items (system excluded from input)' do
      roles = payload[:input].filter_map { |item| item[:role] }
      expect(roles).to eq(['user'])
      expect(payload[:input].first[:content]).to eq([{ type: 'input_text', text: 'Weather in Paris?' }])
    end

    it 'renders flat function tools (not nested under :function)' do
      tool = payload[:tools].first
      expect(tool[:type]).to eq('function')
      expect(tool[:name]).to eq(tools[:weather].name)
      expect(tool).to have_key(:parameters)
      expect(tool).not_to have_key(:function)
    end

    it 'maps a structured-output schema to text.format' do
      schema = { name: 'S', schema: { 'type' => 'object' }, strict: true }
      result = provider.send(
        :render_responses_payload,
        system_and_user, tools: {}, model: model, stream: false, schema:, thinking: effort, tool_prefs: {}
      )
      expect(result[:text]).to eq(format: { type: 'json_schema', name: 'S', schema: { 'type' => 'object' },
                                            strict: true })
    end
  end

  describe '#format_responses_input tool round-trip' do
    it 'emits function_call for assistant tool calls and function_call_output for tool results' do
      call = RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: { 'city' => 'Paris' })
      conversation = [
        RubyLLM::Message.new(role: :assistant, content: nil, tool_calls: { 'call_1' => call }),
        RubyLLM::Message.new(role: :tool, content: '{"temp_c":18}', tool_call_id: 'call_1')
      ]

      input = provider.send(:format_responses_input, conversation)

      function_call = input.find { |item| item[:type] == 'function_call' }
      expect(function_call).to include(call_id: 'call_1', name: 'weather')
      expect(JSON.parse(function_call[:arguments])).to eq('city' => 'Paris')

      output = input.find { |item| item[:type] == 'function_call_output' }
      expect(output).to include(call_id: 'call_1', output: '{"temp_c":18}')
    end
  end

  describe '#parse_responses_response' do
    it 'parses message text, function_call, reasoning and usage' do
      body = {
        'model' => 'gpt-5.5',
        'output' => [
          { 'type' => 'reasoning', 'summary' => [{ 'type' => 'summary_text', 'text' => 'thinking...' }],
            'encrypted_content' => 'enc' },
          { 'type' => 'function_call', 'call_id' => 'call_9', 'name' => 'weather', 'arguments' => '{"city":"Paris"}' },
          { 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => 'It is 18C.' }] }
        ],
        'usage' => {
          'input_tokens' => 100, 'output_tokens' => 20,
          'output_tokens_details' => { 'reasoning_tokens' => 12 },
          'input_tokens_details' => { 'cached_tokens' => 30 }
        }
      }
      message = provider.send(:parse_responses_response, instance_double(Faraday::Response, body:))

      expect(message.content).to eq('It is 18C.')
      expect(message.tool_calls['call_9'].name).to eq('weather')
      expect(message.tool_calls['call_9'].arguments).to eq('city' => 'Paris')
      expect(message.thinking.text).to eq('thinking...')
      expect(message.thinking.signature).to eq('enc')
      expect([message.input_tokens, message.output_tokens]).to eq([100, 20])
      expect([message.thinking_tokens, message.cached_tokens]).to eq([12, 30])
    end

    it 'falls back to output_text and nil tool_calls when there is no message item' do
      body = { 'model' => 'gpt-5.5', 'output' => [], 'output_text' => 'hi', 'usage' => {} }
      message = provider.send(:parse_responses_response, instance_double(Faraday::Response, body:))

      expect(message.content).to eq('hi')
      expect(message.tool_calls).to be_nil
    end

    it 'raises on an error body' do
      body = { 'error' => { 'message' => 'boom' } }
      expect do
        provider.send(:parse_responses_response, instance_double(Faraday::Response, body:))
      end.to raise_error(RubyLLM::Error, /boom/)
    end
  end

  describe '#parse_completion_response delegation' do
    it 'routes to the Responses parser when responses mode is active' do
      provider.instance_variable_set(:@openai_responses_mode, true)
      body = {
        'model' => 'gpt-5.5',
        'output' => [{ 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => 'ok' }] }],
        'usage' => {}
      }
      message = provider.send(:parse_completion_response, instance_double(Faraday::Response, body:))
      expect(message.content).to eq('ok')
    end
  end

  describe '#responses_tool_for' do
    it 'deep-merges provider_params into the flat tool definition' do
      definition = provider.send(:responses_tool_for, RespParamsTool.new)

      expect(definition[:type]).to eq('function')
      expect(definition[:metadata]).to eq(source: 'test')
    end
  end

  describe '#responses_text_content' do
    it 'reads .text from Content objects' do
      expect(provider.send(:responses_text_content, RubyLLM::Content.new('hi'))).to eq('hi')
    end

    it 'falls back to to_s for plain values' do
      expect(provider.send(:responses_text_content, 42)).to eq('42')
    end
  end

  describe '#responses_tool_choice' do
    it 'passes auto/required/none through as strings' do
      expect(provider.send(:responses_tool_choice, :required)).to eq('required')
    end

    it 'wraps a named tool choice' do
      expect(provider.send(:responses_tool_choice, 'weather')).to eq(type: 'function', name: 'weather')
    end
  end

  describe '#stream_response guard' do
    it 'raises a clear error in responses mode (streaming not implemented)' do
      provider.instance_variable_set(:@openai_responses_mode, true)
      expect { provider.stream_response(nil, {}) }.to raise_error(RubyLLM::Error, /streaming not implemented/i)
    end
  end
end
