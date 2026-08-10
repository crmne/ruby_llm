# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, :live do
  describe '#with_thinking' do
    it 'clears thinking when both options are nil' do
      chat = RubyLLM.chat.with_thinking(effort: :low)

      chat.with_thinking(effort: nil)

      expect(chat.instance_variable_get(:@thinking)).to be_nil
    end

    it 'renders the display option inside the Anthropic thinking config' do
      payload = RubyLLM.chat(model: 'claude-sonnet-5', provider: :anthropic)
                       .with_thinking(effort: :high, display: :summarized)
                       .render

      expect(payload[:thinking]).to eq({ type: 'adaptive', display: 'summarized' })
      expect(payload.dig(:output_config, :effort)).to eq('high')
    end

    it 'renders display alone as adaptive thinking with the default effort' do
      payload = RubyLLM.chat(model: 'claude-sonnet-5', provider: :anthropic)
                       .with_thinking(display: :summarized)
                       .render

      expect(payload[:thinking]).to eq({ type: 'adaptive', display: 'summarized' })
      expect(payload[:output_config]).to be_nil
    end

    it 'passes provider-specific effort tiers through untouched' do
      payload = RubyLLM.chat(model: 'gpt-5.2', provider: :openai)
                       .with_thinking(effort: :xhigh)
                       .render

      expect(payload.dig(:reasoning, :effort)).to eq('xhigh')
    end
  end

  describe 'thinking display' do
    context 'with anthropic/claude-sonnet-5' do
      it 'returns readable thinking with display summarized' do
        chat = RubyLLM.chat(model: 'claude-sonnet-5', provider: :anthropic)
                      .with_thinking(display: :summarized)

        response = chat.ask(
          'A farmer has chickens and rabbits, 35 heads and 94 legs. How many of each? Reason step by step.'
        )

        expect(response.content).to include('23').and include('12')
        expect(response.thinking&.signature).to be_present
      end
    end
  end

  context 'with extended thinking' do
    question = <<~QUESTION.strip
      If a magic mirror shows your future self, but only if you ask a question it cannot answer truthfully, what question do you ask to see your future, and what would the mirror reveal about the answer it gives?
    QUESTION

    def thinking_config_for(provider)
      case provider
      when :anthropic, :bedrock
        { budget: 1024 }
      when :gemini
        { effort: :low }
      when :gpustack, :ollama
        nil
      else
        { effort: :medium }
      end
    end

    def chat_with_thinking(model:, provider:)
      chat = RubyLLM.chat(model: model, provider: provider)
      config = thinking_config_for(provider)
      config ? chat.with_thinking(**config) : chat
    end

    def expect_response_payload(response)
      expect(response.content.presence || response.thinking&.text).to be_present
    end

    each_model(THINKING_MODELS) do |provider, model|
      it "#{provider}/#{model} returns thinking when available" do
        chat = chat_with_thinking(model: model, provider: provider)
        prompt = provider == :gpustack ? 'What is 5 + 3? Think briefly before answering.' : question

        response = chat.ask(prompt)

        expect_response_payload(response)
        if provider.in?(%i[openai azure])
          expect(response.tokens.thinking).to be_present
        elsif provider == :perplexity && response.thinking.nil?
          expect(response.content).to be_present
        else
          expect(response.thinking).to be_present
        end
      end

      it "#{provider}/#{model} streams thinking content when available" do
        chat = chat_with_thinking(model: model, provider: provider)
        prompt = provider == :gpustack ? 'What is 5 + 3? Think briefly before answering.' : question

        chunks = []
        response = chat.ask(prompt) do |chunk|
          chunks << chunk
        end

        expect_response_payload(response)
        expect(chunks).not_to be_empty
        expect(chunks.any?(&:thinking)).to be true if response.thinking && provider != :perplexity
      end

      it "#{provider}/#{model} preserves thinking signatures between turns when provided" do
        chat = chat_with_thinking(model: model, provider: provider)

        first = chat.ask('What is 5 + 3?')
        signature = first.thinking&.signature

        second = chat.ask('Now multiply that by 2')
        expect_response_payload(second)

        if signature
          expect(second.thinking&.signature).to be_present

          if %i[anthropic bedrock gemini vertexai].include?(provider)
            stored_signatures = chat.messages.filter_map { |msg| msg.thinking&.signature }
            expect(stored_signatures).to include(signature)
          end
        end
      end
    end
  end

  describe 'Mistral hybrid reasoning' do
    let(:chat) { RubyLLM.chat(model: 'mistral-small-latest', provider: :mistral).with_thinking(effort: :high) }

    it 'separates thinking from final content' do
      response = chat.ask('What is 12 * 12? Answer with just the number.')

      expect(response.thinking&.text).to be_present
      expect(response.content).to be_present
      expect(response.content).not_to include(response.thinking.text)
    end

    it 'replays thinking chunks across turns' do
      chat.ask('What is 12 * 12? Answer with just the number.')

      response = chat.ask('Now add 10 to that. Answer with just the number.')

      expect(response.content).to be_present
      expect(response.thinking&.text).to be_present
    end

    it 'streams thinking separately from content' do
      thinking_parts = []
      content_parts = []

      response = chat.ask('What is 12 * 12? Answer with just the number.') do |chunk|
        thinking_parts << chunk.thinking.text if chunk.thinking&.text
        content_parts << chunk.content if chunk.content.present?
      end

      expect(thinking_parts.join).to eq(response.thinking&.text)
      expect(content_parts.join).to eq(response.content)
      expect(response.content).to be_present
    end
  end

  describe 'DeepSeek thinking control' do
    it 'disables thinking for effort none' do
      chat = RubyLLM.chat(model: 'deepseek-v4-flash', provider: :deepseek).with_thinking(effort: :none)

      response = chat.ask('What is 2 + 2? Answer with just the number.')

      expect(response.content).to be_present
      expect(response.thinking).to be_nil
    end

    it 'returns reasoning content for effort high' do
      chat = RubyLLM.chat(model: 'deepseek-v4-flash', provider: :deepseek).with_thinking(effort: :high)

      response = chat.ask('What is 2 + 2? Answer with just the number.')

      expect(response.content).to be_present
      expect(response.thinking&.text).to be_present
    end
  end

  describe 'Gemini token accounting' do
    it 'correctly sums candidatesTokenCount and thoughtsTokenCount' do
      chat = RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini)
      response = chat.ask('What is 2+2? Think step by step.')

      raw_body = response.raw.body
      candidates_tokens = raw_body.dig('usageMetadata', 'candidatesTokenCount') || 0
      thoughts_tokens = raw_body.dig('usageMetadata', 'thoughtsTokenCount') || 0

      expect(response.tokens.output).to eq(candidates_tokens + thoughts_tokens)
    end
  end
end
