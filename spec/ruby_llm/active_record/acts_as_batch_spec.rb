# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RubyLLM::Batch do # rubocop:disable RSpec/SpecFilePathFormat
  include_context 'with configured RubyLLM'

  let(:model) { 'claude-haiku-4-5' }

  it 'uses the record itself as the Rails persistence adapter' do
    expect(RubyLLM.config.batch_store).to eq(RubyLLM::ActiveRecord::Batch)
    expect(RubyLLM::ActiveRecord.const_defined?(:BatchStore, false)).to be(false)
  end

  # rubocop:disable-next RSpec/AnyInstance
  def stub_anthropic_batch(create:, find:, results:)
    allow_any_instance_of(RubyLLM::Providers::Anthropic).to receive(:create_batch).and_return(create)
    allow_any_instance_of(RubyLLM::Providers::Anthropic).to receive(:find_batch).and_return(find)
    allow_any_instance_of(RubyLLM::Providers::Anthropic).to receive(:batch_results).and_return(results)
  end

  def answer(content)
    RubyLLM::Message.new(role: :assistant, content: content, input_tokens: 5, output_tokens: 1, model: model)
  end

  it 'submits, persists the batch and its chats, and routes answers home' do
    chats = [
      Chat.create!(model: model).ask_later('What is 2 + 2? Just the number.'),
      Chat.create!(model: model).ask_later('Name the largest planet. One word.')
    ]
    stub_anthropic_batch(
      create: { id: 'msgbatch_1', raw_status: 'in_progress', completed: false },
      find: { id: 'msgbatch_1', raw_status: 'ended', completed: true },
      results: [[0, answer('4')], [1, answer('Jupiter')]]
    )

    batch = RubyLLM.batch(chats)

    expect(batch.id).to eq('msgbatch_1')
    record = RubyLLM::ActiveRecord::Batch.find_by!(provider_batch_id: batch.id)
    expect(record.provider).to eq('anthropic')
    expect(record.chat_ids).to eq(chats.map(&:id))
    expect(record.chats).to eq(chats)

    # Poll from a fresh record, the way a job in another process would.
    polled = described_class.find(batch.id).refresh
    expect(polled).to be_complete
    expect(polled.status).to eq(:succeeded)
    expect(polled.raw_status).to eq('ended')

    polled.messages

    expect(chats.first.messages.reload.pluck(:role)).to eq(%w[user assistant])
    expect(chats.first.messages.last.content).to eq('4')
    expect(chats.first.messages.last.tokens.input).to eq(5)
    expect(chats.second.messages.reload.last.content).to eq('Jupiter')
  end

  it 'is idempotent: re-collecting never appends an answer twice' do
    chat = Chat.create!(model: model).ask_later('What is 2 + 2?')
    stub_anthropic_batch(
      create: { id: 'msgbatch_2', raw_status: 'in_progress', completed: false },
      find: { id: 'msgbatch_2', raw_status: 'ended', completed: true },
      results: [[0, answer('4')]]
    )
    batch = RubyLLM.batch([chat])

    described_class.find(batch.id).refresh.messages # first poll
    described_class.find(batch.id).messages # retry: a fresh record re-collects

    expect(chat.messages.reload.where(role: 'assistant').count).to eq(1)
  end

  it 'keeps answers aligned when a chat was deleted before collection' do
    chats = [
      Chat.create!(model: model).ask_later('First question.'),
      Chat.create!(model: model).ask_later('Second question.')
    ]
    stub_anthropic_batch(
      create: { id: 'msgbatch_3', raw_status: 'in_progress', completed: false },
      find: { id: 'msgbatch_3', raw_status: 'ended', completed: true },
      results: [[0, answer('first')], [1, answer('second')]]
    )
    batch = RubyLLM.batch(chats)

    chats.first.destroy! # gone by the time the job polls

    described_class.find(batch.id).messages

    # The survivor gets its own answer, not the deleted chat's.
    expect(chats.second.messages.reload.last.content).to eq('second')
  end
end
