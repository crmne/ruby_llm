# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  def produced_by(provider, model, thinking = nil, **attributes)
    entry = RubyLLM::Accounting::Usage::Entry.new(operation: :chat, provider:, model:, status: :succeeded)
    RubyLLM::Message.new(role: :assistant, content: 'Done.', model:, thinking:, usage_entries: [entry], **attributes)
  end

  def replay(chat, message)
    chat.add_message(role: :user, content: 'Hi')
    chat.add_message(message)
    chat.add_message(role: :user, content: 'And now?')
    chat.render
  end

  it 'drops a Gemini thought signature when the chat moves to Anthropic' do
    message = produced_by('gemini', model_for(:gemini), RubyLLM::Thinking.build(signature: 'gemini-signature'))
    chat = RubyLLM.chat(model: model_for(:gemini), provider: :gemini)

    payload = replay(chat.with_model(model_for(:anthropic), provider: :anthropic), message)

    expect(payload[:messages][1]).to eq(role: 'assistant', content: [{ type: 'text', text: 'Done.' }])
  end

  it 'drops Anthropic thinking when the chat moves to OpenAI' do
    thinking = RubyLLM::Thinking.build(text: 'Let me think.', signature: 'anthropic-signature')
    message = produced_by('anthropic', model_for(:anthropic), thinking)
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    payload = replay(chat.with_model(model_for(:openai), provider: :openai), message)

    expect(payload[:input].map { |item| item[:type] }).not_to include('reasoning')
    expect(payload[:input][1]).to include(role: 'assistant')
  end

  it 'drops the signature of a model the registry does not list' do
    message = produced_by('gemini', 'private-gemini', RubyLLM::Thinking.build(signature: 'gemini-signature'))
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    payload = replay(chat, message)

    expect(payload[:messages][1]).to eq(role: 'assistant', content: [{ type: 'text', text: 'Done.' }])
  end

  it 'drops native Anthropic thinking blocks when the chat moves to Vertex AI' do
    blocks = [{ 'type' => 'thinking', 'thinking' => 'Let me think.', 'signature' => 'anthropic-signature' }]
    message = produced_by('anthropic', model_for(:anthropic), raw_reasoning: { 'anthropic' => blocks })
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    payload = replay(chat.with_model(model_for(:anthropic), provider: :vertexai), message)

    expect(payload[:messages][1]).to eq(role: 'assistant', content: [{ type: 'text', text: 'Done.' }])
  end

  it 'drops the interaction a Gemini answer carries when the chat moves to Anthropic' do
    state = { 'response' => { 'object' => 'interaction', 'status' => 'completed',
                              'steps' => [{ 'type' => 'model_output', 'content' => [{ 'type' => 'text',
                                                                                      'text' => 'Done.' }] }] } }
    message = produced_by('gemini', model_for(:gemini, :mcp), raw_content: state)
    chat = RubyLLM.chat(model: model_for(:gemini, :mcp), provider: :gemini, protocol: :interactions)

    payload = replay(chat.with_model(model_for(:anthropic), provider: :anthropic), message)

    expect(payload[:messages][1]).to eq(role: 'assistant', content: [{ type: 'text', text: 'Done.' }])
  end

  it 'sends generateContent the answer of an Interactions turn, not the interaction' do
    state = { 'response' => { 'object' => 'interaction', 'status' => 'completed', 'steps' => [] } }
    message = produced_by('gemini', model_for(:gemini, :mcp), raw_content: state)
    chat = RubyLLM.chat(model: model_for(:gemini, :mcp), provider: :gemini, protocol: :interactions)

    payload = replay(chat.with_model(model_for(:gemini, :mcp), provider: :gemini), message)

    expect(payload[:contents][1]).to eq(role: 'model', parts: [{ text: 'Done.' }])
  end

  it 'drops Anthropic server tool blocks when the chat moves to OpenAI' do
    blocks = [
      { 'type' => 'server_tool_use', 'id' => 'srvtoolu_1', 'name' => 'web_search', 'input' => { 'query' => 'Ruby' } },
      { 'type' => 'web_search_tool_result', 'tool_use_id' => 'srvtoolu_1', 'content' => [] },
      { 'type' => 'text', 'text' => 'Done.' }
    ]
    message = produced_by('anthropic', model_for(:anthropic), raw_content: blocks)
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    payload = replay(chat.with_model(model_for(:openai), provider: :openai), message)

    expect(payload[:input][1]).to eq(role: 'assistant', content: [{ type: 'output_text', text: 'Done.' }])
  end

  it 'keeps the server tool blocks of the provider that produced them' do
    blocks = [{ 'type' => 'server_tool_use', 'id' => 'srvtoolu_1', 'name' => 'web_search', 'input' => {} },
              { 'type' => 'text', 'text' => 'Done.' }]
    message = produced_by('anthropic', model_for(:anthropic), raw_content: blocks)
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    payload = replay(chat, message)

    expect(payload[:messages][1]).to eq(role: 'assistant', content: blocks)
  end

  it 'drops Gemini tool call thought signatures when the chat moves to a Chat Completions provider' do
    call = RubyLLM::ToolCall.new(id: 'call-1', name: 'lookup', arguments: {}, thought_signature: 'gemini-signature')
    message = produced_by('gemini', model_for(:gemini), tool_calls: { 'call-1' => call })
    chat = RubyLLM.chat(model: model_for(:gemini), provider: :gemini)
    chat.add_message(role: :user, content: 'Hi')
    chat.add_message(message)
    chat.add_message(role: :tool, content: 'Found it.', tool_call_id: 'call-1')

    expect(chat.render[:contents][1][:parts]).to include(a_hash_including(thoughtSignature: 'gemini-signature'))
    payload = chat.with_model(model_for(:deepseek), provider: :deepseek).render

    expect(payload[:messages][1][:tool_calls].first).not_to have_key(:extra_content)
    expect(message.tool_calls['call-1'].thought_signature).to eq('gemini-signature')
  end

  it 'signs a call another provider made with the placeholder Gemini documents' do
    call = RubyLLM::ToolCall.new(id: 'call-1', name: 'lookup', arguments: {})
    thinking = RubyLLM::Thinking.build(signature: 'openai-encrypted-content')
    message = produced_by('openai', model_for(:openai), thinking, tool_calls: { 'call-1' => call })
    chat = RubyLLM.chat(model: model_for(:openai), provider: :openai)
    chat.add_message(role: :user, content: 'Hi')
    chat.add_message(message)
    chat.add_message(role: :tool, content: 'Found it.', tool_call_id: 'call-1')

    payload = chat.with_model(model_for(:gemini), provider: :gemini).render

    expect(payload[:contents][1][:parts]).to eq(
      [{ text: 'Done.' },
       { functionCall: { name: 'lookup', args: {} }, thoughtSignature: 'skip_thought_signature_validator' }]
    )
  end

  it 'sends Gemini no answer signature whose producer is unknown' do
    message = RubyLLM::Message.new(role: :assistant, content: 'Done.', model: model_for(:openai),
                                   thinking: RubyLLM::Thinking.build(signature: 'openai-encrypted-content'))
    chat = RubyLLM.chat(model: model_for(:gemini), provider: :gemini)

    payload = replay(chat, message)

    expect(payload[:contents][1][:parts]).to eq([{ text: 'Done.' }])
  end

  it 'sends Gemini back the answer signature it produced' do
    message = produced_by('gemini', model_for(:gemini), RubyLLM::Thinking.build(signature: 'gemini-signature'))
    chat = RubyLLM.chat(model: model_for(:gemini), provider: :gemini)

    payload = replay(chat, message)

    expect(payload[:contents][1][:parts]).to eq([{ text: 'Done.', thoughtSignature: 'gemini-signature' }])
  end

  it 'sends the Responses API no reasoning whose producer is unknown' do
    message = RubyLLM::Message.new(role: :assistant, content: 'Done.', model: model_for(:anthropic),
                                   thinking: RubyLLM::Thinking.build(text: 'Adding.', signature: 'anthropic-signature'))
    chat = RubyLLM.chat(model: model_for(:openai), provider: :openai)

    payload = replay(chat, message)

    expect(payload[:input][1]).to eq(role: 'assistant', content: [{ type: 'output_text', text: 'Done.' }])
  end

  it 'sends the Responses API back the reasoning it produced' do
    message = produced_by('openai', model_for(:openai), RubyLLM::Thinking.build(signature: 'openai-encrypted-content'))
    chat = RubyLLM.chat(model: model_for(:openai), provider: :openai)

    payload = replay(chat, message)

    expect(payload[:input][1]).to eq(type: 'reasoning', summary: [], encrypted_content: 'openai-encrypted-content')
  end

  it 'keeps thinking for the provider that produced it' do
    thinking = RubyLLM::Thinking.build(text: 'Let me think.', signature: 'anthropic-signature')
    message = produced_by('anthropic', model_for(:anthropic), thinking)
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    payload = replay(chat, message)

    expect(payload[:messages][1][:content].first).to eq(
      type: 'thinking', thinking: 'Let me think.', signature: 'anthropic-signature'
    )
  end

  it 'sends Claude no thinking whose producer is unknown' do
    message = RubyLLM::Message.new(role: :assistant, content: 'Done.',
                                   thinking: RubyLLM::Thinking.build(text: 'Adding.', signature: 'gemini-signature'))
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    payload = replay(chat, message)

    expect(payload[:messages][1]).to eq(role: 'assistant', content: [{ type: 'text', text: 'Done.' }])
  end

  it 'keeps the thinking blocks of a Claude answer whose producer is unknown' do
    blocks = [{ 'type' => 'thinking', 'thinking' => 'Let me think.', 'signature' => 'anthropic-signature' }]
    message = RubyLLM::Message.new(role: :assistant, content: 'Done.', raw_reasoning: { 'anthropic' => blocks })
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    payload = replay(chat, message)

    expect(payload[:messages][1][:content].first).to eq(blocks.first)
  end

  it 'does not guess the producer from a model id several providers serve' do
    message = RubyLLM::Message.new(role: :assistant, content: 'Done.', model: model_for(:anthropic),
                                   thinking: RubyLLM::Thinking.build(signature: 'signature'))
    chat = RubyLLM.chat(model: model_for(:openrouter), provider: :openrouter)

    payload = replay(chat, message)

    expect(payload[:messages][1][:reasoning_details]).to eq([{ type: 'reasoning.encrypted', data: 'signature' }])
  end

  it 'leaves the transcript untouched' do
    message = produced_by('gemini', model_for(:gemini), RubyLLM::Thinking.build(signature: 'gemini-signature'))
    chat = RubyLLM.chat(model: model_for(:gemini), provider: :gemini)

    replay(chat.with_model(model_for(:anthropic), provider: :anthropic), message)

    expect(chat.messages[1].thinking.signature).to eq('gemini-signature')
  end
end
