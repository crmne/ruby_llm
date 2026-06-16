# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'acts_as_batch' do # rubocop:disable RSpec/DescribeClass
  include_context 'with configured RubyLLM'

  let(:model) { 'claude-haiku-4-5' }

  # rubocop:disable RSpec/AnyInstance
  def stub_anthropic_batch(create:, find:, results:)
    allow_any_instance_of(RubyLLM::Providers::Anthropic).to receive(:create_batch).and_return(create)
    allow_any_instance_of(RubyLLM::Providers::Anthropic).to receive(:find_batch).and_return(find)
    allow_any_instance_of(RubyLLM::Providers::Anthropic).to receive(:batch_results).and_return(results)
  end
  # rubocop:enable RSpec/AnyInstance

  def answer(content)
    RubyLLM::Message.new(role: :assistant, content: content, input_tokens: 5, output_tokens: 1, model_id: model)
  end

  it 'submits, persists the batch and its chats, and routes answers home' do
    chats = [
      Chat.create!(model: model).ask_later('What is 2 + 2? Just the number.'),
      Chat.create!(model: model).ask_later('Name the largest planet. One word.')
    ]
    stub_anthropic_batch(
      create: { id: 'msgbatch_1', status: 'in_progress', completed: false },
      find: { id: 'msgbatch_1', status: 'ended', completed: true },
      results: [[0, answer('4')], [1, answer('Jupiter')]]
    )

    batch = Batch.create!(chats: chats)

    expect(batch.provider_batch_id).to eq('msgbatch_1')
    expect(batch.provider).to eq('anthropic')
    expect(batch.chat_ids).to eq(chats.map(&:id))

    # Poll from a fresh record, the way a job in another process would.
    polled = Batch.find(batch.id)
    expect(polled).to be_complete
    expect(polled.status).to eq('ended')

    polled.messages

    expect(chats.first.messages.reload.pluck(:role)).to eq(%w[user assistant])
    expect(chats.first.messages.last.content).to eq('4')
    expect(chats.first.messages.last.input_tokens).to eq(5)
    expect(chats.second.messages.reload.last.content).to eq('Jupiter')
  end

  it 'is idempotent: re-collecting never appends an answer twice' do
    chat = Chat.create!(model: model).ask_later('What is 2 + 2?')
    stub_anthropic_batch(
      create: { id: 'msgbatch_2', status: 'in_progress', completed: false },
      find: { id: 'msgbatch_2', status: 'ended', completed: true },
      results: [[0, answer('4')]]
    )
    batch = Batch.create!(chats: [chat])

    Batch.find(batch.id).tap(&:complete?).messages # first poll
    Batch.find(batch.id).messages # retry: a fresh record re-collects

    expect(chat.messages.reload.where(role: 'assistant').count).to eq(1)
  end

  it 'keeps answers aligned when a chat was deleted before collection' do
    chats = [
      Chat.create!(model: model).ask_later('First question.'),
      Chat.create!(model: model).ask_later('Second question.')
    ]
    stub_anthropic_batch(
      create: { id: 'msgbatch_3', status: 'in_progress', completed: false },
      find: { id: 'msgbatch_3', status: 'ended', completed: true },
      results: [[0, answer('first')], [1, answer('second')]]
    )
    batch = Batch.create!(chats: chats)

    chats.first.destroy! # gone by the time the job polls

    Batch.find(batch.id).messages

    # The survivor gets its own answer, not the deleted chat's.
    expect(chats.second.messages.reload.last.content).to eq('second')
  end
end
