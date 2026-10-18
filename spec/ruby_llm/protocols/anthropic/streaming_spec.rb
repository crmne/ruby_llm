# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::Streaming do
  include_context 'with configured RubyLLM'

  let(:protocol) do
    RubyLLM::Protocols::Anthropic.allocate.tap do |object|
      object.instance_variable_set(:@model, instance_double(RubyLLM::Model, id: 'claude-sonnet-4-5'))
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

    expect(chunk.finish_reason).to eq(:stop)
  end

  it 'reads thinking token counts from message_delta usage' do
    chunk = protocol.send(
      :build_chunk,
      {
        'type' => 'message_delta',
        'delta' => { 'stop_reason' => 'end_turn' },
        'usage' => { 'output_tokens' => 10, 'output_tokens_details' => { 'thinking_tokens' => 7 } }
      }
    )

    expect(chunk.tokens.thinking).to eq(7)
  end

  it 'reports the cumulative input tokens from message_delta usage' do
    accumulator = RubyLLM::Protocol::StreamAccumulator.new
    [
      { 'type' => 'message_start',
        'message' => { 'model' => 'claude-haiku-4-5', 'usage' => { 'input_tokens' => 2225, 'output_tokens' => 1 } } },
      { 'type' => 'message_delta', 'delta' => { 'stop_reason' => 'end_turn' },
        'usage' => { 'input_tokens' => 11_715, 'output_tokens' => 310 } }
    ].each { |event| accumulator.add(protocol.send(:build_chunk, event)) }

    expect(accumulator.to_message(nil).tokens).to have_attributes(input: 11_715, output: 310)
  end

  it 'keeps the message_start input tokens when message_delta omits them' do
    accumulator = RubyLLM::Protocol::StreamAccumulator.new
    [
      { 'type' => 'message_start',
        'message' => { 'model' => 'claude-haiku-4-5', 'usage' => { 'input_tokens' => 25, 'output_tokens' => 1 } } },
      { 'type' => 'message_delta', 'delta' => { 'stop_reason' => 'end_turn' }, 'usage' => { 'output_tokens' => 12 } }
    ].each { |event| accumulator.add(protocol.send(:build_chunk, event)) }

    expect(accumulator.to_message(nil).tokens).to have_attributes(input: 25, output: 12)
  end

  it 'reads the cache write lifetimes from message_start usage' do
    chunk = protocol.send(
      :build_chunk,
      {
        'type' => 'message_start',
        'message' => {
          'model' => 'claude-sonnet-4-5',
          'usage' => {
            'input_tokens' => 3,
            'cache_creation_input_tokens' => 300,
            'cache_creation' => { 'ephemeral_5m_input_tokens' => 100, 'ephemeral_1h_input_tokens' => 200 }
          }
        }
      }
    )

    expect(chunk.tokens.cache_write_by_ttl).to eq('5m' => 100, '1h' => 200)
  end

  it 'appends streamed text to its content block in place' do
    delta = lambda do |text|
      { 'type' => 'content_block_delta', 'index' => 0, 'delta' => { 'type' => 'text_delta', 'text' => text } }
    end
    protocol.send(:build_chunk, { 'type' => 'content_block_start', 'index' => 0,
                                  'content_block' => { 'type' => 'text', 'text' => '' } })
    protocol.send(:build_chunk, delta.call('Hello'))
    text = protocol.instance_variable_get(:@stream_blocks)[0]['text']
    protocol.send(:build_chunk, delta.call(', world'))

    expect(protocol.instance_variable_get(:@stream_blocks)[0]['text']).to be(text).and eq('Hello, world')
  end

  it 'streams thinking text and its signature as thinking, not content' do
    thinking = protocol.send(:build_chunk, { 'type' => 'content_block_delta', 'index' => 0,
                                             'delta' => { 'type' => 'thinking_delta', 'thinking' => 'Hmm' } })
    signature = protocol.send(:build_chunk, { 'type' => 'content_block_delta', 'index' => 0,
                                              'delta' => { 'type' => 'signature_delta', 'signature' => 'sig' } })
    text = protocol.send(:build_chunk, { 'type' => 'content_block_delta', 'index' => 0,
                                         'delta' => { 'type' => 'text_delta', 'text' => 'Hi' } })

    expect([thinking.content, thinking.thinking.text, thinking.thinking.signature]).to eq([nil, 'Hmm', nil])
    expect([signature.content, signature.thinking.text, signature.thinking.signature]).to eq([nil, '', 'sig'])
    expect(text.thinking).to be_nil
    expect(text.citations).to be_empty
  end

  def accumulate(events)
    accumulator = RubyLLM::Protocol::StreamAccumulator.new
    events.each { |event| accumulator.add(protocol.send(:build_chunk, event)) }
    accumulator.to_message(nil)
  end

  def block_start(index, block)
    { 'type' => 'content_block_start', 'index' => index, 'content_block' => block }
  end

  def signature_delta(index, signature)
    { 'type' => 'content_block_delta', 'index' => index,
      'delta' => { 'type' => 'signature_delta', 'signature' => signature } }
  end

  it 'keeps redacted thinking distinct from omitted thinking' do
    message = accumulate([{ 'type' => 'message_start' },
                          block_start(0, { 'type' => 'redacted_thinking', 'data' => 'redacted-thinking' }),
                          { 'type' => 'content_block_stop', 'index' => 0 },
                          { 'type' => 'message_stop' }])

    expect(message.thinking.text).to be_nil
    expect(message.thinking.signature).to eq('redacted-thinking')
  end

  it 'preserves omitted thinking through stream accumulation' do
    message = accumulate([{ 'type' => 'message_start' },
                          block_start(0, { 'type' => 'thinking', 'thinking' => '', 'signature' => '' }),
                          signature_delta(0, 'thinking-signature'),
                          { 'type' => 'content_block_stop', 'index' => 0 },
                          { 'type' => 'message_stop' }])

    expect(message.thinking.text).to eq('')
    expect(message.thinking.signature).to eq('thinking-signature')
  end

  it 'prefers a thinking signature over redacted thinking that streamed first' do
    message = accumulate([{ 'type' => 'message_start' },
                          block_start(0, { 'type' => 'redacted_thinking', 'data' => 'redacted-thinking' }),
                          block_start(1, { 'type' => 'thinking', 'thinking' => '', 'signature' => '' }),
                          signature_delta(1, 'thinking-signature'),
                          { 'type' => 'message_stop' }])

    expect(message.thinking.signature).to eq('thinking-signature')
  end

  it 'starts each streamed message of a pause_turn continuation with no blocks' do
    events = lambda do |index, block, partial_json|
      delta = { 'type' => 'input_json_delta', 'partial_json' => partial_json }
      [{ 'type' => 'message_start', 'message' => { 'model' => 'claude-sonnet-4-5', 'usage' => {} } },
       { 'type' => 'content_block_start', 'index' => index, 'content_block' => block },
       { 'type' => 'content_block_delta', 'index' => index, 'delta' => delta },
       { 'type' => 'content_block_stop', 'index' => index },
       { 'type' => 'message_stop' }].map { |event| protocol.send(:build_chunk, event) }.last
    end
    search = { 'type' => 'server_tool_use', 'id' => 'srv_1', 'name' => 'web_search', 'input' => {} }
    tool = { 'type' => 'tool_use', 'id' => 'tool_1', 'name' => 'lookup', 'input' => {} }

    first = events.call(0, search, '{"query":"ruby"}')
    second = events.call(1, tool, '')

    expect(first.raw_content).to eq([search.merge('input' => { 'query' => 'ruby' })])
    expect(second.raw_content).to be_nil
    expect(second.server_tool_calls).to be_empty
    expect(protocol.instance_variable_get(:@stream_block_json).keys).to eq([1])
  end

  describe 'content block reconstruction' do
    def start(index, block)
      protocol.send(:build_chunk, { 'type' => 'content_block_start', 'index' => index, 'content_block' => block })
    end

    def input_json(index, partial_json)
      protocol.send(:build_chunk, { 'type' => 'content_block_delta', 'index' => index,
                                    'delta' => { 'type' => 'input_json_delta', 'partial_json' => partial_json } })
    end

    def stop(index)
      protocol.send(:build_chunk, { 'type' => 'content_block_stop', 'index' => index })
    end

    def block(index) = protocol.instance_variable_get(:@stream_blocks)[index]

    it 'assembles tool input from a stream that sent no message_start' do
      start(0, { 'type' => 'server_tool_use', 'id' => 'srv_1', 'name' => 'web_search' })
      input_json(0, '{"query":')
      input_json(0, '"ruby"}')
      stop(0)

      expect(block(0)['input']).to eq('query' => 'ruby')
    end

    it 'keeps an empty input object for a tool that streamed no input' do
      start(0, { 'type' => 'server_tool_use', 'id' => 'srv_1', 'name' => 'web_search' })
      stop(0)

      expect(block(0)['input']).to eq({})
    end

    it 'falls back to the starting input when the streamed input is not JSON' do
      start(0, { 'type' => 'server_tool_use', 'id' => 'srv_1', 'name' => 'web_search', 'input' => { 'q' => 1 } })
      start(1, { 'type' => 'server_tool_use', 'id' => 'srv_2', 'name' => 'web_search' })
      input_json(0, '{"query":')
      input_json(1, '{"query":')
      stop(0)
      stop(1)

      expect([block(0)['input'], block(1)['input']]).to eq([{ 'q' => 1 }, {}])
    end

    it 'ignores a delta for a block that never started' do
      expect { input_json(3, '{}') }.not_to raise_error
      expect(protocol.send(:build_chunk, { 'type' => 'content_block_delta', 'index' => 3,
                                           'delta' => { 'type' => 'text_delta', 'text' => 'Hi' } }).content).to eq('Hi')
    end

    it 'reports the reconstructed blocks only when the message stops' do
      start(0, { 'type' => 'server_tool_use', 'id' => 'srv_1', 'name' => 'web_search', 'input' => {} })

      delta = stop(0)

      expect(delta.raw_content).to be_nil
      expect(delta.server_tool_calls).to be_empty
      expect(protocol.send(:build_chunk, { 'type' => 'message_stop' }).server_tool_calls.map(&:id)).to eq(['srv_1'])
    end
  end

  describe 'citations' do
    let(:citation) do
      { 'type' => 'char_location', 'cited_text' => 'Matz created Ruby in 1995', 'document_index' => 0,
        'document_title' => 'facts.txt', 'start_char_index' => 0, 'end_char_index' => 25 }
    end
    let(:blocks) do
      [{ 'type' => 'text', 'text' => 'Matz made Ruby.', 'citations' => [citation] },
       { 'type' => 'text', 'text' => ' ' },
       { 'type' => 'text', 'text' => 'It dates from 1995.', 'citations' => [citation] }]
    end
    let(:events) do
      blocks.each_with_index.flat_map do |block, index|
        [{ 'type' => 'content_block_start', 'index' => index, 'content_block' => { 'type' => 'text', 'text' => '' } },
         *Array(block['citations']).map do |cited|
           { 'type' => 'content_block_delta', 'index' => index,
             'delta' => { 'type' => 'citations_delta', 'citation' => cited } }
         end,
         { 'type' => 'content_block_delta', 'index' => index,
           'delta' => { 'type' => 'text_delta', 'text' => block['text'] } },
         { 'type' => 'content_block_stop', 'index' => index }]
      end
    end

    it 'streams a citation once the text it supports is complete' do
      chunks = events.first(4).map { |event| protocol.send(:build_chunk, event) }

      expect(chunks.first(3).flat_map(&:citations)).to be_empty
      expect(chunks.last.citations.map(&:to_h)).to eq(
        [{ title: 'facts.txt', text: 'Matz made Ruby.', cited_text: 'Matz created Ruby in 1995',
           start_index: 0, end_index: 15, source_index: 0 }]
      )
    end

    it 'gives streamed citations the spans of the complete response' do
      complete = protocol.send(:parse_completion_body, { 'content' => blocks, 'usage' => {} }, raw: nil)
      accumulator = RubyLLM::Protocol::StreamAccumulator.new
      events.each { |event| accumulator.add(protocol.send(:build_chunk, event)) }
      streamed = accumulator.to_message(nil)

      expect(streamed.citations.map(&:text)).to eq(['Matz made Ruby.', 'It dates from 1995.'])
      expect(streamed.citations.map(&:to_h)).to eq(complete.citations.map(&:to_h))
    end

    it 'ignores a citation delta without a citation' do
      chunks = [
        { 'type' => 'content_block_start', 'index' => 0, 'content_block' => { 'type' => 'text', 'text' => '' } },
        { 'type' => 'content_block_delta', 'index' => 0, 'delta' => { 'type' => 'citations_delta' } },
        { 'type' => 'content_block_stop', 'index' => 0 }
      ].map { |event| protocol.send(:build_chunk, event) }

      expect(chunks.flat_map(&:citations)).to be_empty
    end
  end

  it 'reads no tool call from a text delta' do
    chunk = protocol.send(:build_chunk, { 'type' => 'content_block_delta', 'index' => 0,
                                          'delta' => { 'type' => 'text_delta', 'text' => 'Hi' } })

    expect(chunk.tool_calls).to be_nil
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

    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)
    chat.ask('hi') { |_chunk| nil }

    expect(captured).to eq('identity')
  end

  describe '#parse_streaming_error' do
    it 'parses typed error objects' do
      status, message = protocol.send(
        :parse_streaming_error,
        { type: 'error', error: { type: 'overloaded_error', message: 'Overloaded' } }.to_json
      )

      expect(status).to eq(529)
      expect(message).to eq('Overloaded')
    end

    it 'gives each documented error type its HTTP status' do
      statuses = {
        'invalid_request_error' => 400, 'authentication_error' => 401, 'billing_error' => 402,
        'permission_error' => 403, 'not_found_error' => 404, 'request_too_large' => 413,
        'rate_limit_error' => 429, 'api_error' => 500, 'timeout_error' => 504, 'overloaded_error' => 529
      }

      parsed = statuses.keys.to_h do |type|
        [type, protocol.send(:parse_streaming_error, { type: 'error', error: { type:, message: 'Failed' } }.to_json)]
      end

      expect(parsed).to eq(statuses.transform_values { |status| [status, 'Failed'] })
    end

    it 'ignores an event that is not an error' do
      expect(protocol.send(:parse_streaming_error, { type: 'ping' }.to_json)).to be_nil
    end

    it 'falls back to a 500 for an error type it does not know' do
      status, message = protocol.send(
        :parse_streaming_error,
        { type: 'error', error: { type: 'brand_new_error', message: 'Failed' } }.to_json
      )

      expect(status).to eq(500)
      expect(message).to eq('Failed')
    end

    it 'handles a string error value' do
      status, message = protocol.send(
        :parse_streaming_error,
        { type: 'error', error: 'Overloaded' }.to_json
      )

      expect(status).to eq(500)
      expect(message).to eq('Overloaded')
    end

    it 'ignores a body that parses to a bare JSON string' do
      expect(protocol.send(:parse_streaming_error, '"model unavailable (type: error)"')).to be_nil
    end
  end

  describe 'stream errors' do
    def stream_failing_with(type, message)
      events = <<~SSE
        event: message_start
        data: {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","content":[],"model":"#{model_for(:anthropic)}","usage":{"input_tokens":12,"output_tokens":1}}}

        event: error
        data: {"type":"error","error":{"type":"#{type}","message":"#{message}"}}

      SSE
      stub_request(:post, %r{api\.anthropic\.com/v1/messages})
        .to_return(status: 200, body: events, headers: { 'Content-Type' => 'text/event-stream' })

      RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic).ask('Hello') { |_chunk| nil }
    end

    it 'raises a rate limit reported in an error event' do
      message = 'This request would exceed the rate limit for your organization of 50,000 input tokens per minute.'

      expect { stream_failing_with('rate_limit_error', message) }.to raise_error(RubyLLM::RateLimitError, message)
    end

    it 'raises a refused request reported in an error event as a bad request' do
      expect { stream_failing_with('invalid_request_error', 'messages: at least one message is required') }
        .to raise_error(RubyLLM::BadRequestError, 'messages: at least one message is required')
    end
  end

  it 'raises ToolCallTruncatedError when max_tokens cuts off a tool call' do
    accumulator = RubyLLM::Protocol::StreamAccumulator.new
    [{ 'type' => 'message_start', 'message' => { 'model' => 'claude-sonnet-4-5', 'usage' => {} } },
     { 'type' => 'content_block_start', 'index' => 0,
       'content_block' => { 'type' => 'tool_use', 'id' => 'toolu_1', 'name' => 'move', 'input' => {} } },
     { 'type' => 'content_block_delta', 'index' => 0,
       'delta' => { 'type' => 'input_json_delta', 'partial_json' => '{"from":"a.txt","to' } },
     { 'type' => 'message_delta', 'delta' => { 'stop_reason' => 'max_tokens' }, 'usage' => { 'output_tokens' => 64 } },
     { 'type' => 'message_stop' }].each do |event|
      accumulator.add(protocol.send(:build_chunk, event))
    end

    expect { accumulator.to_message(nil) }.to raise_error(RubyLLM::ToolCallTruncatedError)
  end
end
