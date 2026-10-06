# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::Tools do
  def tool(name, deferred:, provider_options: {})
    base = instance_double(RubyLLM::Tool, name: name, description: "#{name} desc",
                                          parameters_schema: nil, declared_parameters: {},
                                          provider_options: provider_options)
    deferred ? RubyLLM::Tool::Deferred.new(base) : base
  end

  let(:search_use) do
    { 'type' => 'server_tool_use', 'id' => 'srv_1', 'name' => 'tool_search_tool_bm25',
      'input' => { 'query' => 'weather' } }
  end
  let(:search_result) do
    { 'type' => 'tool_search_tool_result', 'tool_use_id' => 'srv_1',
      'content' => { 'type' => 'tool_search_tool_search_result',
                     'tool_references' => [{ 'type' => 'tool_reference', 'tool_name' => 'weather_lookup' }] } }
  end

  describe '.function_for' do
    it 'omits defer_loading for a bare tool even if its class is deferred' do
      expect(described_class.function_for(tool('a', deferred: false))).not_to have_key(:defer_loading)
    end

    it 'emits defer_loading: true for a deferred tool' do
      expect(described_class.function_for(tool('a', deferred: true))[:defer_loading]).to be(true)
    end

    it 'renders cache_control alongside defer_loading and leaves the combination to Anthropic' do
      deferred = tool('a', deferred: true, provider_options: { cache_control: { type: 'ephemeral' } })
      expect(described_class.function_for(deferred))
        .to include(defer_loading: true, cache_control: { type: 'ephemeral' })
    end
  end

  describe '.apply_tool_search' do
    def payload_tools(*tools)
      payload = { tools: tools.map { |t| described_class.function_for(t) }, messages: [] }
      described_class.apply_tool_search(payload)[:tools]
    end

    it 'does not add the search tool when nothing is deferred' do
      expect(payload_tools(tool('a', deferred: false)).map { |t| t[:name] }).to eq(%w[a])
    end

    it 'adds the BM25 search tool once when any tool is deferred' do
      tools = payload_tools(tool('a', deferred: false), tool('b', deferred: true))

      expect(tools.last).to eq(described_class::NATIVE_TOOL_SEARCH)
      expect(tools.count { |t| t[:type] == 'tool_search_tool_bm25_20251119' }).to eq(1)
    end
  end

  describe '.tool_search_block?' do
    it 'matches the BM25 server_tool_use and its result, but not other server tools' do
      expect(described_class.tool_search_block?(search_use)).to be(true)
      expect(described_class.tool_search_block?(search_result)).to be(true)
      expect(described_class.tool_search_block?(search_use.merge('name' => 'tool_search_tool_regex'))).to be(true)
      expect(described_class.tool_search_block?({ 'type' => 'server_tool_use', 'name' => 'web_search' })).to be(false)
      expect(described_class.tool_search_block?({ 'type' => 'text', 'text' => 'hi' })).to be(false)
    end
  end

  describe 'parse_completion_body with tool search' do
    def parse(content_blocks)
      data = { 'model' => 'claude-haiku-4-5', 'content' => content_blocks,
               'usage' => { 'input_tokens' => 1, 'output_tokens' => 1 }, 'stop_reason' => 'tool_use' }
      RubyLLM::Protocols::Anthropic.allocate.send(:parse_completion_body, data, raw: nil)
    end

    it 'keeps the raw blocks for replay' do
      blocks = [{ 'type' => 'text', 'text' => 'searching' }, search_use, search_result]
      expect(parse(blocks).raw_content).to eq(blocks)
    end

    it 'keeps no raw content for an ordinary answer' do
      expect(parse([{ 'type' => 'text', 'text' => 'hi' }]).raw_content).to be_nil
    end
  end

  describe 'history replay of tool-search blocks through raw_content' do
    let(:protocol) { RubyLLM::Protocols::Anthropic.allocate }
    let(:message) do
      tool_use = { 'type' => 'tool_use', 'id' => 't1', 'name' => 'weather_lookup', 'input' => { 'city' => 'B' } }
      web_search = { 'type' => 'server_tool_use', 'id' => 'srv_2', 'name' => 'web_search', 'input' => {} }
      RubyLLM::Message.new(
        role: :assistant, content: 'searching',
        raw_content: [{ 'type' => 'text', 'text' => 'searching' }, search_use, search_result, web_search, tool_use],
        tool_calls: { 't1' => RubyLLM::ToolCall.new(id: 't1', name: 'weather_lookup', arguments: { 'city' => 'B' }) }
      )
    end

    def types(formatted)
      formatted[:content].map { |b| b['type'] || b[:type] }
    end

    it 'replays the search pair verbatim while the request still declares deferred tools' do
      expect(types(protocol.send(:format_message, message)))
        .to eq(%w[text server_tool_use tool_search_tool_result server_tool_use tool_use])
    end

    def replayed(tools)
      payload = { tools:, messages: [protocol.send(:format_message, message)] }
      described_class.apply_tool_search(payload)[:messages].first
    end

    it 'drops only the search pair when the request declares no search tool' do
      formatted = replayed([{ name: 'a' }])

      expect(types(formatted)).to eq(%w[text server_tool_use tool_use])
      expect(formatted[:content][1]['name']).to eq('web_search')
      expect(message.raw_content.size).to eq(5)
    end

    it 'keeps the pair while a deferred tool or a configured search tool is declared' do
      regex = { type: 'tool_search_tool_regex_20251119', name: 'tool_search_tool_regex' }

      expect(types(replayed([{ name: 'a', defer_loading: true }]))).to include('tool_search_tool_result')
      expect(types(replayed([regex]))).to include('tool_search_tool_result')
    end
  end

  describe 'end-to-end request payload via Chat#render' do
    include_context 'with configured RubyLLM'

    let(:chat) { RubyLLM::Chat.new(model: 'claude-haiku-4-5', provider: :anthropic) }

    before do
      stub_const('WeatherLookupTool', Class.new(RubyLLM::Tool) do
        description 'Looks up the current weather for a city.'
        defer
        parameter :city, description: 'City name'
        def execute(city:) = "weather in #{city}"
      end)
      stub_const('CurrentTimeTool', Class.new(RubyLLM::Tool) do
        description 'Returns the current time.'
        def execute = 'now'
      end)
    end

    it 'sends defer_loading: true on deferred tools and appends the BM25 primitive' do
      chat.with_tools(WeatherLookupTool)
      chat.with_tools(CurrentTimeTool)
      chat.ask_later('hi')

      tools = chat.render[:tools]
      weather = tools.find { |t| t[:name] == 'weather_lookup' }
      current = tools.find { |t| t[:name] == 'current_time' }

      expect(weather[:defer_loading]).to be(true)
      expect(current).not_to have_key(:defer_loading)
      expect(tools.count { |t| t[:type] == 'tool_search_tool_bm25_20251119' }).to eq(1)
    end

    it 'uses a configured search tool instead of adding the BM25 primitive' do
      chat.with_tools(WeatherLookupTool, CurrentTimeTool)
      chat.with_provider_tools({ type: 'tool_search_tool_regex_20251119', name: 'tool_search_tool_regex' })
      chat.ask_later('hi')

      types = chat.render[:tools].filter_map { |t| t[:type] }
      expect(types).to eq(%w[tool_search_tool_regex_20251119])
    end
  end
end
