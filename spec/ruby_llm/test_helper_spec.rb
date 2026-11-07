# frozen_string_literal: true

require 'rails_helper'
require 'ruby_llm/test_helper'

RSpec.describe RubyLLM::TestHelper do
  include described_class

  around do |example|
    keys = RubyLLM.config.anthropic_api_key
    RubyLLM.config.anthropic_api_key = nil
    example.run
  ensure
    RubyLLM.config.anthropic_api_key = keys
  end

  def chat
    @chat ||= RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic)
  end

  it 'answers from the script, with no provider and no key' do
    stub_replies 'Hello there'

    expect(chat.ask('Hi').content).to eq('Hello there')
  end

  %i[azure bedrock].each do |provider|
    it "answers on #{provider}, which checks its own credentials" do
      stub_replies 'Hello'
      chat = RubyLLM.chat(model: model_for(provider), provider:, assume_model_exists: true)

      expect(chat.ask('Hi').content).to eq('Hello')
    end
  end

  it 'leaves other operations their connection' do
    stub_replies 'Hello'

    expect(RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic).provider.connection).not_to be_nil
  end

  it 'streams word by word' do
    stub_replies 'Hello there friend'
    chunks = []

    chat.ask('Hi') { |chunk| chunks << chunk.content }

    expect(chunks).to eq(['Hello ', 'there ', 'friend'])
    expect(chat.messages.last.content).to eq('Hello there friend')
  end

  it 'reports the cost on the reply and in the chat' do
    stub_replies 'Hello', cost: 0.25

    expect(chat.ask('Hi').cost.total).to eq(0.25)
    expect(chat.cost.total).to eq(0.25)
  end

  it 'answers in order and repeats the last reply' do
    stub_replies 'One', 'Two'

    expect(Array.new(3) { chat.ask('Hi').content }).to eq(%w[One Two Two])
  end

  it 'lets a stream be cancelled, keeping what it showed' do
    stub_replies 'one two three four five six seven eight', interval: 0.05
    seen = Queue.new
    Thread.new do
      seen.pop
      chat.cancel
    end

    expect { chat.ask('Hi') { |chunk| seen << true if chunk.content } }.to raise_error(RubyLLM::CancelledError)

    reply = chat.messages.last
    expect(reply).to be_cancelled
    expect(reply.content).not_to include('eight')
  end

  it 'scripts a tool call that the loop runs' do
    weather = Class.new(RubyLLM::Tool) do
      description 'Looks up the weather'
      define_singleton_method(:tool_name) { 'weather' }
      parameter :city
      define_method(:execute) { |city:| "Sunny in #{city}" }
    end
    stub_replies tool_call(:weather, city: 'Berlin'), 'It is sunny.'

    reply = chat.with_tools(weather).ask('Weather?')

    expect(reply.content).to eq('It is sunny.')
    expect(chat.messages.find(&:tool_result?).content).to eq('Sunny in Berlin')
  end

  it 'fails a request with a scripted exception' do
    stub_replies RubyLLM::ServerError.new('The provider is down')

    expect { chat.ask('Hi') }.to raise_error(RubyLLM::ServerError, 'The provider is down')
  end

  it 'works on a persisted chat, across threads, and writes the ledger' do
    stub_replies 'Saved', cost: 0.5
    record = Chat.create!(model: model_for(:anthropic))

    Thread.new { record.ask('Hi') }.join

    expect(record.messages.last.content).to eq('Saved')
    expect(record.ruby_llm_usages.sum(:total_cost)).to eq(0.5)
  end

  it 'goes back to the real provider once cleared' do
    stub_replies 'Hello'
    RubyLLM::TestHelper::Script.clear

    expect { RubyLLM.chat(model: model_for(:anthropic), provider: :anthropic) }.to raise_error(RubyLLM::ConfigurationError)
  end

  it 'keeps the script through the rest of a Minitest teardown, such as a browser reset, then clears it' do
    active_during_reset = nil
    system_test = Class.new do
      define_method(:after_teardown) { active_during_reset = RubyLLM::TestHelper::Script.active? }
    end
    test = Class.new(system_test) { include RubyLLM::TestHelper }.new
    test.stub_replies 'Hello'

    test.after_teardown

    expect(active_during_reset).to be(true)
    expect(RubyLLM::TestHelper::Script).not_to be_active
  end

  it 'clears the script after each example through its RSpec hook' do
    expect(RubyLLM::TestHelper::Script).not_to be_active
  end
end
