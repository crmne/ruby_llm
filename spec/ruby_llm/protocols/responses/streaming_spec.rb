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

  it 'streams file citations with their source identities' do
    chunk = build_chunk({
                          'type' => 'response.output_text.annotation.added',
                          'annotation' => { 'type' => 'file_citation', 'file_id' => 'file_facts',
                                            'filename' => 'facts.pdf', 'index' => 0 }
                        })

    expect(chunk.citations.first).to have_attributes(source_id: 'file_facts', title: 'facts.pdf', source_index: 0)
  end

  it 'keeps streamed citation positions across output parts without duplicating final annotations' do
    accumulator = RubyLLM::Protocol::StreamAccumulator.new
    annotation = { 'type' => 'container_file_citation', 'container_id' => 'container_1',
                   'file_id' => 'file_report', 'filename' => 'report.txt', 'start_index' => 0, 'end_index' => 4 }
    events = [
      { 'type' => 'response.output_text.delta', 'output_index' => 0, 'content_index' => 0, 'delta' => 'Café. ' },
      { 'type' => 'response.output_text.delta', 'output_index' => 1, 'content_index' => 0, 'delta' => 'Read ' },
      { 'type' => 'response.output_text.delta', 'output_index' => 1, 'content_index' => 1, 'delta' => 'Ruby' },
      { 'type' => 'response.output_text.annotation.added', 'output_index' => 1, 'content_index' => 1,
        'annotation' => annotation },
      { 'type' => 'response.completed', 'response' => { 'status' => 'completed', 'output' => [
        { 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => 'Café. ' }] },
        { 'type' => 'message', 'content' => [
          { 'type' => 'output_text', 'text' => 'Read ' },
          { 'type' => 'output_text', 'text' => 'Ruby', 'annotations' => [annotation] }
        ] }
      ] } }
    ]

    events.each { |event| accumulator.add(build_chunk(event)) }
    citations = accumulator.to_message(nil).citations

    expect(citations.length).to eq(1)
    expect(citations.first).to have_attributes(source_id: 'file_report', start_index: 11, end_index: 15, text: 'Ruby')
  end

  it 'reads citations included only in the completed response' do
    chunk = build_chunk({
                          'type' => 'response.completed', 'response' => { 'status' => 'completed', 'output' => [
                            { 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => 'Ruby',
                                                                   'annotations' => [{ 'type' => 'file_citation',
                                                                                       'file_id' => 'file_facts',
                                                                                       'filename' => 'facts.pdf',
                                                                                       'index' => 0 }] }] }
                          ] }
                        })

    expect(chunk.citations.first).to have_attributes(source_id: 'file_facts', title: 'facts.pdf')
  end

  it 'resets citation positions when the protocol starts another stream' do
    allow(protocol).to receive(:stream_events) do |*, &block|
      block.call({ 'type' => 'response.output_text.delta', 'output_index' => 0, 'delta' => 'Read ' })
      block.call({ 'type' => 'response.output_text.delta', 'output_index' => 1, 'delta' => 'Ruby' })
      block.call({ 'type' => 'response.output_text.annotation.added', 'output_index' => 1,
                   'annotation' => { 'type' => 'url_citation', 'url' => 'https://ruby-lang.org',
                                     'start_index' => 0, 'end_index' => 4 } })
      nil
    end

    2.times do
      response = protocol.send(:stream_response, {}, &:itself)

      expect(response.citations.first).to have_attributes(start_index: 5, end_index: 9, text: 'Ruby')
    end
  end

  it 'streams reasoning summary deltas as thinking' do
    chunk = build_chunk({ 'type' => 'response.reasoning_summary_text.delta', 'delta' => 'hmm' })

    expect(chunk.thinking.text).to eq('hmm')
  end

  it 'separates reasoning summary parts' do
    accumulator = RubyLLM::Protocol::StreamAccumulator.new
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
    accumulator = RubyLLM::Protocol::StreamAccumulator.new

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
    expect(chunk.finish_reason).to eq(:stop)
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

    expect(chunk.finish_reason).to eq(:stop)
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

    expect(chunk.finish_reason).to eq(:max_tokens)
  end
end
