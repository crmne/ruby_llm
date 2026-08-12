# frozen_string_literal: true

require 'spec_helper'

# Event fixtures are the SSE stream published at
# https://docs.cohere.com/reference/chat-stream, copied verbatim.
RSpec.describe RubyLLM::Protocols::Cohere::Streaming do
  include_context 'with configured RubyLLM'

  let(:model) { RubyLLM.models.find('command-a-plus-05-2026') }
  let(:protocol) { RubyLLM::Protocols::Cohere.new(RubyLLM::Providers::Cohere.new(RubyLLM.config), model) }

  def build_chunk(json)
    protocol.send(:build_chunk, JSON.parse(json))
  end

  def sse(*events)
    events.map { |event| "event: #{JSON.parse(event)['type']}\ndata: #{event}\n\n" }.join
  end

  # Drives the protocol rather than Chat, so a streamed tool call is read back
  # instead of being executed and re-requested.
  def stream(body)
    stub_request(:post, 'https://api.cohere.com/v2/chat')
      .to_return(status: 200, body: body, headers: { 'Content-Type' => 'text/event-stream' })

    chunks = []
    messages = [RubyLLM::Message.new(role: :user, content: 'Tell me about LLMs')]
    response = protocol.complete(messages, tools: {}, temperature: nil) { |chunk| chunks << chunk }
    [response, chunks]
  end

  describe '#build_chunk' do
    it 'reads text from content-delta events' do
      chunk = build_chunk('{"delta":{"message":{"content":{"text":"LL"}}},"index":0,"type":"content-delta"}')

      expect(chunk.content).to eq('LL')
      expect(chunk.model).to eq('command-a-plus-05-2026')
    end

    it 'reads reasoning from content-delta events' do
      chunk = build_chunk('{"delta":{"message":{"content":{"thinking":"Let me"}}},"index":0,"type":"content-delta"}')

      expect(chunk.content).to be_nil
      expect(chunk.thinking.text).to eq('Let me')
    end

    it 'reads reasoning from tool-plan-delta events' do
      chunk = build_chunk('{"delta":{"message":{"tool_plan":"I"}},"type":"tool-plan-delta"}')

      expect(chunk.thinking.text).to eq('I')
    end

    it 'opens a tool call on tool-call-start' do
      chunk = build_chunk(
        '{"delta":{"message":{"tool_calls":{"function":{"arguments":"","name":"query_daily_sales_report"},' \
        '"id":"query_daily_sales_report_j3f0adww9pmr","type":"function"}}},"index":0,"type":"tool-call-start"}'
      )

      expect(chunk.tool_calls[0]).to have_attributes(
        id: 'query_daily_sales_report_j3f0adww9pmr',
        name: 'query_daily_sales_report',
        arguments: ''
      )
    end

    it 'appends arguments on tool-call-delta' do
      chunk = build_chunk(
        '{"delta":{"message":{"tool_calls":{"function":{"arguments":"{\\n    \\""}}}},' \
        '"index":0,"type":"tool-call-delta"}'
      )

      expect(chunk.tool_calls[0]).to have_attributes(id: nil, name: nil, arguments: "{\n    \"")
    end

    it 'reads the finish reason and usage from message-end' do
      chunk = build_chunk(
        '{"delta":{"finish_reason":"COMPLETE","usage":{"billed_units":{"input_tokens":5,"output_tokens":26},' \
        '"tokens":{"input_tokens":71,"output_tokens":26}}},"type":"message-end"}'
      )

      expect(chunk.finish_reason).to eq('COMPLETE')
      expect(chunk.tokens.input).to eq(71)
      expect(chunk.tokens.output).to eq(26)
    end

    it 'ignores the bookkeeping events' do
      expect(build_chunk('{"index":0,"type":"content-end"}').content).to be_nil
      expect(build_chunk('{"delta":{"message":{"role":"assistant"}},"id":"29f","type":"message-start"}').content)
        .to be_nil
    end
  end

  describe 'end to end' do
    it 'accumulates a streamed answer' do
      response, chunks = stream(
        sse(
          '{"delta":{"message":{"role":"assistant"}},"id":"29f14a5a","type":"message-start"}',
          '{"delta":{"message":{"content":{"text":"","type":"text"}}},"index":0,"type":"content-start"}',
          '{"delta":{"message":{"content":{"text":"LL"}}},"index":0,"type":"content-delta"}',
          '{"delta":{"message":{"content":{"text":"Ms"}}},"index":0,"type":"content-delta"}',
          '{"delta":{"message":{"content":{"text":" stand"}}},"index":0,"type":"content-delta"}',
          '{"index":0,"type":"content-end"}',
          '{"delta":{"finish_reason":"COMPLETE","usage":{"billed_units":{"input_tokens":5,"output_tokens":26},' \
          '"tokens":{"input_tokens":71,"output_tokens":26}}},"type":"message-end"}'
        )
      )

      expect(response.content).to eq('LLMs stand')
      expect(response.finish_reason).to eq('COMPLETE')
      expect(response.tokens.input).to eq(71)
      expect(chunks.filter_map(&:content).join).to eq('LLMs stand')
    end

    it 'accumulates streamed tool calls' do
      response, = stream(
        sse(
          '{"delta":{"message":{"role":"assistant"}},"id":"2edfdf70","type":"message-start"}',
          '{"delta":{"message":{"tool_plan":"I will"}},"type":"tool-plan-delta"}',
          '{"delta":{"message":{"tool_calls":{"function":{"arguments":"","name":"query_daily_sales_report"},' \
          '"id":"query_daily_sales_report_j3f0adww9pmr","type":"function"}}},"index":0,"type":"tool-call-start"}',
          '{"delta":{"message":{"tool_calls":{"function":{"arguments":"{\\"day\\": "}}}},' \
          '"index":0,"type":"tool-call-delta"}',
          '{"delta":{"message":{"tool_calls":{"function":{"arguments":"\\"2023-09-29\\"}"}}}},' \
          '"index":0,"type":"tool-call-delta"}',
          '{"index":0,"type":"tool-call-end"}',
          '{"delta":{"finish_reason":"TOOL_CALL"},"type":"message-end"}'
        )
      )

      expect(response.tool_calls.values.first).to have_attributes(
        id: 'query_daily_sales_report_j3f0adww9pmr',
        name: 'query_daily_sales_report',
        arguments: { 'day' => '2023-09-29' }
      )
      expect(response.thinking.text).to eq('I will')
    end

    it 'places streamed citations against the accumulated content' do
      response, chunks = stream(
        sse(
          '{"delta":{"message":{"role":"assistant"}},"id":"8268c123","type":"message-start"}',
          '{"delta":{"message":{"content":{"text":"","type":"text"}}},"index":0,"type":"content-start"}',
          '{"delta":{"message":{"content":{"text":"Both Nsync"}}},"index":0,"type":"content-delta"}',
          '{"delta":{"message":{"citations":{"end":10,"sources":[{"document":{"id":"1",' \
          '"snippet":"CSPC: NSYNC Popularity Analysis","title":"CSPC: NSYNC Popularity Analysis"},' \
          '"id":"doc:1","type":"document"}],"start":5,"text":"Nsync","type":"TEXT_CONTENT"}}},' \
          '"index":0,"type":"citation-start"}',
          '{"index":0,"type":"citation-end"}',
          '{"delta":{"message":{"content":{"text":" were popular"}}},"index":0,"type":"content-delta"}',
          '{"index":0,"type":"content-end"}',
          '{"delta":{"finish_reason":"COMPLETE"},"type":"message-end"}'
        )
      )

      citation = response.citations.first

      expect(response.content).to eq('Both Nsync were popular')
      expect(response.content[citation.start_index...citation.end_index]).to eq(citation.text)
      expect(citation.source_index).to eq(1)
      expect(chunks.flat_map(&:citations)).not_to be_empty
    end
  end
end
