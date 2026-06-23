# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Responses::Chat do
  let(:protocol) { RubyLLM::Protocols::Responses.allocate }
  let(:model) { instance_double(RubyLLM::Model::Info, id: 'gpt-5-nano') }

  def render_payload(messages, tools: {}, schema: nil, thinking: nil, stream: false)
    protocol.send(:render_payload, messages, tools:, temperature: nil, model:, stream:, schema:, thinking:,
                                             tool_prefs: nil)
  end

  describe '#render_payload' do
    it 'runs stateless and replays encrypted reasoning' do
      payload = render_payload([RubyLLM::Message.new(role: :user, content: 'hi')])

      expect(payload[:store]).to be(false)
      expect(payload[:include]).to eq(['reasoning.encrypted_content'])
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

    it 'uses flat function definitions' do
      tool = instance_double(RubyLLM::Tool, name: 'weather', description: 'Looks up weather',
                                            params_schema: { 'type' => 'object' }, provider_params: {})

      payload = render_payload([RubyLLM::Message.new(role: :user, content: 'hi')], tools: { weather: tool })

      expect(payload[:tools]).to eq([{
                                      type: 'function',
                                      name: 'weather',
                                      description: 'Looks up weather',
                                      parameters: { 'type' => 'object' }
                                    }])
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
      expect(message.model_id).to eq('gpt-5-nano')
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

      expect(message.input_tokens).to eq(6)
      expect(message.output_tokens).to eq(7)
      expect(message.cached_tokens).to eq(4)
      expect(message.thinking_tokens).to eq(3)
    end

    it 'does not synthesize finish_reason for completed function calls' do
      response = response_with([
                                 { 'type' => 'function_call', 'call_id' => 'call_1', 'name' => 'weather',
                                   'arguments' => '{}' }
                               ])

      message = protocol.send(:parse_completion_response, response)

      expect(message.finish_reason).to be_nil
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

      expect(message.finish_reason).to eq('max_output_tokens')
    end
  end
end
