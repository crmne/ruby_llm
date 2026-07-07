# frozen_string_literal: true

require 'spec_helper'

# Define a test schema class for testing RubyLLM::Schema instances
class PersonSchemaClass < RubyLLM::Schema
  string :name
  number :age
end

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

    it 'removes the schema with without_schema' do
      chat = RubyLLM.chat.with_schema(person_schema)

      chat.without_schema

      expect(chat.schema).to be_nil
    end

    it 'rejects nil, pointing to without_schema' do
      chat = RubyLLM.chat

      expect { chat.with_schema(nil) }.to raise_error(ArgumentError, /without_schema/)
    end

    # Test providers that support structured output with JSON schema
    # Note: Only test models that have json_schema support, not just json_object
    STRUCTURED_OUTPUT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]

      context "with #{provider}/#{model}" do
        let(:chat) { RubyLLM.chat(model: model, provider: provider) }

        it 'accepts a JSON schema and returns structured output' do
          skip 'Model does not support structured output' unless chat.model.supports?(:structured_output)

          response = chat
                     .with_schema(person_schema)
                     .ask('Generate a person named John who is 30 years old')

          # Content stays the raw JSON string; #parsed returns the Hash
          expect(response.content).to be_a(String)
          expect(response.parsed).to be_a(Hash)
          expect(response.parsed['name']).to eq('John')
          expect(response.parsed['age']).to eq(30)
        end

        it 'accepts schema regardless of model capabilities' do
          allow(chat.model).to receive(:structured_output?).and_return(false)

          expect do
            chat.with_schema(person_schema)
          end.not_to raise_error
        end

        it 'allows removing schema mid-conversation' do
          # First, ask with schema - content is a JSON string, #parsed gives the Hash
          chat.with_schema(person_schema)
          response1 = chat.ask('Generate a person named Bob')

          expect(response1.content).to be_a(String)
          expect(response1.parsed).to be_a(Hash)
          expect(response1.parsed['name']).to be_a(String)
          expect(response1.parsed['name']).not_to be_empty
          expect(response1.parsed['age']).to be_a(Integer)

          # Remove schema and ask again - should get plain string
          chat.without_schema
          response2 = chat.ask('Now just tell me about Ruby')

          expect(response2.content).to be_a(String)
          expect(response2.content).to include('Ruby')
        end

        it 'accepts RubyLLM::Schema class instances and returns structured output' do
          skip 'Model does not support structured output' unless chat.model.supports?(:structured_output)

          response = chat
                     .with_schema(PersonSchemaClass)
                     .ask('Generate a person named Alice who is 28 years old')

          # Content stays the raw JSON string; #parsed returns the Hash
          expect(response.content).to be_a(String)
          expect(response.parsed).to be_a(Hash)
          expect(response.parsed['name']).to eq('Alice')
          expect(response.parsed['age']).to eq(28)
        end
      end
    end

    describe 'schema name sanitization' do
      it 'sanitizes :: from namespaced RubyLLM::Schema class names' do
        namespaced_schema = stub_const('MyApp::Nested::TestSchema', Class.new(RubyLLM::Schema) do
          string :name
        end)

        chat = RubyLLM.chat
        chat.with_schema(namespaced_schema)
        schema = chat.schema

        expect(schema[:name]).to eq('MyApp__Nested__TestSchema')
        expect(schema[:name]).to match(/\A[a-zA-Z0-9_-]+\z/)
      end

      it 'sanitizes :: from plain hash schema names' do
        chat = RubyLLM.chat
        chat.with_schema({
                           name: 'Some::Namespaced::Schema',
                           schema: { type: 'object', properties: {} }
                         })

        expect(chat.schema[:name]).to eq('Some__Namespaced__Schema')
      end

      it 'uses response as default name when no name is provided' do
        chat = RubyLLM.chat
        chat.with_schema({ type: 'object', properties: {} })

        expect(chat.schema[:name]).to eq('response')
      end

      it 'uses response as default name when provided name is empty' do
        chat = RubyLLM.chat
        chat.with_schema({
                           name: '',
                           schema: { type: 'object', properties: {} }
                         })

        expect(chat.schema[:name]).to eq('response')
      end
    end

    # Regression test for schema + tool calls interaction
    # When both schema and tools are used, intermediate tool-call responses
    # may contain JSON-like text content. Content is never auto-parsed:
    # it must stay a plain String on every message so it serializes
    # correctly on the next API call. #parsed gives the Hash on demand.
    describe 'schema with tool calls' do
      before do
        stub_const('SchemaToolTestWeather', Class.new(RubyLLM::Tool) do
          description 'Gets current weather for a location'
          parameter :location, description: 'City name'

          def execute(location:)
            "Weather in #{location}: 20°C"
          end
        end)
      end

      it 'does not parse tool-call response content as JSON when schema is set' do
        chat = RubyLLM.chat.with_tools(SchemaToolTestWeather).with_schema(person_schema)
        provider = chat.instance_variable_get(:@provider)

        tool_call = RubyLLM::ToolCall.new(
          id: 'call_1',
          name: 'schema_tool_test_weather',
          arguments: { 'location' => 'Berlin' }
        )

        # First response: tool call with JSON-like text content
        # Second response: final answer with valid JSON matching the schema
        allow(provider).to receive(:complete).and_return(
          RubyLLM::Message.new(
            role: :assistant,
            content: '{"name": "partial"}',
            tool_calls: { tool_call.id => tool_call }
          ),
          RubyLLM::Message.new(
            role: :assistant,
            content: '{"name": "John", "age": 30}'
          )
        )

        response = chat.ask('What is the weather and generate a person named John who is 30?')

        # The intermediate tool-call message should have kept content as String
        tool_call_msg = chat.messages.find { |m| m.role == :assistant && m.tool_call? }
        expect(tool_call_msg.content).to be_a(String)
        expect(tool_call_msg.content).to eq('{"name": "partial"}')

        # The final response content stays a String too; #parsed returns the Hash
        expect(response.content).to be_a(String)
        expect(response.parsed['name']).to eq('John')
        expect(response.parsed['age']).to eq(30)
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
        %i[openai gemini bedrock].include?(model_info[:provider])
      end

      if test_model
        model = test_model[:model]
        provider = test_model[:provider]

        it "#{provider}/#{model} handles complex nested schemas" do
          chat = RubyLLM.chat(model: model, provider: provider)
          skip 'Model does not support structured output' unless chat.model.supports?(:structured_output)

          response = chat
                     .with_schema(complex_schema)
                     .ask('Generate a response with 2 users and metadata with version 1')

          # Content stays the raw JSON string; #parsed returns the Hash
          expect(response.content).to be_a(String)
          expect(response.parsed).to be_a(Hash)
          expect(response.parsed['users']).to be_an(Array)
          expect(response.parsed['users'].length).to be >= 2
          expect(response.parsed['metadata']['version']).to eq(1)
        end
      end
    end
  end
end
