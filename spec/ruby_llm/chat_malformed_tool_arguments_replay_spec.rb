# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:malformed) { '{"path":"zzq' }

  def render(model, provider:, protocol: nil, raw_content: nil)
    call = RubyLLM::ToolCall.new(id: 'call_1', name: 'echo', malformed_arguments: malformed)
    chat = RubyLLM.chat(model:, provider:, protocol:, assume_model_exists: true)
    chat.add_message(role: :user, content: 'List the files')
    chat.add_message(role: :assistant, content: nil, tool_calls: { 'call_1' => call }, raw_content:)
    chat.add_message(role: :tool, content: '{"error":"Try again"}', tool_call_id: 'call_1')
    JSON.generate(chat.render)
  end

  {
    'Anthropic' => [:anthropic],
    'Chat Completions' => %i[openai chat_completions],
    'Cohere' => [:cohere],
    'Converse' => [:bedrock],
    'Gemini' => [:gemini],
    'Interactions' => %i[gemini interactions],
    'Mistral Conversations' => %i[mistral conversations],
    'Responses' => %i[openai responses]
  }.each do |name, (provider, protocol)|
    it "replays a call with malformed arguments to #{name} with empty arguments" do
      payload = render(model_for(provider), provider:, protocol:)

      expect(payload).to include('"name":"echo"')
      expect(payload).not_to include('zzq')
    end
  end

  it 'replays Chat Completions arguments as an empty JSON object' do
    payload = JSON.parse(render(model_for(:openai), provider: :openai, protocol: :chat_completions))

    expect(payload['messages'][1]['tool_calls'][0]['function']['arguments']).to eq('{}')
  end

  context 'with provider content kept for replay' do
    it 'empties the arguments of a Responses function call item' do
      raw = [{ 'type' => 'function_call', 'call_id' => 'call_1', 'name' => 'echo', 'arguments' => malformed }]
      payload = JSON.parse(render(model_for(:openai), provider: :openai, protocol: :responses, raw_content: raw))

      expect(payload['input'][1]).to eq(raw.first.merge('arguments' => '{}'))
    end

    it 'empties the input of an Anthropic tool use block' do
      raw = [{ 'type' => 'tool_use', 'id' => 'call_1', 'name' => 'echo', 'input' => 'zzq' }]
      payload = JSON.parse(render(model_for(:anthropic), provider: :anthropic, raw_content: raw))

      expect(payload['messages'][1]['content']).to eq([raw.first.merge('input' => {})])
    end

    it 'empties the arguments of a Mistral conversation function call entry' do
      raw = [{ 'type' => 'function.call', 'tool_call_id' => 'call_1', 'name' => 'echo', 'arguments' => malformed }]
      payload = render(model_for(:mistral), provider: :mistral, protocol: :conversations, raw_content: raw)

      expect(payload).not_to include('zzq')
      expect(JSON.parse(payload)['inputs']).to include(raw.first.merge('arguments' => '{}'))
    end

    it 'empties the arguments of a Mistral chat message tool call' do
      raw = [{ 'role' => 'assistant', 'content' => '',
               'tool_calls' => [{ 'id' => 'call_1', 'function' => { 'name' => 'echo', 'arguments' => malformed } }] }]
      payload = JSON.parse(render(model_for(:mistral), provider: :mistral, protocol: :chat_completions,
                                                       raw_content: raw))

      expect(payload['messages'][1]['tool_calls'][0]['function']['arguments']).to eq('{}')
    end

    it 'empties the arguments of an Interactions function call step' do
      raw = { 'response' => { 'object' => 'interaction',
                              'steps' => [{ 'type' => 'function_call', 'id' => 'call_1', 'name' => 'echo',
                                            'arguments' => 'zzq' }] } }
      payload = render(model_for(:gemini), provider: :gemini, protocol: :interactions, raw_content: raw)

      expect(payload).to include('call_1')
      expect(payload).not_to include('zzq')
    end
  end
end
