# frozen_string_literal: true

require 'spec_helper'

LARGE_PROMPT = File.read(File.join(__dir__, '../../../fixtures/large_prompt.txt'))

RSpec.describe RubyLLM::Providers::Anthropic::Chat, '.complete with prompt caching' do
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

          expect(response).to be_a(RubyLLM::Message)
        end
      end

      context 'with user message caching' do
        it 'adds cache_control to user messages when user caching is requested' do
          chat.cache_prompts(user: true)
          response = chat.ask("#{LARGE_PROMPT}\n\nBased on the above, tell me about Ruby")

          expect(response).to be_a(RubyLLM::Message)
        end
      end

      context 'with tool definition caching' do
        it 'adds cache_control to tool definitions when tools caching is requested' do
          chat.with_tools(DescribeRubyDev)
          chat.cache_prompts(tools: true)

          response = chat.ask('Tell me about Ruby')

          expect(response).to be_a(RubyLLM::Message)
        end
      end

      context 'with multiple caching types' do
        it 'handles multiple caching types together' do
          chat.with_tools(DescribeRubyDev)
          chat.with_instructions(LARGE_PROMPT)
          chat.cache_prompts(system: true, tools: true, user: true)

          response = chat.ask("#{LARGE_PROMPT}\n\nBased on the above, tell me about Ruby")

          expect(response).to be_a(RubyLLM::Message)
        end
      end
    end
  end
end
