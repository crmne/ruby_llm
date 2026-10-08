# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ToolCall do
  let(:from_model) { { 'start_date' => '2026-10-05', 'sort' => 'start_date', 'direction' => 'asc' } }
  let(:from_jsonb) { { 'sort' => 'start_date', 'direction' => 'asc', 'start_date' => '2026-10-05' } }

  it 'orders argument keys the way jsonb stores them' do
    tool_call = described_class.new(id: 'call_1', name: 'search_trips', arguments: from_model)

    expect(tool_call.arguments.keys).to eq(%w[sort direction start_date])
  end

  it 'orders nested hashes, including those inside arrays' do
    tool_call = described_class.new(
      id: 'call_1', name: 'search',
      arguments: { 'filters' => [{ 'value' => 1, 'op' => 'eq' }], 'b' => { 'zz' => 1, 'a' => 2 } }
    )

    expect(JSON.generate(tool_call.arguments)).to eq('{"b":{"a":2,"zz":1},"filters":[{"op":"eq","value":1}]}')
  end

  it 'leaves streamed argument fragments untouched' do
    tool_call = described_class.new(id: 'call_1', name: 'search', arguments: +'{"q":')

    tool_call.arguments << '"ruby"}'

    expect(tool_call.arguments).to eq('{"q":"ruby"}')
  end

  %i[anthropic openai].each do |provider|
    it "renders the same #{provider} request before and after a jsonb round trip" do
      context = RubyLLM.context do |config|
        config.anthropic_api_key = 'test'
        config.openai_api_key = 'test'
      end
      render = lambda do |arguments|
        chat = context.chat(model: model_for(provider), provider: provider)
        chat.add_message(role: :user, content: 'What trips do I have coming up?')
        tool_call = described_class.new(id: 'call_1', name: 'search_trips', arguments: arguments)
        chat.add_message(role: :assistant, content: '', tool_calls: { 'call_1' => tool_call })
        chat.add_message(role: :tool, content: '[]', tool_call_id: 'call_1')
        JSON.generate(chat.render)
      end

      expect(render.call(from_jsonb)).to eq(render.call(from_model))
    end
  end
end
