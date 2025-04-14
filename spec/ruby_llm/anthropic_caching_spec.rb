# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Anthropic Prompt Caching' do
  let(:model) { 'claude-3-5-sonnet-20240620' }

  it 'supports cache control in content' do
    content = RubyLLM::Content.new('Hello, world!', cache_control: true)
    expect(content.cache_control).to be true
  end

  it 'formats content with cache control for Anthropic' do
    content = RubyLLM::Content.new('Hello, world!', cache_control: true)
    formatted = RubyLLM::Providers::Anthropic::Media.format_content([{ type: 'text', text: 'Hello, world!' }], true)
    
    expect(formatted.first[:cache_control]).to eq({ type: 'ephemeral' })
  end

  it 'includes cache control in message formatting' do
    # Create a message with cache control
    content = RubyLLM::Content.new('Hello, world!', cache_control: true)
    message = RubyLLM::Message.new(role: :user, content: content)
    
    # Format the message using the Anthropic provider
    formatted = RubyLLM::Providers::Anthropic.send(:format_basic_message, message)
    
    # Check that the formatted message includes cache control
    expect(formatted[:content].first[:cache_control]).to eq({ type: 'ephemeral' })
  end

  it 'tracks cache-related token usage in messages' do
    # Create a message with cache-related token usage
    message = RubyLLM::Message.new(
      role: :assistant,
      content: 'Hello, world!',
      cache_creation_input_tokens: 100,
      cache_read_input_tokens: 0
    )
    
    # Check that the message includes cache-related token usage
    expect(message.cache_creation_input_tokens).to eq(100)
    expect(message.cache_read_input_tokens).to eq(0)
    
    # Check that the hash representation includes cache-related token usage
    expect(message.to_h[:cache_creation_input_tokens]).to eq(100)
    expect(message.to_h[:cache_read_input_tokens]).to eq(0)
  end

  it 'reports cache pricing information' do
    # Get the input price for the model
    input_price = RubyLLM::Providers::Anthropic::Capabilities.get_input_price(model)
    
    # Get the cache write price for the model
    cache_write_price = RubyLLM::Providers::Anthropic::Capabilities.cache_write_price_for(model)
    
    # Get the cache hit price for the model
    cache_hit_price = RubyLLM::Providers::Anthropic::Capabilities.cache_hit_price_for(model)
    
    # Check that the cache write price is 25% more than the input price
    expect(cache_write_price).to eq(input_price * 1.25)
    
    # Check that the cache hit price is 90% less than the input price
    expect(cache_hit_price).to eq(input_price * 0.1)
  end

  it 'reports caching support for Claude models' do
    # Check that caching is supported for Claude 3 models
    expect(RubyLLM::Providers::Anthropic::Capabilities.supports_caching?('claude-3-opus-20240229')).to be true
    expect(RubyLLM::Providers::Anthropic::Capabilities.supports_caching?('claude-3-sonnet-20240229')).to be true
    expect(RubyLLM::Providers::Anthropic::Capabilities.supports_caching?('claude-3-haiku-20240307')).to be true
    expect(RubyLLM::Providers::Anthropic::Capabilities.supports_caching?('claude-3-5-sonnet-20240620')).to be true
    expect(RubyLLM::Providers::Anthropic::Capabilities.supports_caching?('claude-3-7-sonnet-20250219')).to be true
    
    # Check that caching is not supported for Claude 2 models
    expect(RubyLLM::Providers::Anthropic::Capabilities.supports_caching?('claude-2.0')).to be false
    expect(RubyLLM::Providers::Anthropic::Capabilities.supports_caching?('claude-2.1')).to be false
  end
end
