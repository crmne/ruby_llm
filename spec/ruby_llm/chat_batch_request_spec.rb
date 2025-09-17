# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  class WeatherTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Gets current weather for a location'
    param :location, desc: 'City name or location'

    def execute(location:)
      "Current weather in #{location}: 15°C, partly cloudy"
    end
  end

  describe 'batch request functionality' do
    describe '#for_batch_request' do
      it 'enables batch request mode' do
        chat = RubyLLM.chat
        result = chat.for_batch_request
        expect(result).to eq(chat) # returns self for chaining
      end

      it 'changes behavior of complete method' do
        chat = RubyLLM.chat.for_batch_request
        chat.add_message(role: :user, content: 'test')

        # Should return a hash payload instead of making API call
        result = chat.complete
        expect(result).to be_a(Hash)
      end
    end

    describe '#complete with batch_request format' do
      CHAT_MODELS.each do |model_info|
        model = model_info[:model]
        provider = model_info[:provider]

        context "with #{provider}/#{model}" do
          it 'returns a batch request payload instead of making an API call' do
            chat = RubyLLM.chat(model: model, provider: provider)
                          .for_batch_request

            chat.add_message(role: :user, content: "What's 2 + 2?")

            # Only OpenAI currently supports batch requests
            if provider == :openai
              payload = chat.complete

              expect(payload).to be_a(Hash)
              expect(payload[:custom_id]).to be_present
              expect(payload[:method]).to eq('POST')
              expect(payload[:url]).to eq('/v1/chat/completions')
              expect(payload[:body]).to be_present
              expect(payload[:body][:model]).to eq(model)

              # Verify no message was added (since no actual response was received)
              expect(chat.messages.count).to eq(1)
              expect(chat.messages.last.role).to eq(:user)
            else
              # Other providers should raise NotImplementedError
              expect { chat.complete }.to raise_error(
                NotImplementedError,
                /does not support batch requests/
              )
            end
          end

          it 'includes tools in the batch request payload when tools are configured' do
            # Skip for non-OpenAI providers since they don't support batch requests
            skip "#{provider} doesn't support batch requests" unless provider == :openai

            # Skip if provider doesn't support functions or model is not in registry
            begin
              model_info = RubyLLM::Models.find(model)
              skip "#{provider} doesn't support functions" unless model_info.supports_functions?
            rescue RubyLLM::ModelNotFoundError
              skip "Model #{model} not found in registry"
            end

            chat = RubyLLM.chat(model: model, provider: provider)
                          .for_batch_request
                          .with_tool(WeatherTool)

            chat.add_message(role: :user, content: "What's the weather in Tokyo?")

            payload = chat.complete

            expect(payload).to be_a(Hash)
            expect(payload[:body]).to be_present

            # The body should contain tool definitions for OpenAI
            body = payload[:body]
            expect(body[:tools] || body[:functions]).to be_present
          end

          it 'includes schema in the batch request payload when schema is configured' do
            # Skip for non-OpenAI providers since they don't support batch requests
            skip "#{provider} doesn't support batch requests" unless provider == :openai

            # Skip if provider doesn't support structured output or model is not in registry
            begin
              model_info = RubyLLM::Models.find(model)
              skip "#{provider} doesn't support structured output" unless model_info.structured_output?
            rescue RubyLLM::ModelNotFoundError
              skip "Model #{model} not found in registry"
            end

            schema = {
              type: 'object',
              properties: {
                answer: { type: 'integer' },
                explanation: { type: 'string' }
              },
              required: %w[answer explanation]
            }

            chat = RubyLLM.chat(model: model, provider: provider)
                          .for_batch_request
                          .with_schema(schema)

            chat.add_message(role: :user, content: "What's 2 + 2?")

            payload = chat.complete

            expect(payload).to be_a(Hash)
            expect(payload[:body]).to be_present

            # The body should contain schema information for OpenAI
            body = payload[:body]
            expect(body[:response_format]).to be_present
          end

          it 'raises error when attempting to stream with batch_request format' do
            chat = RubyLLM.chat(model: model, provider: provider)
                          .for_batch_request

            chat.add_message(role: :user, content: 'Test message')

            expect { chat.complete { |chunk| puts chunk } }.to raise_error(
              ArgumentError,
              'Streaming is not supported for batch requests'
            )
          end

          it 'includes custom parameters in the batch request payload' do
            # Skip for non-OpenAI providers since they don't support batch requests
            skip "#{provider} doesn't support batch requests" unless provider == :openai

            chat = RubyLLM.chat(model: model, provider: provider)
                          .for_batch_request
                          .with_params(max_tokens: 100, top_p: 0.9)
                          .with_temperature(0.5)

            chat.add_message(role: :user, content: 'Test message')

            payload = chat.complete

            expect(payload).to be_a(Hash)
            body = payload[:body]

            # Check that parameters are present in the payload
            expect(body).to be_present
            expect(body[:messages]).to be_present
            expect(body[:max_tokens]).to eq(100)
            expect(body[:top_p]).to eq(0.9)
            expect(body[:temperature]).to eq(0.5)
          end
        end
      end
    end

    describe 'batch request workflow example' do
      it 'demonstrates generating multiple batch requests' do
        requests = []

        # Generate multiple batch request payloads
        3.times do |i|
          chat = RubyLLM.chat.for_batch_request
          chat.add_message(role: :user, content: "Question #{i + 1}: What's #{i + 1} + #{i + 1}?")

          payload = chat.complete
          requests << payload
        end

        expect(requests).to be_an(Array)
        expect(requests.length).to eq(3)

        requests.each_with_index do |request, i|
          expect(request).to be_a(Hash)
          expect(request[:body]).to be_present

          # Verify each request has the correct question
          messages = request[:body][:messages]
          expect(messages).to be_present
          expect(messages.last[:content]).to include("Question #{i + 1}")
        end
      end

      it 'demonstrates batch request mode' do
        # Create a chat in batch request mode
        chat = RubyLLM.chat.for_batch_request
        chat.add_message(role: :user, content: "What's 2 + 2?")

        # Generate batch request payload
        payload = chat.complete
        expect(payload).to be_a(Hash)
        expect(chat.messages.count).to eq(1) # Only user message (no response added)

        # NOTE: In production, you'd use this payload with the provider's batch API
        # For normal API calls, create a new chat without for_batch_request
      end
    end
  end
end
