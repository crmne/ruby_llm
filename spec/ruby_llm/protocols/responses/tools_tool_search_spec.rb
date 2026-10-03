# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Responses::Tools do
  def tool(name, deferred:)
    base = instance_double(RubyLLM::Tool, name: name, description: "#{name} desc",
                                          parameters_schema: { 'type' => 'object' },
                                          declared_parameters: {}, provider_options: {})
    deferred ? RubyLLM::Tool::Registration.new(base, deferred: true) : base
  end

  describe '.tool_for' do
    it 'omits defer_loading for a bare tool' do
      expect(described_class.tool_for(tool('a', deferred: false))).not_to have_key(:defer_loading)
    end

    it 'emits defer_loading: true for a deferred Registration' do
      expect(described_class.tool_for(tool('a', deferred: true))[:defer_loading]).to be(true)
    end
  end

  describe '.format_tools' do
    it 'does not append the tool_search tool when nothing is deferred' do
      formatted = described_class.format_tools({ a: tool('a', deferred: false) })
      expect(formatted.map { |t| t[:type] }).not_to include('tool_search')
    end

    it 'appends the native tool_search tool once when any function is deferred' do
      formatted = described_class.format_tools({ a: tool('a', deferred: false), b: tool('b', deferred: true) })
      expect(formatted.last).to eq({ type: 'tool_search' })
      expect(formatted.count { |t| t[:type] == 'tool_search' }).to eq(1)
    end
  end

  describe 'Responses::Chat tool-search parsing' do
    let(:output) do
      [
        { 'type' => 'tool_search_call', 'id' => 'ts_1' },
        { 'type' => 'tool_search_output', 'tools' => [{ 'name' => 'weather_lookup' }, { 'name' => 'stock_price' }] },
        { 'type' => 'function_call', 'call_id' => 'c1', 'name' => 'weather_lookup', 'arguments' => '{}' }
      ]
    end

    it 'keeps the raw output on the parsed Message for replay' do
      data = { 'output' => output, 'model' => 'gpt-5.4', 'status' => 'completed', 'usage' => {} }
      message = RubyLLM::Protocols::Responses.allocate.send(:parse_completion_body, data, raw: nil)
      expect(message.raw_content).to eq(output)
    end
  end

  describe 'a function call the model reached through tool search' do
    let(:chat_protocol) { RubyLLM::Protocols::Responses::Chat }
    let(:call) do
      { 'type' => 'function_call', 'call_id' => 'c1', 'name' => 'weather_lookup', 'arguments' => '{}',
        'namespace' => 'weather_lookup' }
    end

    def parse(output)
      data = { 'output' => output, 'model' => 'gpt-5.4', 'status' => 'completed', 'usage' => {} }
      RubyLLM::Protocols::Responses.allocate.send(:parse_completion_body, data, raw: nil)
    end

    it 'keeps the raw output, so the namespace the API assigned is replayed with the call' do
      message = parse([call])

      expect(message.raw_content).to eq([call])
      expect(message.tool_calls['c1'].to_h).not_to have_key(:namespace)
      expect(chat_protocol.format_assistant_items(message)).to eq([call])
    end

    it 'leaves an ordinary function call to the plain replay' do
      message = parse([call.except('namespace')])

      expect(message.raw_content).to be_nil
      expect(chat_protocol.format_function_call_items(message.tool_calls).first).not_to have_key(:namespace)
    end
  end

  describe 'history replay of tool-search items through raw_content' do
    let(:protocol) { RubyLLM::Protocols::Responses.allocate }
    let(:items) do
      [{ 'type' => 'tool_search_call', 'id' => 'ts_1' },
       { 'type' => 'tool_search_output', 'tools' => [{ 'name' => 'weather_lookup' }] },
       { 'type' => 'function_call', 'call_id' => 'c1', 'name' => 'weather_lookup', 'arguments' => '{}',
         'namespace' => 'weather_lookup' }]
    end
    let(:message) do
      RubyLLM::Message.new(
        role: :assistant, content: nil, raw_content: items,
        tool_calls: { 'c1' => RubyLLM::ToolCall.new(id: 'c1', name: 'weather_lookup', arguments: {}) }
      )
    end

    it 'replays the items verbatim while the request still declares deferred tools' do
      types = protocol.send(:format_assistant_items, message).map { |i| i['type'] }
      expect(types).to eq(%w[tool_search_call tool_search_output function_call])
    end

    it 'omits the search items when the request no longer carries deferred tools, keeping the namespaced call' do
      replayed = protocol.send(:format_assistant_items, message, replay_search: false)

      expect(replayed).to eq([items.last])
      expect(replayed.first['namespace']).to eq('weather_lookup')
    end

    describe 'from render_payload' do
      let(:model) { instance_double(RubyLLM::Model, id: 'gpt-5.4', supports?: false, reasoning_option: nil) }

      def replayed_types(tools, provider_tools: [])
        payload = protocol.send(:render_payload, [message],
                                tools: tools, temperature: nil, model: model, provider_tools: provider_tools)
        payload[:input].map { |item| item['type'] }
      end

      it 'keeps the search items while a deferred tool is rendered and strips them otherwise' do
        expect(replayed_types({ a: tool('a', deferred: true) })).to include('tool_search_call')
        expect(replayed_types({ a: tool('a', deferred: false) })).not_to include('tool_search_call')
      end

      it 'keeps the search items while the tool_search provider tool is configured' do
        expect(replayed_types({}, provider_tools: [{ type: 'tool_search' }])).to include('tool_search_call')
        expect(replayed_types({}, provider_tools: [{ type: 'web_search' }])).not_to include('tool_search_call')
      end
    end
  end

  describe 'end-to-end request payload via Chat#render' do
    include_context 'with configured RubyLLM'

    let(:chat) { RubyLLM::Chat.new(model: 'gpt-5.4', provider: :openai) }

    before do
      stub_const('WeatherLookupTool', Class.new(RubyLLM::Tool) do
        description 'Looks up the current weather for a city.'
        deferred
        parameter :city, description: 'City name'
        def execute(city:) = "weather in #{city}"
      end)
      stub_const('CurrentTimeTool', Class.new(RubyLLM::Tool) do
        description 'Returns the current time.'
        def execute = 'now'
      end)
    end

    it 'sends defer_loading on deferred tools and appends the tool_search tool' do
      chat.with_tools(WeatherLookupTool, CurrentTimeTool)
      chat.ask_later('hi')

      tools = chat.render[:tools]
      weather = tools.find { |t| t[:name] == 'weather_lookup' }
      current = tools.find { |t| t[:name] == 'current_time' }

      expect(weather[:defer_loading]).to be(true)
      expect(current).not_to have_key(:defer_loading)
      expect(tools.count { |t| t[:type] == 'tool_search' }).to eq(1)
    end

    it 'does not add a second tool_search when one is configured' do
      chat.with_tools(WeatherLookupTool, CurrentTimeTool)
      chat.with_provider_tools({ type: 'tool_search' })
      chat.ask_later('hi')

      expect(chat.render[:tools].count { |t| t[:type] == 'tool_search' }).to eq(1)
    end
  end
end
