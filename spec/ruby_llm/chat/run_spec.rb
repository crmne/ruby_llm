# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat::Run do
  include_context 'with configured RubyLLM'

  let(:run) { described_class.new }

  it 'reports usage through the usage event' do
    allow(RubyLLM::Accounting::Usage).to receive(:record)
    entry = Object.new

    run.record_usage(entry)

    expect(RubyLLM::Accounting::Usage).to have_received(:record).with(entry)
  end

  it 'has nothing to consult on its own' do
    expect(run.record_progress(Object.new)).to be_nil
    expect(run).not_to be_cancellation_requested
    expect(run).not_to be_interrupted_by(StandardError.new)
  end

  it 'is shared by a copy of the chat' do
    chat = RubyLLM.chat(model: RubyLLM.config.default_model)
    chat.run = run

    expect(chat.dup.instance_variable_get(:@run)).to be(run)
  end
end
