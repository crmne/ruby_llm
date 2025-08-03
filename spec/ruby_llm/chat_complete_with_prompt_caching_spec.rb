# frozen_string_literal: true

require 'spec_helper'

LARGE_PROMPT = 'a' * (2048 * 4)

RSpec.describe RubyLLM::Chat, '.complete with prompt caching' do
  include_context 'with configured RubyLLM'

  class DescribeRubyDev < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description LARGE_PROMPT

    def execute
      'Ruby is a great language for building web applications.'
    end
  end

  CACHING_MODELS.each do |model_info|
    provider = model_info[:provider]
    model = model_info[:model]

    describe "with #{provider} provider (#{model})" do
      let(:chat) { RubyLLM.chat(model: model, provider: provider).with_temperature(0.7) }

      context 'with system message caching' do
        it 'adds cache_control to the last system message when system caching is requested' do
          chat.with_instructions(LARGE_PROMPT)
          chat.cache_prompts(system: true)

          response = chat.ask('What are the key principles you follow?')

          expect(response.cache_creation_tokens).to be_positive

          response = chat.ask('What are the key principles you follow?')

          expect(response.cached_tokens).to be_positive
        end
      end

      context 'with user message caching' do
        it 'adds cache_control to user messages when user caching is requested' do
          chat.cache_prompts(user: true)
          response = chat.ask("#{LARGE_PROMPT}\n\nBased on the above, tell me about Ruby")

          expect(response.cache_creation_tokens).to be_positive

          response = chat.ask('Tell me more about Ruby')

          expect(response.cached_tokens).to be_positive
        end
      end

      context 'with tool definition caching' do
        it 'adds cache_control to tool definitions when tools caching is requested' do
          chat.with_tools(DescribeRubyDev)
          chat.cache_prompts(tools: true)

          response = chat.ask('Tell me about Ruby')

          expect(chat.messages[1].cache_creation_tokens).to be_positive
          expect(response.cached_tokens).to be_positive
        end
      end

      context 'with multiple caching types' do
        it 'handles multiple caching types together' do
          chat.with_tools(DescribeRubyDev)
          chat.with_instructions(LARGE_PROMPT)
          chat.cache_prompts(system: true, tools: true, user: true)

          response = chat.ask("#{LARGE_PROMPT}\n\nBased on the above, tell me about Ruby")

          expect(chat.messages[2].cache_creation_tokens).to be_positive
          expect(response.cached_tokens).to be_positive
        end
      end

      context 'with streaming' do
        it 'reports cached tokens' do
          chat.cache_prompts(user: true)
          response = chat.ask("#{LARGE_PROMPT}\n\nCount from 1 to 3") do |chunk|
            # do nothing
          end

          expect(response.cache_creation_tokens).to be_positive

          response = chat.ask("#{LARGE_PROMPT}\n\nCount from 1 to 3") do |chunk|
            # do nothing
          end

          expect(response.cached_tokens).to be_positive
        end
      end
    end
  end

  CACHED_MODELS.each do |model_info|
    provider = model_info[:provider]
    model = model_info[:model]

    describe "with #{provider} provider (#{model})" do
      let(:chat_first) { RubyLLM.chat(model: model, provider: provider).with_temperature(0.7) }
      let(:chat_second) { RubyLLM.chat(model: model, provider: provider).with_temperature(0.7) }

      it 'reports cached tokens' do
        large_prompt = LARGE_PROMPT * 2

        # Not sure why, but Gemini seems to only report cached tokens when the prompt is sufficiently complex
        large_prompt += ('b' * 1024) if provider == :gemini

        response_first = chat_first.ask("#{large_prompt}\n\nBased on the above, tell me about Ruby")

        response_second = chat_second.ask("#{large_prompt}\n\nBased on the above, tell me about Ruby")

        expect(response_first.cached_tokens).to be_zero
        expect(response_second.cached_tokens).to be_positive
      end
    end
  end
end
