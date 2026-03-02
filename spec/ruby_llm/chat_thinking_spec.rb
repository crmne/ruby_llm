# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

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
      when :ollama
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

    THINKING_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]

      it "#{provider}/#{model} returns thinking when available" do
        chat = chat_with_thinking(model: model, provider: provider)

        response = chat.ask(question)

        expect(response.content).to be_present
        if provider == :openai
          expect(response.thinking_tokens).to be_present
        elsif provider == :perplexity && response.thinking.nil?
          expect(response.content).to be_present
        else
          expect(response.thinking).to be_present
        end
      end

      it "#{provider}/#{model} streams thinking content when available" do
        chat = chat_with_thinking(model: model, provider: provider)

        chunks = []
        response = chat.ask(question) do |chunk|
          chunks << chunk
        end

        expect(response.content).to be_present
        expect(chunks).not_to be_empty
        expect(chunks.any?(&:thinking)).to be true if response.thinking && provider != :perplexity
      end

      it "#{provider}/#{model} preserves thinking signatures between turns when provided" do
        chat = chat_with_thinking(model: model, provider: provider)

        first = chat.ask('What is 5 + 3?')
        signature = first.thinking&.signature

        second = chat.ask('Now multiply that by 2')
        expect(second.content).to be_present

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
end
