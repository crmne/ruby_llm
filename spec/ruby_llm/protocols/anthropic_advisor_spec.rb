# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic do
  include_context 'with configured RubyLLM'

  let(:chat) { RubyLLM.chat(model: 'claude-haiku-4-5', provider: :anthropic) }
  let(:executor) { RubyLLM::Tokens.new(input: 1760, output: 531, cache_read: 412) }
  let(:advisor) { RubyLLM::Tokens.new(input: 823, output: 1612) }
  let(:expected_cost) { cost_of('claude-haiku-4-5', executor) + cost_of('claude-opus-4-5', advisor) }
  let(:usage) do
    { input_tokens: 1760, cache_read_input_tokens: 412, cache_creation_input_tokens: 0, output_tokens: 531,
      iterations: [
        { type: 'message', input_tokens: 412, cache_read_input_tokens: 0, output_tokens: 89 },
        { type: 'advisor_message', model: 'claude-opus-4-5', input_tokens: 823, output_tokens: 1612 },
        { type: 'message', input_tokens: 1348, cache_read_input_tokens: 412, output_tokens: 442 }
      ] }
  end

  def cost_of(model, tokens)
    RubyLLM.models.find(model, provider: :anthropic).cost_for(tokens).total
  end

  def stub_messages(body, type: 'application/json')
    stub_request(:post, 'https://api.anthropic.com/v1/messages')
      .to_return(status: 200, headers: { 'Content-Type' => type }, body:)
  end

  def expect_separate_usage(response)
    advised, requested = response.ruby_llm_usage_entries

    expect(advised.model).to eq('claude-opus-4-5')
    expect(advised.tokens.to_h).to include(input_tokens: 823, output_tokens: 1612)
    expect(requested.model).to eq(chat.model.id)
    expect(requested.tokens.to_h).to include(input_tokens: 1760, output_tokens: 531, cache_read_tokens: 412)
    expect(response.cost.total).to be_within(1e-9).of(expected_cost)
    expect(chat.cost.total).to be_within(1e-9).of(expected_cost)
    expect(response.model_info).to eq(chat.model)
  end

  it 'prices advisor tokens with the model that ran them' do
    stub_messages(JSON.generate(id: 'm', type: 'message', role: 'assistant', model: 'claude-haiku-4-5', usage:,
                                content: [{ type: 'text', text: 'hi' }], stop_reason: 'end_turn'))

    expect_separate_usage(chat.ask('x'))
  end

  it 'prices advisor tokens of a streamed response with the model that ran them' do
    events = [
      { type: 'message_start', message: { model: 'claude-haiku-4-5', usage: { input_tokens: 412, output_tokens: 1 } } },
      { type: 'content_block_start', index: 0, content_block: { type: 'text', text: '' } },
      { type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: 'hi' } },
      { type: 'content_block_stop', index: 0 },
      { type: 'message_delta', delta: { stop_reason: 'end_turn' }, usage: },
      { type: 'message_stop' }
    ]
    stub_messages(events.map { |event| "event: #{event[:type]}\ndata: #{JSON.generate(event)}\n\n" }.join,
                  type: 'text/event-stream')

    expect_separate_usage(chat.ask('x') { |chunk| chunk })
  end
end
