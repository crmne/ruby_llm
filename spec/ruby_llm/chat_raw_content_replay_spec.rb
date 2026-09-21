# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  def anthropic_raw_content
    [
      { 'type' => 'server_tool_use', 'id' => 'srvtoolu_1', 'name' => 'web_search',
        'input' => { 'query' => 'latest Ruby' } },
      { 'type' => 'web_search_tool_result', 'tool_use_id' => 'srvtoolu_1', 'content' => [] },
      { 'type' => 'text', 'text' => 'Ruby 3.x is the latest stable line.' }
    ]
  end

  def openai_raw_content
    [
      { 'type' => 'web_search_call', 'id' => 'ws_1' },
      { 'type' => 'message', 'content' => [{ 'type' => 'output_text', 'text' => 'Found it.' }] }
    ]
  end

  def produced_by(provider, model, raw_content:, content: 'Done.', **attributes)
    entry = RubyLLM::Accounting::Usage::Entry.new(operation: :chat, provider:, model:, status: :succeeded)
    RubyLLM::Message.new(role: :assistant, content:, model:, raw_content:, usage_entries: [entry], **attributes)
  end

  def replay(chat, message)
    chat.add_message(role: :user, content: 'Hi')
    chat.add_message(message)
    chat.add_message(role: :user, content: 'And now?')
    chat.render
  end

  it 'drops Anthropic server-tool raw_content when the chat moves to OpenAI' do
    message = produced_by('anthropic', model_for(:anthropic), raw_content: anthropic_raw_content,
                                                              content: 'Ruby 3.x is the latest stable line.')
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    payload = replay(chat.with_model(model_for(:openai), provider: :openai), message)

    input_types = payload[:input].filter_map { |item| item[:type] }
    expect(input_types).not_to include('web_search_call')
    expect(payload[:input].flatten).not_to include(a_hash_including('type' => 'server_tool_use'))
    expect(payload[:input]).to include(
      role: 'assistant', content: [{ type: 'output_text', text: 'Ruby 3.x is the latest stable line.' }]
    )
  end

  it 'drops OpenAI Responses raw_content when the chat moves to Anthropic' do
    message = produced_by('openai', model_for(:openai), raw_content: openai_raw_content, content: 'Found it.')
    chat = RubyLLM.chat(model: model_for(:openai), provider: :openai)

    payload = replay(chat.with_model(model_for(:anthropic), provider: :anthropic), message)

    expect(payload[:messages][1]).to eq(role: 'assistant', content: [{ type: 'text', text: 'Found it.' }])
  end

  it 'keeps Anthropic raw_content for the provider that produced it' do
    message = produced_by('anthropic', model_for(:anthropic), raw_content: anthropic_raw_content,
                                                              raw_content_protocol: 'anthropic')
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    payload = replay(chat, message)

    expect(payload[:messages][1]).to eq(role: 'assistant', content: anthropic_raw_content)
  end

  it 'keeps OpenAI Responses raw_content for the provider that produced it' do
    message = produced_by('openai', model_for(:openai), raw_content: openai_raw_content,
                                                        raw_content_protocol: 'responses')
    chat = RubyLLM.chat(model: model_for(:openai), provider: :openai)

    payload = replay(chat, message)

    expect(payload[:input]).to include(*openai_raw_content)
  end

  it 'drops raw_content when the same provider switches protocols' do
    thinking = RubyLLM::Thinking.build(text: 'Private reasoning.', signature: 'anthropic-signature')
    message = produced_by(
      'vertexai', 'claude-haiku-4-5', raw_content: anthropic_raw_content,
                                      raw_content_protocol: 'anthropic',
                                      content: 'Ruby 3.x is the latest stable line.',
                                      thinking:
    )
    chat = RubyLLM.chat(model: 'claude-haiku-4-5', provider: :vertexai, protocol: :anthropic)

    payload = replay(chat.with_model(model_for(:vertexai), provider: :vertexai, protocol: :gemini), message)

    expect(payload[:contents][1][:parts]).to eq([{ text: 'Ruby 3.x is the latest stable line.' }])
  end

  it 'keeps raw_content whose producer is unknown' do
    message = RubyLLM::Message.new(role: :assistant, content: 'Ruby 3.x is the latest stable line.',
                                   raw_content: anthropic_raw_content)
    chat = RubyLLM.chat(model: model_for(:openai), provider: :openai)

    payload = replay(chat, message)

    expect(payload[:input].flatten).to include(a_hash_including('type' => 'server_tool_use'))
  end

  it 'does not guess the producer from a model id several providers serve' do
    message = RubyLLM::Message.new(role: :assistant, content: 'Ruby 3.x is the latest stable line.',
                                   model: model_for(:anthropic), raw_content: anthropic_raw_content)
    chat = RubyLLM.chat(model: model_for(:openrouter), provider: :openrouter, protocol: :responses)

    payload = replay(chat, message)

    expect(payload[:input]).to include(*anthropic_raw_content)
  end

  it 'drops foreign thinking and foreign raw_content together' do
    thinking = RubyLLM::Thinking.build(text: 'Let me think.', signature: 'anthropic-signature')
    message = produced_by('anthropic', model_for(:anthropic), raw_content: anthropic_raw_content,
                                                              content: 'Ruby 3.x is the latest stable line.', thinking:)
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    payload = replay(chat.with_model(model_for(:openai), provider: :openai), message)

    expect(payload[:input].map { |item| item[:type] }).not_to include('reasoning')
    expect(payload[:input].flatten).not_to include(a_hash_including('type' => 'server_tool_use'))
    expect(payload[:input]).to include(
      role: 'assistant', content: [{ type: 'output_text', text: 'Ruby 3.x is the latest stable line.' }]
    )
  end

  it 'raises instead of dropping a foreign raw-only assistant turn' do
    message = produced_by(
      'anthropic', model_for(:anthropic), raw_content: anthropic_raw_content, content: nil,
                                          server_tool_calls: [RubyLLM::ServerToolCall.new(type: 'web_search', raw: {})]
    )
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    expect do
      replay(chat.with_model(model_for(:openai), provider: :openai), message)
    end.to raise_error(RubyLLM::Error, /no normalized content to continue from/)
    expect(message.raw_content).to eq(anthropic_raw_content)
  end

  it 'drops foreign raw_content without raising when a function tool call remains' do
    message = produced_by(
      'anthropic', model_for(:anthropic), raw_content: anthropic_raw_content, content: nil,
                                          tool_calls: { 'call-1' => RubyLLM::ToolCall.new(id: 'call-1',
                                                                                          name: 'lookup',
                                                                                          arguments: {}) }
    )
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    expect do
      replay(chat.with_model(model_for(:openai), provider: :openai), message)
    end.not_to raise_error
    expect(message.raw_content).to eq(anthropic_raw_content)
  end

  it 'drops foreign raw_content without raising when an attachment remains' do
    image_path = File.expand_path('../fixtures/ruby.png', __dir__)
    message = produced_by('anthropic', model_for(:anthropic), raw_content: anthropic_raw_content, content: nil,
                                                              attachments: image_path)
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    expect do
      replay(chat.with_model(model_for(:openai), provider: :openai), message)
    end.not_to raise_error
    expect(message.raw_content).to eq(anthropic_raw_content)
  end

  it 'leaves the transcript untouched' do
    message = produced_by('anthropic', model_for(:anthropic), raw_content: anthropic_raw_content)
    chat = RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)

    replay(chat.with_model(model_for(:openai), provider: :openai), message)

    expect(chat.messages[1].raw_content).to eq(anthropic_raw_content)
  end
end
