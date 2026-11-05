# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  let(:chat) { described_class.new(model: model_for(:anthropic)) }
  let(:seen) { [] }

  def answer(content = 'Done')
    RubyLLM::Message.new(role: :assistant, content:, input_tokens: 1, output_tokens: 1)
  end

  def tool_call
    RubyLLM::Message.new(
      role: :assistant, content: '', input_tokens: 1, output_tokens: 1,
      tool_calls: { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'whoami', arguments: {}) }
    )
  end

  def whoami_tool(seen)
    Class.new(RubyLLM::Tool) do
      description 'Reports who pays'
      define_method(:name) { 'whoami' }
      define_method(:execute) do
        seen << [:tool, RubyLLM::Accounting::Usage.owner]
        'ok'
      end
    end
  end

  describe '#with_owner' do
    it 'sets the owner, returns the chat, and resets with nil' do
      expect(chat.owner).to be_nil
      expect(chat.with_owner(:alice)).to be(chat)
      expect(chat.owner).to eq(:alice)
      expect(chat.with_owner(nil).owner).to be_nil
    end

    it 'attributes every attempt of a turn, and the tools it runs, to the owner' do
      responses = [tool_call, answer]
      allow(chat.provider).to receive(:complete) do
        seen << [:request, RubyLLM::Accounting::Usage.owner]
        responses.shift
      end

      chat.with_owner(:alice).with_tools(whoami_tool(seen)).ask('Who pays?')

      expect(seen).to eq([%i[request alice], %i[tool alice], %i[request alice]])
      expect(chat.usage_entries.map(&:owner)).to eq(%i[alice alice])
      expect(RubyLLM::Accounting::Usage.owner).to be_nil
    end

    it 'attributes a step and a compaction to the owner' do
      allow(chat.provider).to receive(:complete) do
        seen << [:request, RubyLLM::Accounting::Usage.owner]
        answer
      end
      allow(chat.provider).to receive(:compact) do
        seen << [:compact, RubyLLM::Accounting::Usage.owner]
        answer('Compacted')
      end
      chat.with_owner(:alice).ask_later('Hello')

      chat.step
      chat.compact

      expect(seen).to eq([%i[request alice], %i[compact alice]])
    end

    it 'wins over RubyLLM.with_owner, which applies to a chat without one' do
      allow(chat.provider).to receive(:complete) do
        seen << RubyLLM::Accounting::Usage.owner
        answer
      end

      RubyLLM.with_owner(:account) do
        chat.ask('Hello')
        chat.with_owner(:alice).ask('Hello again')
      end

      expect(seen).to eq(%i[account alice])
    end

    it 'attributes the converters a render runs to the owner' do
      seen = []
      docx = File.expand_path('../fixtures/sample.docx', __dir__)
      type = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      converter = lambda do |_file|
        seen << RubyLLM::Accounting::Usage.owner
        'The codename is Bluebird.'
      end
      chat = RubyLLM.context { |config| config.file_converters = { type => converter } }
                    .chat(model: model_for(:anthropic), provider: :anthropic)
                    .with_file_store.with_owner(:alice)
      chat.add_message(role: :user, content: 'What is the codename?', attachments: [docx])

      chat.render

      expect(seen).to eq([:alice])
    end

    it 'keeps the owner on a copy' do
      expect(chat.with_owner(:alice).dup.owner).to eq(:alice)
    end
  end

  describe 'RubyLLM.with_usage_owner' do
    it 'still attributes usage, and is deprecated in favor of RubyLLM.with_owner' do
      allow(RubyLLM.deprecator).to receive(:deprecate)

      owner = RubyLLM.with_usage_owner(:alice) { RubyLLM::Accounting::Usage.owner }

      expect(owner).to eq(:alice)
      expect(RubyLLM.deprecator).to have_received(:deprecate)
        .with('RubyLLM.with_usage_owner', replacement: 'RubyLLM.with_owner', removal: '3.0')
    end
  end
end
