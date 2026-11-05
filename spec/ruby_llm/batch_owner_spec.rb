# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Batch do
  include_context 'with configured RubyLLM'

  def answer
    RubyLLM::Message.new(role: :assistant, content: 'Hello', input_tokens: 1, output_tokens: 1)
  end

  it 'attributes each answer to the owner of its chat, and runs its callbacks under that owner' do
    seen = []
    chats = %i[alice bob].map do |owner|
      RubyLLM.chat(model: model_for(:anthropic)).with_owner(owner).ask_later('Hi')
             .after_message { seen << RubyLLM::Accounting::Usage.owner }
    end
    allow(chats.first.provider).to receive(:batch_results).and_return([[0, answer], [1, answer]])
    batch = described_class.new(provider: chats.first.provider, chats:, id: 'msgbatch_test',
                                raw_status: 'ended', completed: true)

    RubyLLM.with_owner(:poller) { batch.messages }

    expect(chats.map { |chat| chat.usage_entries.sole.owner }).to eq(%i[alice bob])
    expect(seen).to eq(%i[alice bob])
  end
end
