# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  let(:model) { model_for(:xai, :server_tools) }
  let(:context) { RubyLLM.context { |config| config.xai_api_key = 'test' } }
  let(:chat) { context.chat(model:, provider: :xai) }
  let(:output) { [{ 'type' => 'compaction', 'id' => 'cmp_1', 'encrypted_content' => 'opaque context' }] }
  let(:body) do
    { 'id' => 'cmp_1', 'object' => 'response.compaction', 'output' => output,
      'usage' => { 'input_tokens' => 23, 'output_tokens' => 7 } }
  end

  def stub_compaction(response_body = body)
    stub_request(:post, 'https://api.x.ai/v1/responses/compact').to_return_json(body: response_body)
  end

  it 'retains history while replacing subsequent wire context and recording usage and callbacks' do
    request = stub_compaction
    events = []
    chat.with_instructions('Remember the project.')
    chat.add_message(role: :user, content: 'The project is Thimble.')
    chat.add_message(role: :assistant, content: 'I will remember Thimble.')
    history = chat.messages.dup
    chat.before_message { events << :before }
    chat.after_message { |message| events << message }

    result = chat.compact

    expect(result).to be_a(RubyLLM::Message)
    expect(result).to have_attributes(role: :assistant, content: '', finish_reason: :stop, raw_content: body)
    expect(chat.messages).to eq(history + [result])
    expect(events).to eq([:before, result])
    expect(result.tokens).to have_attributes(input: 23, output: 7)
    expect(chat.tokens).to have_attributes(input: 23, output: 7)
    expect(chat.render[:input]).to eq(output)
    expect(chat.render[:instructions]).to eq('Remember the project.')
    expect(request).to have_been_requested.once
  end

  it 'uses the latest instructions and last compacted context across multiple rounds' do
    stub_compaction
    chat.with_instructions('Old instructions').ask_later('First request')
    chat.compact
    chat.with_instructions('Answer briefly.').ask_later('Second request')
    second_output = [{ 'type' => 'compaction', 'id' => 'cmp_2', 'encrypted_content' => 'second context' }]
    second = stub_compaction(body.merge('output' => second_output))

    chat.compact
    chat.ask_later('Third request')

    expect(second.with do |request|
      JSON.parse(request.body)['input'] == output +
          [{ 'role' => 'user', 'content' => 'Second request' }]
    end).to have_been_requested.once
    expect(chat.render[:input]).to eq(second_output + [{ role: 'user', content: 'Third request' }])
    expect(chat.render[:instructions]).to eq('Answer briefly.')
    expect(chat.messages.size).to eq(6)
  end

  it 'keeps current system attachments and cache boundaries in the rendered input' do
    stub_compaction
    chat.with_instructions('Current instructions', cache_until_here: true).ask_later('Summarize this')
    chat.compact

    expect(chat.render[:input].first).to include(role: 'system')
    expect(chat.render[:input].first[:content].first[:text]).to eq('Current instructions')
    expect(chat.render[:input].last).to eq(output.last)
  end

  it 'forwards request hooks and headers without generation-only options' do
    request = stub_compaction.with(headers: { 'X-Trace' => 'trace' }) do |req|
      payload = JSON.parse(req.body)
      payload['instructions'] == 'Keep the names.' && !payload.key?('temperature') && !payload.key?('tools')
    end
    chat.with_headers('X-Trace' => 'trace').with_temperature(0.3).ask_later('Hello')
    chat.before_request { |payload| payload[:instructions] = 'Keep the names.' }

    chat.compact

    expect(request).to have_been_requested.once
  end

  it 'leaves history unchanged after cancellation during the request while retaining billed usage' do
    stub_request(:post, 'https://api.x.ai/v1/responses/compact').to_return do
      chat.cancel
      { body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
    end
    chat.ask_later('Hello')

    expect { chat.compact }.to raise_error(RubyLLM::CancelledError)
    expect(chat.messages.size).to eq(1)
    expect(chat.tokens.input).to eq(23)
  end

  it 'refuses pending local or remote tool calls before contacting the provider' do
    [false, true].each do |remote|
      call = RubyLLM::ToolCall.new(id: 'call_1', name: 'search', arguments: {}, remote:)
      chat.messages = [RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { call.id => call })]

      expect { chat.compact }.to raise_error(RubyLLM::PendingToolCallsError)
    end
  end

  it 'does not enable manual compaction for other Responses dialects' do
    context = RubyLLM.context { |config| config.deepseek_api_key = 'test' }
    chat = context.chat(model: model_for(:deepseek), provider: :deepseek, protocol: :responses)

    expect { chat.compact }.to raise_error(RubyLLM::Error, /doesn't support manual compaction/)
  end

  it 'rejects malformed compaction responses without adding a message' do
    stub_compaction('object' => 'response', 'output' => [])

    expect { chat.compact }.to raise_error(RubyLLM::Error, /invalid compaction response/)
    expect(chat.messages).to be_empty
  end

  %i[xai openai azure].each do |provider|
    it "compacts and continues a conversation with #{provider}", :live do
      model = provider == :xai ? model_for(provider, :server_tools) : model_for(provider)
      chat = RubyLLM.chat(model:, provider:, protocol: :responses).with_instructions('Answer in one short sentence.')
      chat.ask_later('The project codename is Thimble. We write it in Ruby.')
      chat.add_message(role: :assistant, content: 'I will remember the Thimble project and Ruby.')
      history = chat.messages.dup

      result = chat.compact
      expect(result).to be_a(RubyLLM::Message)
      expect(result.raw_content['object']).to eq('response.compaction')
      expect(result.tokens.input).to be_positive
      expect(chat.messages).to eq(history + [result])

      answer = chat.ask('What is the project codename?')
      expect(answer.content.downcase).to include('thimble')
      expect(answer.tokens.input).to be_positive
    end
  end
end
