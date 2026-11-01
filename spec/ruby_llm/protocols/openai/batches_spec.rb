# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::OpenAI::Batches do
  include_context 'with configured RubyLLM'

  let(:provider) { RubyLLM::Providers::OpenAI.new(RubyLLM.config) }

  def result(protocol, body)
    line = { 'custom_id' => '1', 'response' => { 'status_code' => 200, 'body' => body } }
    RubyLLM::Providers::OpenAI.protocols.fetch(protocol).new(provider).send(:parse_batch_result, line)
  end

  it 'fails only the Responses slot whose tool call was cut off' do
    body = {
      'id' => 'resp', 'status' => 'incomplete', 'incomplete_details' => { 'reason' => 'max_output_tokens' },
      'output' => [{ 'type' => 'function_call', 'call_id' => 'c', 'name' => 'f', 'arguments' => '{"a":' }]
    }

    expect(result(:responses, body)).to eq([1, nil, :failed])
  end

  it 'fails only the Chat Completions slot whose tool call was cut off' do
    call = { 'id' => 't', 'type' => 'function', 'function' => { 'name' => 'f', 'arguments' => '{"a":' } }
    body = { 'id' => 'c', 'choices' => [{ 'finish_reason' => 'length', 'message' => { 'tool_calls' => [call] } }] }

    expect(result(:chat_completions, body)).to eq([1, nil, :failed])
  end

  it 'fails only the slot that came back with no choices' do
    expect(result(:chat_completions, 'id' => 'c', 'choices' => [])).to eq([1, nil, :failed])
  end

  it 'still reads a good line' do
    body = { 'id' => 'c', 'choices' => [{ 'finish_reason' => 'stop', 'message' => { 'content' => 'fine' } }] }

    index, message = result(:chat_completions, body)

    expect([index, message.content]).to eq([1, 'fine'])
  end
end
