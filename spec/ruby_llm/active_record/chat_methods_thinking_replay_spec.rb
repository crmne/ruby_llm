# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  def persist_thinking(message, chat: Chat.create!(model: model_for(:openai)), provider: nil)
    chat.send(:persist_new_message)
    if provider
      entry = RubyLLM::Accounting::Usage::Entry.new(operation: :chat, provider:, model: message.model,
                                                    status: :succeeded)
      chat.send(:persist_usage_entry, entry)
      message.ruby_llm_usage_entries = [entry]
    end
    chat.send(:persist_message_completion, message)
    Message.find(chat.instance_variable_get(:@message).id).to_llm
  end

  it 'replays all Anthropic thinking blocks after reloading the message' do
    blocks = [
      { 'type' => 'thinking', 'thinking' => 'First.', 'signature' => 'sig-one' },
      { 'type' => 'redacted_thinking', 'data' => 'encrypted' },
      { 'type' => 'thinking', 'thinking' => 'Second.', 'signature' => 'sig-two' }
    ]
    protocol = RubyLLM::Protocols::Anthropic.allocate
    message = protocol.send(:parse_completion_body,
                            { 'model' => model_for(:anthropic), 'content' => blocks, 'usage' => {} }, raw: nil)

    restored = persist_thinking(message)
    rendered = protocol.send(:format_message, restored)

    expect(JSON.parse(JSON.generate(rendered)).fetch('content')).to eq(blocks)
  end

  it 'replays all Converse thinking blocks after reloading the message' do
    blocks = [
      { 'reasoningContent' => { 'reasoningText' => { 'text' => 'First.', 'signature' => 'sig-one' } } },
      { 'reasoningContent' => { 'redactedContent' => Base64.strict_encode64('encrypted') } },
      { 'reasoningContent' => { 'reasoningText' => { 'text' => 'Second.', 'signature' => 'sig-two' } } }
    ]
    protocol = RubyLLM::Protocols::Converse.allocate
    message = protocol.send(:parse_completion_body,
                            { 'modelId' => model_for(:bedrock), 'output' => { 'message' => { 'content' => blocks } } },
                            raw: nil)

    restored = persist_thinking(message)
    rendered = protocol.send(:format_message_content, restored)

    expect(JSON.parse(JSON.generate(rendered))).to eq(blocks)
  end

  it 'drops a persisted Gemini thought signature when the chat moves to Anthropic' do
    parts = [{ 'text' => '221', 'thoughtSignature' => 'gemini-signature' }]
    message = RubyLLM::Protocols::Gemini.allocate.send(
      :parse_completion_body,
      { 'modelVersion' => model_for(:gemini), 'candidates' => [{ 'content' => { 'parts' => parts } }] }, raw: nil
    )
    chat = Chat.create!(model: model_for(:gemini), provider: 'gemini')
    chat.add_message(role: :user, content: '13*17?')
    persist_thinking(message, chat:, provider: 'gemini')
    chat.with_model(model_for(:anthropic), provider: :anthropic)
    chat.add_message(role: :user, content: 'As a table.')

    payload = Chat.find(chat.id).to_llm.render

    expect(payload[:messages][1]).to eq(role: 'assistant', content: [{ type: 'text', text: '221' }])
    expect(chat.messages.second.thinking_signature).to eq('gemini-signature')
  end

  it 'drops persisted Anthropic server-tool raw_content when the chat moves to OpenAI' do
    blocks = [
      { 'type' => 'server_tool_use', 'id' => 'srvtoolu_1', 'name' => 'web_search',
        'input' => { 'query' => 'latest Ruby' } },
      { 'type' => 'web_search_tool_result', 'tool_use_id' => 'srvtoolu_1', 'content' => [] },
      { 'type' => 'text', 'text' => 'Ruby 3.x is the latest stable line.' }
    ]
    protocol = RubyLLM::Protocols::Anthropic.allocate
    message = protocol.send(:parse_completion_body,
                            { 'model' => model_for(:anthropic), 'content' => blocks, 'usage' => {} }, raw: nil)

    chat = Chat.create!(model: model_for(:anthropic), provider: 'anthropic')
    chat.add_message(role: :user, content: 'What is the latest Ruby?')
    restored = persist_thinking(message, chat:, provider: 'anthropic')
    chat.with_model(model_for(:openai), provider: :openai)
    chat.add_message(role: :user, content: 'And now?')

    payload = Chat.find(chat.id).to_llm.render

    input_types = payload[:input].filter_map { |item| item[:type] }
    expect(input_types).not_to include('web_search_call')
    expect(payload[:input].flatten).not_to include(a_hash_including('type' => 'server_tool_use'))
    expect(payload[:input]).to include(
      role: 'assistant', content: [{ type: 'output_text', text: 'Ruby 3.x is the latest stable line.' }]
    )
    expect(restored.raw_content).to eq(blocks)
    expect(Chat.find(chat.id).messages.second.raw_content).to eq(blocks)
  end

  it 'keeps persisted raw_content from before protocol provenance when the chat continues with the same provider' do
    blocks = [
      { 'type' => 'server_tool_use', 'id' => 'srvtoolu_1', 'name' => 'web_search',
        'input' => { 'query' => 'latest Ruby' } },
      { 'type' => 'web_search_tool_result', 'tool_use_id' => 'srvtoolu_1', 'content' => [] },
      { 'type' => 'text', 'text' => 'Ruby 3.x is the latest stable line.' }
    ]
    protocol = RubyLLM::Protocols::Anthropic.allocate
    message = protocol.send(:parse_completion_body,
                            { 'model' => model_for(:anthropic), 'content' => blocks, 'usage' => {} }, raw: nil)

    chat = Chat.create!(model: model_for(:anthropic), provider: 'anthropic')
    chat.add_message(role: :user, content: 'What is the latest Ruby?')
    persist_thinking(message, chat:, provider: 'anthropic')
    chat.add_message(role: :user, content: 'And now?')

    stored = Chat.find(chat.id).messages.second.raw_content
    payload = Chat.find(chat.id).to_llm.render

    expect(stored).to eq(blocks)
    expect(payload[:messages][1]).to eq(role: 'assistant', content: blocks)
  end

  it 'filters persisted raw content after switching protocols' do
    blocks = [{ 'type' => 'server_tool_use', 'id' => 'srvtoolu_1', 'name' => 'web_search',
                'input' => { 'query' => 'latest Ruby' } }]
    message = RubyLLM::Message.new(
      role: :assistant, content: 'Ruby 3.x is the latest stable line.', model: 'claude-haiku-4-5',
      raw_content: blocks, raw_content_protocol: :anthropic
    )
    chat = Chat.create!(model: 'claude-haiku-4-5', provider: 'vertexai')
    chat.add_message(role: :user, content: 'Search for the latest Ruby version.')

    restored = persist_thinking(message, chat:, provider: 'vertexai')
    stored = chat.messages.last.raw_content
    reloaded = Chat.find(chat.id).to_llm
    reloaded.with_model(model_for(:vertexai), provider: :vertexai, protocol: :gemini)
    reloaded.add_message(role: :user, content: 'Summarize the result.')
    payload = reloaded.render

    expect(stored).to include(
      RubyLLM::Message::RAW_CONTENT_STORAGE_KEY => { 'version' => 1, 'protocol' => 'anthropic' }
    )
    expect(restored.raw_content).to eq(blocks)
    expect(restored.raw_content_protocol).to eq('anthropic')
    expect(payload[:contents][1][:parts]).to eq([{ text: 'Ruby 3.x is the latest stable line.' }])
  end
end
