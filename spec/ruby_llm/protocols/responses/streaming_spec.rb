# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Responses::Streaming do
  let(:protocol) { RubyLLM::Protocols::Responses.allocate }

  def build_chunk(data)
    protocol.send(:build_chunk, data)
  end

  it 'streams output text deltas as content' do
    chunk = build_chunk({ 'type' => 'response.output_text.delta', 'delta' => 'Hel' })

    expect(chunk.content).to eq('Hel')
  end

  it 'streams refusal deltas as content' do
    chunk = build_chunk({ 'type' => 'response.refusal.delta', 'delta' => 'I cannot help' })

    expect(chunk.content).to eq('I cannot help')
  end

  it 'streams reasoning summary deltas as thinking' do
    chunk = build_chunk({ 'type' => 'response.reasoning_summary_text.delta', 'delta' => 'hmm' })

    expect(chunk.thinking.text).to eq('hmm')
  end

  it 'separates reasoning summary parts' do
    accumulator = RubyLLM::StreamAccumulator.new
    events = [
      { 'type' => 'response.reasoning_summary_part.added', 'summary_index' => 0 },
      { 'type' => 'response.reasoning_summary_text.delta', 'delta' => '**First summary**' },
      { 'type' => 'response.reasoning_summary_part.added', 'summary_index' => 1 },
      { 'type' => 'response.reasoning_summary_text.delta', 'delta' => '**Second summary**' }
    ]

    events.each { |event| accumulator.add(build_chunk(event)) }

    expect(accumulator.to_message(nil).thinking.text).to eq("**First summary**\n\n**Second summary**")
  end

  it 'accumulates a function call across item and argument events' do
    accumulator = RubyLLM::StreamAccumulator.new

    accumulator.add build_chunk({
                                  'type' => 'response.output_item.added',
                                  'output_index' => 1,
                                  'item' => { 'type' => 'function_call', 'call_id' => 'call_1', 'name' => 'weather' }
                                })
    accumulator.add build_chunk({
                                  'type' => 'response.function_call_arguments.delta',
                                  'output_index' => 1,
                                  'delta' => '{"city":'
                                })
    accumulator.add build_chunk({
                                  'type' => 'response.function_call_arguments.delta',
                                  'output_index' => 1,
                                  'delta' => '"Berlin"}'
                                })

    message = accumulator.to_message(instance_double(Faraday::Response, body: {}))

    expect(message.tool_calls.keys).to eq(['call_1'])
    expect(message.tool_calls['call_1'].name).to eq('weather')
    expect(message.tool_calls['call_1'].arguments).to eq({ 'city' => 'Berlin' })
  end

  it 'captures encrypted reasoning from completed items' do
    chunk = build_chunk({
                          'type' => 'response.output_item.done',
                          'item' => { 'type' => 'reasoning', 'encrypted_content' => 'ENCRYPTED' }
                        })

    expect(chunk.thinking.signature).to eq('ENCRYPTED')
  end

  it 'reads usage and model from the completed event' do
    chunk = build_chunk({
                          'type' => 'response.completed',
                          'response' => {
                            'model' => 'gpt-5-nano',
                            'status' => 'completed',
                            'usage' => {
                              'input_tokens' => 10,
                              'output_tokens' => 7,
                              'input_tokens_details' => { 'cached_tokens' => 4 },
                              'output_tokens_details' => { 'reasoning_tokens' => 3 }
                            }
                          }
                        })

    expect(chunk.model).to eq('gpt-5-nano')
    expect(chunk.tokens.input).to eq(6)
    expect(chunk.tokens.output).to eq(7)
    expect(chunk.tokens.cache_read).to eq(4)
    expect(chunk.tokens.thinking).to eq(3)
    expect(chunk.finish_reason).to eq('stop')
  end

  it 'reports the completed status as finish_reason for function-call responses' do
    chunk = build_chunk({
                          'type' => 'response.completed',
                          'response' => {
                            'model' => 'gpt-5-nano',
                            'status' => 'completed',
                            'output' => [
                              { 'type' => 'function_call', 'call_id' => 'call_1', 'name' => 'weather',
                                'arguments' => '{}' }
                            ]
                          }
                        })

    expect(chunk.finish_reason).to eq('stop')
  end

  describe '#parse_streaming_error' do
    def parse_streaming_error(payload)
      protocol.send(:parse_streaming_error, payload.to_json)
    end

    it 'classifies a rate limit reported by a flat error event' do
      status, message = parse_streaming_error(
        { type: 'error', code: 'rate_limit_exceeded', message: 'Slow down', param: nil, sequence_number: 3 }
      )

      expect(status).to eq(429)
      expect(message).to eq('Slow down')
    end

    it 'classifies a server error reported by a flat error event' do
      status, = parse_streaming_error({ type: 'error', code: 'server_error', message: 'Internal error' })

      expect(status).to eq(500)
    end

    it 'falls back to a 400 for other flat error codes' do
      status, message = parse_streaming_error({ type: 'error', code: 'invalid_prompt', message: 'Bad prompt' })

      expect(status).to eq(400)
      expect(message).to eq('Bad prompt')
    end

    it 'still classifies nested error objects' do
      status, message = parse_streaming_error({ error: { type: 'rate_limit_exceeded', message: 'Slow down' } })

      expect(status).to eq(429)
      expect(message).to eq('Slow down')
    end
  end

  it 'preserves incomplete_details reason on completed events' do
    chunk = build_chunk({
                          'type' => 'response.completed',
                          'response' => {
                            'model' => 'gpt-5-nano',
                            'status' => 'incomplete',
                            'incomplete_details' => { 'reason' => 'max_output_tokens' }
                          }
                        })

    expect(chunk.finish_reason).to eq('max_tokens')
  end
end
