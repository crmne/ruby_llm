# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:call) { RubyLLM::ToolCall.new(id: 'call_1', name: 'weather_lookup', arguments: { 'city' => 'Berlin' }) }

  before do
    stub_const('WeatherLookup', Class.new(RubyLLM::Tool) do
      description 'Looks up the current weather for a city'
      parameter :city, description: 'City name'
      def execute(city:) = "Sunny in #{city}"
    end)
  end

  def produced_by(provider, model, raw_content)
    entry = RubyLLM::Accounting::Usage::Entry.new(operation: :chat, provider:, model:, status: :succeeded)
    RubyLLM::Message.new(role: :assistant, content: nil, raw_content:, usage_entries: [entry],
                         tool_calls: { call.id => call })
  end

  def render(provider, model, message)
    chat = RubyLLM.chat(model:, provider:).with_tools(WeatherLookup, defer: true)
    chat.add_message(role: :user, content: 'What is the weather in Berlin?')
    chat.add_message(message)
    chat.add_message(role: :tool, content: 'Sunny', tool_call_id: call.id)
    chat.add_message(role: :user, content: 'And in Paris?')
    chat.render
  end

  def types(items)
    items.filter_map { |item| item['type'] || item[:type] }.map(&:to_s)
  end

  context 'with OpenAI Responses' do
    let(:function_call) do
      { 'type' => 'function_call', 'call_id' => 'call_1', 'name' => 'weather_lookup',
        'arguments' => '{"city":"Berlin"}', 'namespace' => 'weather_lookup' }
    end
    let(:search) do
      [{ 'type' => 'tool_search_call', 'id' => 'tsc_1', 'arguments' => { 'query' => 'weather' } },
       { 'type' => 'tool_search_output', 'id' => 'tso_1', 'tools' => [{ 'name' => 'weather_lookup' }] }]
    end
    let(:reasoning) { { 'type' => 'reasoning', 'id' => 'rs_1', 'encrypted_content' => 'opaque', 'summary' => [] } }

    def input(model, raw_content)
      render(:openai, model, produced_by('openai', 'gpt-5.4', raw_content))[:input]
    end

    it 'replays the search and the namespaced call to another model, without the reasoning' do
      replayed = input('gpt-5.4-mini', [reasoning, *search, function_call])

      expect(types(replayed)).to eq(%w[tool_search_call tool_search_output function_call function_call_output])
      expect(replayed).to include(function_call)
    end

    it 'replays the reasoning too to the model that produced it' do
      expect(types(input('gpt-5.4', [reasoning, *search, function_call])))
        .to eq(%w[reasoning tool_search_call tool_search_output function_call function_call_output])
    end

    it 'replays a turn that also used another server tool without its native content' do
      replayed = input('gpt-5.4-mini', [{ 'type' => 'web_search_call', 'id' => 'ws_1' }, *search, function_call])

      expect(types(replayed)).to eq(%w[function_call function_call_output])
      expect(replayed.find { |item| item[:type] == 'function_call' }).not_to have_key(:namespace)
    end
  end

  context 'with Anthropic' do
    let(:search) do
      [{ 'type' => 'server_tool_use', 'id' => 'srvtoolu_1', 'name' => 'tool_search_tool_bm25',
         'input' => { 'query' => 'weather' } },
       { 'type' => 'tool_search_tool_result', 'tool_use_id' => 'srvtoolu_1',
         'content' => { 'type' => 'tool_search_tool_search_result',
                        'tool_references' => [{ 'type' => 'tool_reference', 'tool_name' => 'weather_lookup' }] } }]
    end
    let(:tool_use) do
      { 'type' => 'tool_use', 'id' => 'call_1', 'name' => 'weather_lookup', 'input' => { 'city' => 'Berlin' } }
    end
    let(:thinking) { { 'type' => 'thinking', 'thinking' => 'Checking.', 'signature' => 'opaque' } }

    def replayed_turn(model, raw_content)
      render(:anthropic, model, produced_by('anthropic', 'claude-haiku-4-5', raw_content))[:messages][1][:content]
    end

    it 'replays the search and the call to another model, without the thinking' do
      expect(types(replayed_turn('claude-sonnet-4-5', [thinking, *search, tool_use])))
        .to eq(%w[server_tool_use tool_search_tool_result tool_use])
    end

    it 'replays the thinking too to the model that produced it' do
      expect(types(replayed_turn('claude-haiku-4-5', [thinking, *search, tool_use])))
        .to eq(%w[thinking server_tool_use tool_search_tool_result tool_use])
    end

    it 'replays a turn that also used another server tool without its native content' do
      web_search = { 'type' => 'server_tool_use', 'id' => 'srvtoolu_2', 'name' => 'web_search', 'input' => {} }

      expect(types(replayed_turn('claude-sonnet-4-5', [web_search, *search, tool_use]))).to eq(%w[tool_use])
    end
  end
end
