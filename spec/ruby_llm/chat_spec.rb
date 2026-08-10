# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
  def total_input_tokens(message)
    message.tokens.input.to_i + message.tokens.cache_read.to_i + message.tokens.cache_write.to_i
  end

  def expect_token_usage(message)
    expect(total_input_tokens(message)).to be_positive
    expect(message.tokens.output).to be_positive
  end

  describe 'basic chat functionality' do
    each_model(CHAT_MODELS) do |provider, model|
      it "#{provider}/#{model} can have a basic conversation" do
        chat = basic_chat(model: model, provider: provider)
        response = chat.ask("What's 2 + 2?")

        expect(response.content).to include('4')
        expect(response.role).to eq(:assistant)
        expect_token_usage(response)
      end

      it "#{provider}/#{model} returns raw responses" do
        chat = RubyLLM.chat(model: model, provider: provider)
        response = chat.ask('What is the capital of France?')
        expect(response.raw).to be_present
        expect(response.raw.headers).to be_present
        expect(response.raw.body).to be_present
        expect(response.raw.status).to be_present
        expect(response.raw.status).to eq(200)
        expect(response.raw.env.request_body).to be_present
      end

      it "#{provider}/#{model} can handle multi-turn conversations" do
        chat = basic_chat(model: model, provider: provider)

        first = chat.ask('Who is the creator of the programming language Ruby?')
        expect(first.content).to include('Matz')

        followup = chat.ask('What year did he create Ruby?')
        expect(followup.content).to include('199')
      end

      it "#{provider}/#{model} successfully uses the system prompt" do
        chat = RubyLLM.chat(model: model, provider: provider).with_temperature(0.0)

        # Use a distinctive and unusual instruction that wouldn't happen naturally
        chat.with_instructions 'You must include the exact phrase "XKCD7392" somewhere in your response.'

        response = chat.ask('Tell me about the weather.')
        expect(response.content).to match(/XKCD7392/i)
      end

      it "#{provider}/#{model} replaces previous system messages by default" do
        if %i[perplexity mistral].include?(provider)
          skip 'Provider API does not allow system messages after user/assistant messages'
        end
        skip 'xAI may retain prior instruction artifacts from conversation history' if provider == :xai

        if provider == :ollama && model == 'qwen3'
          skip 'ollama/qwen3 includes thinking tags even with enable_thinking: false'
        end

        chat = basic_chat(model: model, provider: provider, temperature: 0.0)

        # Use a distinctive and unusual instruction that wouldn't happen naturally
        chat.with_instructions 'You must include the exact phrase "XKCD7392" somewhere in your response.'

        response = chat.ask('Tell me about the weather.')
        expect(response.content).to match(/XKCD7392/i)

        # Test ability to follow multiple instructions with another unique marker
        chat.with_instructions 'You must include the exact phrase "PURPLE-ELEPHANT-42" somewhere in your response.'

        response = chat.ask('What are some good books?')
        expect(response.content).not_to match(/XKCD7392/i)
        expect(response.content).to match(/PURPLE-ELEPHANT-42/i)
      end
    end
  end

  describe 'change model on the fly' do
    CHAT_MODELS.first(3).combination(2).each do |first, second|
      next if [first[:provider], second[:provider]] == %i[azure bedrock]

      it "between #{first[:provider]}/#{first[:model]} and #{second[:provider]}/#{second[:model]}" do
        chat = RubyLLM.chat(model: first[:model], provider: first[:provider]).with_temperature(0.0)
        response = chat.ask('Reply with exactly: FOUR')

        expect(response.content).to match(/four/i)
        expect(response.role).to eq(:assistant)
        expect_token_usage(response)

        chat.with_model(second[:model], provider: second[:provider])
        response = chat.ask('Reply with exactly: EIGHT')

        expect(response.content).to match(/eight/i)
        expect(response.role).to eq(:assistant)
        expect_token_usage(response)
      end
    end
  end

  describe '#tokens and #cost' do
    let(:model) do
      RubyLLM::Model.new(
        id: 'priced-model',
        name: 'Priced Model',
        provider: 'openai',
        pricing: {
          text_tokens: {
            standard: {
              input_per_million: 1.0,
              output_per_million: 2.0
            }
          }
        }
      )
    end

    it 'keeps manually added messages out of the conversation totals' do
      allow(RubyLLM.models).to receive(:find).and_call_original
      allow(RubyLLM.models).to receive(:find).with('priced-model').and_return(model)

      chat = RubyLLM.chat(model: RubyLLM.config.default_model)
      chat.add_message(role: :user, content: 'Hello')
      response = chat.add_message(role: :assistant, content: 'Hi', input_tokens: 1_000, output_tokens: 2_000,
                                  model: 'priced-model')

      expect(response.tokens.to_h).to eq(input_tokens: 1_000, output_tokens: 2_000)
      expect(response.cost.total).to eq(0.005)
      expect(chat.tokens.to_h).to be_empty
      expect(chat.cost.total).to be_nil
    end

    it 'returns empty value objects before the chat has usage' do
      chat = RubyLLM.chat(model: RubyLLM.config.default_model)

      expect(chat.tokens).to be_a(RubyLLM::Tokens)
      expect(chat.tokens.to_h).to be_empty
      expect(chat.cost).to be_a(RubyLLM::Cost)
      expect(chat.cost.total).to be_nil
    end

    it 'prices a response against a given model when its own model id cannot be resolved' do
      allow(RubyLLM.models).to receive(:find).and_call_original
      allow(RubyLLM.models).to receive(:find).with('priced-model', nil).and_return(model)
      allow(RubyLLM.models).to receive(:find).with('provider-backend-version').and_raise(RubyLLM::ModelNotFoundError)

      chat = RubyLLM.chat(model: 'priced-model')
      response = chat.add_message(role: :assistant, content: 'Hi', input_tokens: 1_000, output_tokens: 2_000,
                                  model: 'provider-backend-version')

      expect(response.cost(model: chat.model).total).to eq(0.005)
    end
  end

  describe '#tool_results' do
    it 'links added messages so a call resolves its result messages' do
      chat = RubyLLM.chat(model: RubyLLM.config.default_model)
      call = chat.add_message(
        role: :assistant,
        content: '',
        tool_calls: { 'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: {}) }
      )
      result = chat.add_message(role: :tool, content: 'sunny', tool_call_id: 'call_1')

      expect(call.tool_results).to eq([result])
    end
  end
end
