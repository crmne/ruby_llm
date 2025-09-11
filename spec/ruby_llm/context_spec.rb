# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Context do
  include_context 'with configured RubyLLM'

  describe '#initialize' do
    it 'creates a copy of the global configuration' do
      # Get current config values
      original_model = RubyLLM.config.default_model
      original_api_key = RubyLLM.config.openai_api_key
      original_log_regexp_timeout = RubyLLM.config.log_regexp_timeout

      # Create context with modified config
      context = RubyLLM.context do |config|
        config.default_model = 'modified-model'
        config.openai_api_key = 'modified-key'
        config.log_regexp_timeout = 5.0
      end

      # Verify global config is unchanged
      expect(RubyLLM.config.default_model).to eq(original_model)
      expect(RubyLLM.config.openai_api_key).to eq(original_api_key)
      expect(RubyLLM.config.log_regexp_timeout).to eq(original_log_regexp_timeout)

      # Verify context has modified config
      expect(context.config.default_model).to eq('modified-model')
      expect(context.config.openai_api_key).to eq('modified-key')
      expect(context.config.log_regexp_timeout).to eq(5.0)
    end
  end

  describe 'context chat operations' do
    it 'creates a chat with context-specific configuration' do
      context = RubyLLM.context do |config|
        config.default_model = 'claude-3-5-haiku-20241022'
      end

      chat = context.chat
      expect(chat.model.id).to eq('claude-3-5-haiku-20241022')

      # Ensure global config wasn't affected
      global_chat = RubyLLM.chat
      expect(global_chat.model.id).to eq(RubyLLM.config.default_model)
    end

    it 'uses context-specific API keys' do
      original_openai_key = RubyLLM.config.openai_api_key

      context = RubyLLM.context do |config|
        config.openai_api_key = 'test-context-key'
      end

      expect do
        chat = context.chat(model: 'gpt-4.1-nano')
        chat.ask('Hello')
      end.to raise_error RubyLLM::UnauthorizedError

      # Global config should be unchanged
      expect(RubyLLM.config.openai_api_key).to eq(original_openai_key)
    end

    it 'allows specifying a model when creating the chat' do
      context = RubyLLM.context do |config|
        config.default_model = 'gpt-4.1-nano'
      end

      chat = context.chat(model: 'claude-3-5-haiku-20241022')
      expect(chat.model.id).to eq('claude-3-5-haiku-20241022')
    end
  end

  describe 'context embed operations' do
    it 'respects context-specific embedding model' do
      context = RubyLLM.context do |config|
        config.default_embedding_model = 'text-embedding-3-large'
      end

      embedding = context.embed('Test embedding')
      expect(embedding.model).to eq('text-embedding-3-large')

      # Global default should be unchanged
      global_embedding = RubyLLM.embed('Test embedding')
      expect(global_embedding.model).to eq(RubyLLM.config.default_embedding_model)
    end

    it 'allows specifying a model at embed time' do
      context = RubyLLM.context do |config|
        config.default_embedding_model = 'text-embedding-3-large'
      end

      embedding = context.embed('Test embedding', model: 'text-embedding-3-small')
      expect(embedding.model).to eq('text-embedding-3-small')
    end
  end

  describe 'multiple independent contexts' do
    it 'allows multiple contexts with different configurations' do
      context1 = RubyLLM.context do |config|
        config.default_model = 'gpt-4.1-nano'
        config.log_regexp_timeout = 5.0
      end

      context2 = RubyLLM.context do |config|
        config.default_model = 'claude-3-5-haiku-20241022'
      end

      chat1 = context1.chat
      chat2 = context2.chat

      expect(chat1.model.id).to eq('gpt-4.1-nano')
      expect(context1.config.log_regexp_timeout).not_to eq(Regexp.timeout)
      expect(context1.config.log_regexp_timeout).to eq(5.0)

      expect(chat2.model.id).to eq('claude-3-5-haiku-20241022')
      expect(context2.config.log_regexp_timeout).to eq(Regexp.timeout)
    end

    it 'ensures changes in one context do not affect another' do
      context1 = RubyLLM.context do |config|
        config.openai_api_key = 'key1'
        config.default_model = 'model1'
      end

      context2 = RubyLLM.context do |config|
        config.openai_api_key = 'key2'
        config.default_model = 'model2'
      end

      # Modify context1 after creation
      context1.config.openai_api_key = 'modified-key1'

      # Context2 should be unaffected
      expect(context2.config.openai_api_key).to eq('key2')
      expect(context2.config.default_model).to eq('model2')
    end
  end
end
