# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Batch do
  include_context 'with configured RubyLLM'

  let(:model) { 'claude-haiku-4-5' }

  def wait_for(batch)
    40.times do
      break if batch.complete?

      sleep 15 if VCR.current_cassette.recording?
    end
    batch
  end

  describe '.submit' do
    it 'rejects an empty batch' do
      expect { RubyLLM.batch([]) }.to raise_error(ArgumentError, /empty batch/)
    end

    it 'rejects chats that are not awaiting the model' do
      expect { RubyLLM.batch([RubyLLM.chat(model: model)]) }
        .to raise_error(ArgumentError, /awaiting the model/)
    end

    it 'rejects mixed providers' do
      chats = [
        RubyLLM.chat(model: model).ask_later('Hi'),
        RubyLLM.chat(model: 'gpt-5-nano').ask_later('Hi')
      ]

      expect { RubyLLM.batch(chats) }.to raise_error(ArgumentError, /one provider/)
    end

    it 'rejects providers without batch support' do
      chats = [RubyLLM.chat(model: 'gemini-2.5-flash').ask_later('Hi')]

      expect { RubyLLM.batch(chats) }.to raise_error(RubyLLM::Error, /batch/)
    end
  end

  describe '.submit with a single chat' do
    it 'wraps it without decomposing the conversation' do
      chat = RubyLLM.chat(model: model).ask_later('Hi')
      allow(chat.provider).to receive(:create_batch)
        .and_return(id: 'msgbatch_test', status: 'in_progress', completed: false)

      batch = RubyLLM.batch(chat)

      expect(batch.chats).to eq([chat])
    end
  end

  describe '.find' do
    it 'requires a provider' do
      expect { RubyLLM.batch('msgbatch_123') }.to raise_error(ArgumentError, /Provider/)
    end
  end

  describe '#messages' do
    it 'leaves failed slots nil and their chats awaiting a response' do
      chats = [
        RubyLLM.chat(model: model).ask_later('This one fails'),
        RubyLLM.chat(model: model).ask_later('This one succeeds')
      ]
      provider = chats.first.provider
      message = RubyLLM::Message.new(role: :assistant, content: '4', input_tokens: 1, output_tokens: 1)
      allow(provider).to receive(:batch_results).and_return([[1, message]])

      batch = described_class.new(provider:, chats:, id: 'msgbatch_test', status: 'ended', completed: true)

      expect(batch.messages).to eq([nil, message])
      expect(chats.first).not_to be_complete
      expect(chats.second.messages.last).to be(message)

      batch.messages
      expect(provider).to have_received(:batch_results).once
    end
  end

  context 'with anthropic/claude-haiku-4-5' do
    it 'answers staged chats and appends the answers to their conversations' do
      chats = [
        RubyLLM.chat(model: model).with_instructions('Be terse.').ask_later('What is 2 + 2?'),
        RubyLLM.chat(model: model).ask_later('Name the largest planet in our solar system. One word.')
      ]

      batch = RubyLLM.batch(chats)

      expect(batch.id).to start_with('msgbatch_')
      expect(batch.status).to eq('in_progress')

      wait_for batch

      expect(batch).to be_complete
      expect(batch.messages.first.content).to include('4')
      expect(batch.messages.second.content).to match(/jupiter/i)
      expect(batch.messages.first.input_tokens).to be_positive
      expect(chats.first.messages.map(&:role)).to eq(%i[system user assistant])
    end

    it 'reloads a batch by id and collects messages without the chats' do
      submitted = RubyLLM.batch([RubyLLM.chat(model: model).ask_later('What is 3 + 3? Just the number.')])
      wait_for submitted

      batch = RubyLLM.batch(submitted.id, provider: :anthropic)

      expect(batch).to be_complete
      expect(batch.messages.first.content).to include('6')
    end

    it 'cancels a running batch' do
      batch = RubyLLM.batch([RubyLLM.chat(model: model).ask_later('What is 5 + 5?')])

      batch.cancel

      expect(batch.status).to be_in(%w[canceling ended])
    end
  end
end
