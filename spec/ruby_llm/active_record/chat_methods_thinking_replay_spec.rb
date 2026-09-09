# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  def persist_thinking(message)
    chat = Chat.create!(model: model_for(:openai))
    chat.send(:persist_new_message)
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
end
