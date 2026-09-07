# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::ActiveRecord::ChatMethods do
  include_context 'with configured RubyLLM'

  let(:agent) do
    klass = Class.new(RubyLLM::Agent) do
      chat_model Chat
    end
    klass.model model_for(:xai, :server_tools), provider: :xai
    klass
  end
  let(:output) { [{ 'type' => 'compaction', 'id' => 'cmp_1', 'encrypted_content' => 'opaque context' }] }
  let(:body) do
    { 'object' => 'response.compaction', 'output' => output,
      'usage' => { 'input_tokens' => 31, 'output_tokens' => 11 } }
  end

  before do
    RubyLLM.config.xai_api_key = 'test'
    stub_request(:post, 'https://api.x.ai/v1/responses/compact').to_return_json(body:)
  end

  it 'persists compaction and its usage through Agent.find without deleting earlier messages' do
    chat = agent.create!
    chat.with_instructions('Remember Thimble.')
    chat.ask_later('The project language is Ruby.')
    chat.add_message(role: :assistant, content: 'I will remember Ruby.')
    ids = chat.messages_association.pluck(:id)

    result = chat.compact
    restored = agent.find(chat.id)

    expect(result).to be_a(RubyLLM::Message)
    expect(restored.messages_association.pluck(:id)).to include(*ids)
    expect(restored.messages_association.count).to eq(4)
    expect(restored.messages_association.last.to_llm.raw_content).to eq(body)
    expect(restored.tokens).to have_attributes(input: 31, output: 11)
    expect(restored.render[:input]).to eq(output)

    restored.with_instructions('Answer with only the language name.').ask_later('Which language?')
    expect(agent.find(chat.id).render).to include(
      instructions: 'Answer with only the language name.',
      input: output + [{ role: 'user', content: 'Which language?' }]
    )
  end

  it 'keeps only the last compacted context on the wire after reloading multiple rounds' do
    chat = agent.create!
    chat.ask_later('The project language is Ruby.')
    chat.compact
    restored = agent.find(chat.id)
    restored.ask_later('The project codename is Thimble.')
    second = [{ 'type' => 'compaction', 'id' => 'cmp_2', 'encrypted_content' => 'new context' }]
    stub_request(:post, 'https://api.x.ai/v1/responses/compact').to_return_json(body: body.merge('output' => second))

    restored.compact

    expect(agent.find(chat.id).render[:input]).to eq(second)
    expect(chat.messages_association.reload.count).to eq(4)
    expect(agent.find(chat.id).tokens).to have_attributes(input: 62, output: 22)
  end

  it 'honors cancellation written by another process before compaction' do
    chat = agent.create!
    chat.ask_later('Keep this message.')
    restored = agent.find(chat.id)
    Chat.find(chat.id).cancel

    expect { restored.compact }.to raise_error(RubyLLM::CancelledError)
    expect(chat.messages_association.reload.count).to eq(1)
    expect(a_request(:post, 'https://api.x.ai/v1/responses/compact')).not_to have_been_made
  end
end
