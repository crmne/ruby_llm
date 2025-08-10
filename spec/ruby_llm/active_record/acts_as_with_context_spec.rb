# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::ActiveRecord::ActsAs do
  let(:model) { 'gpt-4.1-nano' }

  describe 'when global configuration is missing' do
    around do |example|
      # Save current config
      original_config = RubyLLM.instance_variable_get(:@config)

      # Reset configuration to simulate missing global config
      RubyLLM.instance_variable_set(:@config, RubyLLM::Configuration.new)

      example.run

      # Restore original config
      RubyLLM.instance_variable_set(:@config, original_config)
    end

    it 'works when using chat with a custom context' do
      chat = Chat.create!(model_id: model)

      # Create a custom context with API key
      context = RubyLLM.context do |config|
        config.openai_api_key = 'sk-test-key'
      end

      expect do
        chat.with_context(context)
      end.not_to raise_error

      # The chat should be properly configured with the context
      llm_chat = chat.instance_variable_get(:@chat)
      expect(llm_chat).to be_a(RubyLLM::Chat)
      expect(llm_chat.instance_variable_get(:@context)).to eq(context)
    end

    it 'would have failed before the fix when calling to_llm then with_context' do
      # This test demonstrates that the issue has been fixed
      # Previously, calling to_llm first would create a chat without context
      # and fail if no global config was present

      chat = Chat.create!(model_id: model)
      context = RubyLLM.context do |config|
        config.openai_api_key = 'sk-test-key'
      end

      # This now works because to_llm accepts a context parameter
      expect { chat.with_context(context) }.not_to raise_error
    end
  end

  describe 'with global configuration present' do
    include_context 'with configured RubyLLM'

    it 'works with custom context even when global config exists' do
      chat = Chat.create!(model_id: model)

      # Create a different API key in custom context
      custom_context = RubyLLM.context do |config|
        config.openai_api_key = 'sk-different-key'
      end

      chat.with_context(custom_context)

      llm_chat = chat.instance_variable_get(:@chat)
      expect(llm_chat.instance_variable_get(:@context)).to eq(custom_context)
      expect(llm_chat.instance_variable_get(:@config).openai_api_key).to eq('sk-different-key')
    end
  end
end
