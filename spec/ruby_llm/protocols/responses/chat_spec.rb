# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Responses::Chat do
  let(:protocol) { RubyLLM::Protocols::Responses.allocate }
  let(:model) { instance_double(RubyLLM::Model, id: 'gpt-5-nano') }

  def render_payload(messages, tools: {}, stream: false, **options)
    protocol.send(:render_payload, messages, tools:, temperature: nil, model:, stream:, tool_prefs: nil, **options)
  end

  describe '#render_payload' do
    it 'runs stateless and replays encrypted reasoning' do
      payload = render_payload([RubyLLM::Message.new(role: :user, content: 'hi')])

      expect(payload[:store]).to be(false)
      expect(payload[:include]).to eq(['reasoning.encrypted_content'])
    end

    it 'asks for encrypted reasoning whatever the model is named' do
      %w[gpt-4.1-mini grok-4-fast-reasoning deepseek-reasoner prod-reasoner].each do |id|
        payload = protocol.send(
          :render_payload, [RubyLLM::Message.new(role: :user, content: 'hi')],
          tools: {}, temperature: nil, model: instance_double(RubyLLM::Model, id:), tool_prefs: nil
        )

        expect(payload[:include]).to eq(['reasoning.encrypted_content'])
      end
    end

    it 'turns system messages into instructions' do
      messages = [
        RubyLLM::Message.new(role: :system, content: 'Be brief.'),
        RubyLLM::Message.new(role: :user, content: 'hi')
      ]

      payload = render_payload(messages)

      expect(payload[:instructions]).to eq('Be brief.')
      expect(payload[:input]).to eq([{ role: 'user', content: 'hi' }])
    end

    it 'replays reasoning, tool calls, and tool outputs as items' do
      messages = [
        RubyLLM::Message.new(role: :user, content: 'weather?'),
        RubyLLM::Message.new(
          role: :assistant,
          content: '',
          thinking: RubyLLM::Thinking.new(signature: 'ENCRYPTED'),
          tool_calls: { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: {}) }
        ),
        RubyLLM::Message.new(role: :tool, content: 'Sunny', tool_call_id: 'call_1')
      ]

      payload = render_payload(messages)

      expect(payload[:input][1]).to eq({ type: 'reasoning', summary: [], encrypted_content: 'ENCRYPTED' })
      expect(payload[:input][2]).to eq({ type: 'function_call', call_id: 'call_1', name: 'weather',
                                         arguments: '{}' })
      expect(payload[:input][3]).to eq({ type: 'function_call_output', call_id: 'call_1', output: 'Sunny' })
    end

    it 'replays assistant text as output_text content' do
      messages = [
        RubyLLM::Message.new(role: :user, content: 'hi'),
        RubyLLM::Message.new(role: :assistant, content: 'Hello!', finish_reason: 'MAX_TOKENS')
      ]

      payload = render_payload(messages)

      expect(payload[:input][1]).to eq({ role: 'assistant', content: [{ type: 'output_text', text: 'Hello!' }] })
    end

    it 'uses flat non-strict function definitions' do
      tool = instance_double(RubyLLM::Tool, name: 'weather', description: 'Looks up weather',
                                            parameters_schema: { 'type' => 'object' }, provider_options: {})

      payload = render_payload([RubyLLM::Message.new(role: :user, content: 'hi')], tools: { weather: tool })

      expect(payload[:tools]).to eq([{
                                      type: 'function',
                                      name: 'weather',
                                      description: 'Looks up weather',
                                      parameters: { 'type' => 'object' },
                                      strict: false
                                    }])
    end

    it 'lets tools opt into strict mode via provider_options' do
      tool = instance_double(RubyLLM::Tool, name: 'weather', description: 'Looks up weather',
                                            parameters_schema: { 'type' => 'object' },
                                            provider_options: { strict: true })

      payload = render_payload([RubyLLM::Message.new(role: :user, content: 'hi')], tools: { weather: tool })

      expect(payload[:tools].first[:strict]).to be(true)
    end

    it 'renders structured output as a text format' do
      schema = { name: 'response', schema: { type: 'object' }, strict: true }

      payload = render_payload([RubyLLM::Message.new(role: :user, content: 'hi')], schema: schema)

      expect(payload[:text]).to eq({
                                     format: {
                                       type: 'json_schema',
                                       name: 'response',
                                       schema: { type: 'object' },
                                       strict: true
                                     }
                                   })
    end

    it 'maps thinking effort to reasoning' do
      thinking = RubyLLM::Thinking::Config.new(effort: 'low')

      payload = render_payload([RubyLLM::Message.new(role: :user, content: 'hi')], thinking: thinking)

      expect(payload[:reasoning]).to eq({ effort: 'low' })
    end

    it 'asks for a reasoning summary when display is summarized' do
      thinking = RubyLLM::Thinking::Config.new(effort: 'low', display: :summarized)

      payload = render_payload([RubyLLM::Message.new(role: :user, content: 'hi')], thinking: thinking)

      expect(payload[:reasoning]).to eq({ effort: 'low', summary: 'auto' })
    end

    it 'renders prompt cache params for any Responses-compatible provider' do
      payload = render_payload(
        [RubyLLM::Message.new(role: :user, content: 'hi')],
        caching: { key: 'repo:ruby_llm', ttl: '30m' }
      )

      expect(payload[:prompt_cache_key]).to eq('repo:ruby_llm')
      expect(payload[:prompt_cache_options]).to eq(ttl: '30m')
    end

    it 'translates deprecated retention into a prompt cache ttl' do
      allow(RubyLLM.logger).to receive(:warn)

      payload = render_payload(
        [RubyLLM::Message.new(role: :user, content: 'hi')],
        caching: { retention: '24h' }
      )

      expect(payload[:prompt_cache_options]).to eq(ttl: '24h')
      expect(RubyLLM.logger).to have_received(:warn).with(/retention: is deprecated/)
    end

    it 'marks cache boundaries with explicit breakpoint parts' do
      messages = [
        RubyLLM::Message.new(role: :user, content: 'Long context').cache_until_here,
        RubyLLM::Message.new(role: :user, content: 'hi')
      ]

      payload = render_payload(messages)

      expect(payload[:input].first[:content]).to eq(
        [{ type: 'input_text', text: 'Long context', prompt_cache_breakpoint: { mode: 'explicit' } }]
      )
      expect(payload[:input].last).to eq(role: 'user', content: 'hi')
      expect(payload[:prompt_cache_options]).to eq(mode: 'explicit')
    end

    it 'sends cache-bounded system messages as input items' do
      messages = [
        RubyLLM::Message.new(role: :system, content: 'Stable instructions').cache_until_here,
        RubyLLM::Message.new(role: :user, content: 'hi')
      ]

      payload = render_payload(messages)

      expect(payload[:instructions]).to be_nil
      expect(payload[:input].first).to eq(
        role: 'system',
        content: [{ type: 'input_text', text: 'Stable instructions', prompt_cache_breakpoint: { mode: 'explicit' } }]
      )
    end
  end

  describe '#parse_completion_response' do
    def response_with(output, usage: {})
      instance_double(
        Faraday::Response,
        body: { 'model' => 'gpt-5-nano', 'output' => output, 'usage' => usage, 'status' => 'completed' }
      )
    end

    it 'joins output_text parts into content' do
      response = response_with([
                                 { 'type' => 'message',
                                   'content' => [{ 'type' => 'output_text', 'text' => 'Hello' },
                                                 { 'type' => 'output_text', 'text' => ' world' }] }
                               ])

      message = protocol.send(:parse_completion_response, response)

      expect(message.content).to eq('Hello world')
      expect(message.model).to eq('gpt-5-nano')
    end

    it 'surfaces refusal parts as content' do
      response = response_with([
                                 { 'type' => 'message',
                                   'content' => [{ 'type' => 'refusal', 'refusal' => 'I cannot help with that.' }] }
                               ])

      message = protocol.send(:parse_completion_response, response)

      expect(message.content).to eq('I cannot help with that.')
    end

    it 'parses function calls keyed by call_id' do
      response = response_with([
                                 { 'type' => 'function_call', 'call_id' => 'call_1', 'name' => 'weather',
                                   'arguments' => '{"city":"Berlin"}' }
                               ])

      message = protocol.send(:parse_completion_response, response)

      expect(message.tool_calls.keys).to eq(['call_1'])
      expect(message.tool_calls['call_1'].name).to eq('weather')
      expect(message.tool_calls['call_1'].arguments).to eq({ 'city' => 'Berlin' })
    end

    it 'wraps malformed function-call arguments in a RubyLLM error' do
      response = instance_double(
        Faraday::Response,
        body: {
          'model' => 'gpt-5-nano',
          'output' => [
            { 'type' => 'function_call', 'call_id' => 'call_1', 'name' => 'weather',
              'arguments' => '{"city":"Berlin"' }
          ],
          'status' => 'incomplete',
          'incomplete_details' => { 'reason' => 'max_output_tokens' }
        }
      )

      error = nil

      expect do
        protocol.send(:parse_completion_response, response)
      rescue RubyLLM::ToolCallParseError => e
        error = e
        raise
      end.to raise_error(RubyLLM::ToolCallParseError)

      expect(error).to be_a(RubyLLM::Error)
      expect(error.response).to eq(response)
      expect(error.finish_reason).to eq(:max_tokens)
      expect(error.cause).to be_a(JSON::ParserError)
    end

    it 'parses reasoning summaries and encrypted content into thinking' do
      response = response_with([
                                 { 'type' => 'reasoning',
                                   'summary' => [{ 'type' => 'summary_text', 'text' => 'Thinking...' }],
                                   'encrypted_content' => 'ENCRYPTED' }
                               ])

      message = protocol.send(:parse_completion_response, response)

      expect(message.thinking.text).to eq('Thinking...')
      expect(message.thinking.signature).to eq('ENCRYPTED')
    end

    it 'maps usage with cached and reasoning tokens' do
      response = response_with([], usage: {
                                 'input_tokens' => 10,
                                 'output_tokens' => 7,
                                 'input_tokens_details' => { 'cached_tokens' => 4 },
                                 'output_tokens_details' => { 'reasoning_tokens' => 3 }
                               })

      message = protocol.send(:parse_completion_response, response)

      expect(message.tokens.input).to eq(6)
      expect(message.tokens.output).to eq(7)
      expect(message.tokens.cache_read).to eq(4)
      expect(message.tokens.thinking).to eq(3)
    end

    it 'maps cache write tokens for models that bill cache writes' do
      response = response_with([], usage: {
                                 'input_tokens' => 2048,
                                 'output_tokens' => 7,
                                 'input_tokens_details' => { 'cached_tokens' => 1920, 'cache_write_tokens' => 100 }
                               })

      message = protocol.send(:parse_completion_response, response)

      expect(message.tokens.input).to eq(28)
      expect(message.tokens.cache_read).to eq(1920)
      expect(message.tokens.cache_write).to eq(100)
    end

    it 'reports the completed status as finish_reason for function calls' do
      response = response_with([
                                 { 'type' => 'function_call', 'call_id' => 'call_1', 'name' => 'weather',
                                   'arguments' => '{}' }
                               ])

      message = protocol.send(:parse_completion_response, response)

      expect(message.finish_reason).to eq(:stop)
      expect(message).to be_tool_call_stop
      expect(message).not_to be_stopped
    end

    it 'preserves incomplete_details reason as finish_reason when present' do
      response = instance_double(
        Faraday::Response,
        body: {
          'model' => 'gpt-5-nano',
          'output' => [],
          'status' => 'incomplete',
          'incomplete_details' => { 'reason' => 'max_output_tokens' }
        }
      )

      message = protocol.send(:parse_completion_response, response)

      expect(message.finish_reason).to eq(:max_tokens)
    end
  end
end
