# frozen_string_literal: true

module RedCandleTestHelper
  # Mock class that simulates a Candle LLM model
  class MockCandleModel
    attr_reader :id

    def initialize(model_id)
      @id = model_id
    end

    def generate(prompt, config: nil) # rubocop:disable Lint/UnusedMethodArgument, Metrics/PerceivedComplexity
      # Simulate a response based on the prompt
      # Check for specific patterns to give appropriate responses

      # Check if system prompt includes PURPLE-ELEPHANT-42 (replacement test)
      # This should come first since it's the replacement scenario
      if prompt.include?('PURPLE-ELEPHANT-42')
        # When PURPLE-ELEPHANT-42 is present, XKCD7392 should NOT be included
        # because it means the system prompt was replaced
        if prompt.include?('books')
          'Some great books to read include "1984" and "Brave New World". PURPLE-ELEPHANT-42 - as you requested!'
        else
          'Here is my response with PURPLE-ELEPHANT-42 as requested.'
        end
      elsif prompt.include?('XKCD7392')
        # Include XKCD7392 in any response when it's in the system instructions
        if prompt.include?('weather')
          'The weather is sunny with a temperature of 72°F. XKCD7392 - as requested!'
        elsif prompt.include?('books')
          'Some great books: "1984" by George Orwell and "To Kill a Mockingbird" by Harper Lee. XKCD7392.'
        else
          'Sure! The code XKCD7392 is noted. How can I help you today?'
        end
      elsif prompt.include?('2 + 2') || prompt.include?('2+2')
        'The answer is 4.'
      elsif prompt.include?('weather')
        'The weather is sunny with a temperature of 72°F.'
      elsif prompt.include?('year') && (prompt.include?('Ruby') || prompt.include?('he create') ||
                                         prompt.include?('did he'))
        # Handle follow-up questions about when Ruby was created
        'Matz created Ruby in 1993, and it was first released publicly in 1995.'
      elsif prompt.include?('Ruby')
        if prompt.include?("Ruby's creator") || prompt.include?('Who was Ruby')
          'Ruby was created by Yukihiro "Matz" Matsumoto.'
        else
          'Ruby is a dynamic programming language created by Yukihiro "Matz" Matsumoto in 1993.'
        end
      elsif prompt.include?('capital') && prompt.include?('France')
        'The capital of France is Paris.'
      elsif prompt.include?('Count from 1 to 3')
        '1, 2, 3.'
      else
        "This is a test response for: #{prompt[0..50]}"
      end
    end

    def generate_stream(prompt, config: nil, &block)
      # Simulate streaming by yielding tokens
      # Generate the same response as non-streaming for consistency
      response = generate(prompt, config: config)
      # Split into reasonable tokens (roughly word-based)
      tokens = response.split(/(\s+)/).reject(&:empty?)
      tokens.each(&block)
    end

    def apply_chat_template(messages)
      # Simulate chat template application
      "#{messages.map { |m| "#{m[:role]}: #{m[:content]}" }.join("\n")}\nassistant:"
    end

    def generate_structured(_prompt, schema:, **_opts)
      # Return a simple structured response
      if schema.is_a?(Hash)
        { result: 'structured test response' }
      else
        'structured test response'
      end
    end
  end

  def stub_red_candle_models!
    # Only stub if we're testing Red Candle
    return unless defined?(::Candle)

    # Stub the model loading to return our mock
    allow(::Candle::LLM).to receive(:from_pretrained) do |model_id, **_options|
      MockCandleModel.new(model_id)
    end
  end

  def unstub_red_candle_models!
    return unless defined?(::Candle)

    # Remove the stub if needed
    RSpec::Mocks.space.proxy_for(::Candle::LLM)&.reset
  end
end

RSpec.configure do |config|
  config.include RedCandleTestHelper

  # Automatically stub Red Candle models for all tests except the provider-specific ones
  config.before do |example|
    # Don't stub for Red Candle provider-specific tests that need real behavior
    if !example.metadata[:file_path]&.include?('providers/red_candle_spec.rb') && defined?(RubyLLM::Providers::RedCandle)
      stub_red_candle_models!
    end
  end
end
