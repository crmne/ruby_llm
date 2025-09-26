# frozen_string_literal: true

require 'spec_helper'

class DummyProvider
  include RubyLLM::Providers::Anthropic::Cache

  attr_reader :cache_prompts

  def render_payload(cache_prompts:)
    @cache_prompts = cache_prompts
  end
end

RSpec.describe RubyLLM::Chat, '.complete with prompt caching' do
  include_context 'with configured RubyLLM'

  class DescribeRubyDev < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description MASSIVE_TEXT_FOR_PROMPT_CACHING

    def execute
      'Ruby is a great language for building web applications.'
    end
  end

  context 'with cache setting' do
    it 'caches by default' do
      chat = RubyLLM.chat
      expect(chat.instance_variable_get(:@cache_prompts)).to be_truthy
    end

    it 'honors setting' do
      RubyLLM.configure do |config|
        config.cache_prompts = false
      end

      chat = RubyLLM.chat
      expect(chat.instance_variable_get(:@cache_prompts)).to be_falsey
    end
  end

  context 'with cache specification' do
    it 'supports true' do
      provider = DummyProvider.new
      provider.render_payload(cache_prompts: true)
      expect(provider).to be_should_cache(:system)
      expect(provider).to be_should_cache(:user)
      expect(provider).to be_should_cache(:tools)
    end

    it 'supports false' do
      provider = DummyProvider.new
      provider.render_payload(cache_prompts: false)
      expect(provider).not_to be_should_cache(:system)
      expect(provider).not_to be_should_cache(:user)
      expect(provider).not_to be_should_cache(:tools)
    end

    it 'supports array' do
      provider = DummyProvider.new
      provider.render_payload(cache_prompts: %i[system tools])
      expect(provider).to be_should_cache(:system)
      expect(provider).not_to be_should_cache(:user)
      expect(provider).to be_should_cache(:tools)
    end

    it 'supports symbol' do
      provider = DummyProvider.new
      provider.render_payload(cache_prompts: :tools)
      expect(provider).not_to be_should_cache(:system)
      expect(provider).not_to be_should_cache(:user)
      expect(provider).to be_should_cache(:tools)
    end
  end

  CACHING_MODELS.each do |model_info|
    provider = model_info[:provider]
    model = model_info[:model]

    describe "with #{provider} provider (#{model})" do
      let(:chat) { RubyLLM.chat(model: model, provider: provider, cache: false).with_temperature(0.7) }

      context 'with system message caching' do
        it 'adds cache_control to the last system message when system caching is requested' do
          chat.with_instructions(MASSIVE_TEXT_FOR_PROMPT_CACHING)

          response = chat.ask('What are the key principles you follow?', cache: :system)

          expect(response.cache_creation_tokens).to be_positive

          response = chat.ask('What are the key principles you follow?', cache: :system)

          expect(response.cached_tokens).to be_positive
        end
      end

      context 'with user message caching' do
        it 'adds cache_control to user messages when user caching is requested' do
          response = chat.ask(
            "#{MASSIVE_TEXT_FOR_PROMPT_CACHING}\n\nBased on the above, tell me about Ruby",
            cache: :user
          )

          expect(response.cache_creation_tokens).to be_positive

          response = chat.ask('Tell me more about Ruby', cache: :user)

          expect(response.cached_tokens).to be_positive
        end
      end

      context 'with tool definition caching' do
        it 'adds cache_control to tool definitions when tools caching is requested' do
          chat.with_tools(DescribeRubyDev)

          response = chat.ask('Tell me about Ruby', cache: :tools)

          expect(chat.messages[1].cache_creation_tokens).to be_positive
          expect(response.cached_tokens).to be_positive
        end
      end

      context 'with multiple caching types' do
        it 'handles multiple caching types together' do
          chat.with_tools(DescribeRubyDev)
          chat.with_instructions(MASSIVE_TEXT_FOR_PROMPT_CACHING)

          response = chat.ask(
            "#{MASSIVE_TEXT_FOR_PROMPT_CACHING}\n\nBased on the above, tell me about Ruby",
            cache: %i[system tools user]
          )

          expect(chat.messages[2].cache_creation_tokens).to be_positive
          expect(response.cached_tokens).to be_positive
        end
      end

      context 'with streaming' do
        it 'reports cached tokens' do
          response = chat.ask("#{MASSIVE_TEXT_FOR_PROMPT_CACHING}\n\nCount from 1 to 3", cache: :user) do |chunk|
            # do nothing
          end

          expect(response.cache_creation_tokens).to be_positive

          response = chat.ask("#{MASSIVE_TEXT_FOR_PROMPT_CACHING}\n\nCount from 1 to 3", cache: :user) do |chunk|
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
        question = "#{MASSIVE_TEXT_FOR_PROMPT_CACHE_REPORTING}\n\nBased on the above, tell me about Ruby"
        response_first = chat_first.ask question
        response_second = chat_second.ask question

        expect(response_first.cached_tokens).to be_zero
        expect(response_second.cached_tokens).to be_positive
      end
    end
  end
end
