# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Chat do
  include_context 'with configured RubyLLM'

  let(:chat) do
    RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic).tap do |c|
      stub_const('WeatherLookup', Class.new(RubyLLM::Tool) do
        description 'Looks up current weather for a city.'
        param :city, desc: 'City name'
        def execute(city:) = "Weather for #{city}: 15C"
      end)
      stub_const('StockQuote', Class.new(RubyLLM::Tool) do
        description 'Fetches the latest stock quote for a ticker.'
        param :ticker, desc: 'Ticker symbol'
        def execute(ticker:) = "Quote: #{ticker} = $42"
      end)
      c.with_tools(WeatherLookup, StockQuote, defer: true)
    end
  end

  def response_double(body)
    env = Struct.new(:request_body).new('{}')
    resp = Object.new
    resp.define_singleton_method(:body) { body }
    resp.define_singleton_method(:env)  { env }
    resp
  end

  describe 'parse_completion_response with tool_search_tool_result blocks' do
    it 'exposes referenced tool names on the resulting Message' do
      response = response_double(
        'model' => 'claude-haiku-4-5-20251001',
        'content' => [
          { 'type' => 'text', 'text' => 'Searching…' },
          { 'type' => 'server_tool_use', 'id' => 'srv_1', 'name' => 'tool_search_tool_bm25',
            'input' => { 'query' => 'weather' } },
          { 'type' => 'tool_search_tool_result',
            'tool_use_id' => 'srv_1',
            'content' => {
              'type' => 'tool_search_tool_search_result',
              'tool_references' => [
                { 'type' => 'tool_reference', 'tool_name' => 'weather_lookup' },
                { 'type' => 'tool_reference', 'tool_name' => 'stock_quote' }
              ]
            } }
        ],
        'usage' => { 'input_tokens' => 10, 'output_tokens' => 5 }
      )

      message = described_class.parse_completion_response(response)
      expect(message).to respond_to(:tool_references)
      expect(message.tool_references).to match_array(%w[weather_lookup stock_quote])
    end

    it 'returns an empty list when the response has no tool_search_tool_result block' do
      response = response_double(
        'model' => 'claude-haiku-4-5-20251001',
        'content' => [{ 'type' => 'text', 'text' => 'hello' }],
        'usage' => { 'input_tokens' => 1, 'output_tokens' => 1 }
      )

      message = described_class.parse_completion_response(response)
      expect(message.tool_references).to eq([])
    end
  end

  describe 'Chat promotes catalog entries when a response carries tool_references' do
    it 'moves the referenced tools from deferred_tools into @tools and fires on_tool_search' do
      events = []
      chat.on_tool_search { |e| events << e }

      message_with_refs = RubyLLM::Message.new(
        role: :assistant,
        content: 'Searching…',
        tool_references: %w[weather_lookup]
      )

      # The Chat should recognize tool_references and promote via its catalog.
      # We simulate the post-response path by calling the public hook.
      chat.send(:promote_from_tool_references, message_with_refs)

      expect(chat.tool_catalog.loaded_tools).to include(:weather_lookup)
      expect(chat.tools.keys).to include(:weather_lookup)
      expect(events.map(&:results)).to eq([[:weather_lookup]])
      # Native-path events carry a nil query — consumers can use this to
      # distinguish promotion by the server-side primitive from promotion by
      # the Ruby search_tools function.
      expect(events.first.query).to be_nil
    end

    it 'is a no-op when there are no references' do
      message = RubyLLM::Message.new(role: :assistant, content: 'plain', tool_references: [])
      expect { chat.send(:promote_from_tool_references, message) }.not_to(change { chat.tool_catalog.loaded_tools.dup })
    end
  end
end
