# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#with_schema' do
    let(:person_schema) do
      {
        type: 'object',
        properties: {
          name: { type: 'string' },
          age: { type: 'integer' }
        },
        required: %w[name age],
        additionalProperties: false
      }
    end

    # Test OpenAI-compatible providers that support structured output
    # Note: Only test models that have json_schema support, not just json_object
    CHAT_MODELS.select { |model_info| %i[openai].include?(model_info[:provider]) }.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]

      context "with #{provider}/#{model}" do
        let(:chat) { RubyLLM.chat(model: model, provider: provider) }

        it 'accepts a JSON schema and returns structured output' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
          skip 'Model does not support structured output' unless chat.model.structured_output?

          response = chat
                     .with_schema(person_schema)
                     .ask('Generate a person named John who is 30 years old')

          # Content should already be parsed as a Hash when schema is used
          expect(response.content).to be_a(Hash)
          expect(response.content['name']).to eq('John')
          expect(response.content['age']).to eq(30)
        end

        it 'raises an error if model does not support structured output' do
          allow(chat.model).to receive(:structured_output?).and_return(false)

          expect do
            chat.with_schema(person_schema)
          end.to raise_error(RubyLLM::UnsupportedStructuredOutputError)
        end

        it 'allows forcing schema even if model does not support structured output' do
          allow(chat.model).to receive(:structured_output?).and_return(false)

          expect do
            chat.with_schema(person_schema, force: true)
          end.not_to raise_error
        end

        it 'allows removing schema with nil mid-conversation' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
          # First, ask with schema - should get parsed JSON
          chat.with_schema(person_schema)
          response1 = chat.ask('Generate a person named Bob')

          expect(response1.content).to be_a(Hash)
          expect(response1.content['name']).to eq('Bob')

          # Remove schema and ask again - should get plain string
          chat.with_schema(nil)
          response2 = chat.ask('Now just tell me about Ruby')

          expect(response2.content).to be_a(String)
          expect(response2.content).to include('Ruby')
        end
      end
    end

    # Test Gemini provider separately due to different schema format
    CHAT_MODELS.select { |model_info| model_info[:provider] == :gemini }.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]

      context "with #{provider}/#{model}" do
        let(:chat) { RubyLLM.chat(model: model, provider: provider) }

        it 'converts JSON schema to Gemini format and returns structured output' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
          skip 'Model does not support structured output' unless chat.model.structured_output?

          response = chat
                     .with_schema(person_schema)
                     .ask('Generate a person named Jane who is 25 years old')

          # Content should already be parsed as a Hash when schema is used
          expect(response.content).to be_a(Hash)
          expect(response.content['name']).to eq('Jane')
          expect(response.content['age']).to eq(25)
        end
      end
    end

    # Test schema with arrays and nested objects
    describe 'complex schemas' do
      let(:complex_schema) do
        {
          type: 'object',
          properties: {
            users: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  name: { type: 'string' },
                  role: { type: 'string', enum: %w[admin user guest] }
                },
                required: %w[name role],
                additionalProperties: false
              }
            },
            metadata: {
              type: 'object',
              properties: {
                created_at: { type: 'string' },
                version: { type: 'integer' }
              },
              required: %w[created_at version],
              additionalProperties: false
            }
          },
          required: %w[users metadata],
          additionalProperties: false
        }
      end

      test_model = CHAT_MODELS.find do |model_info|
        %i[openai gemini].include?(model_info[:provider])
      end

      if test_model
        model = test_model[:model]
        provider = test_model[:provider]

        it "#{provider}/#{model} handles complex nested schemas" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
          chat = RubyLLM.chat(model: model, provider: provider)
          skip 'Model does not support structured output' unless chat.model.structured_output?

          response = chat
                     .with_schema(complex_schema)
                     .ask('Generate a response with 2 users and metadata with version 1')

          # Content should already be parsed as a Hash when schema is used
          expect(response.content).to be_a(Hash)
          expect(response.content['users']).to be_an(Array)
          expect(response.content['users'].length).to be >= 2
          expect(response.content['metadata']['version']).to eq(1)
        end
      end
    end
  end
end
