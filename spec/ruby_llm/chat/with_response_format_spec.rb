# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat, '#with_response_format' do
  include_context 'with configured RubyLLM'

  # TODO: Add support for other API types
  # chat_models = %w[claude-3-5-haiku-20241022
  #                  anthropic.claude-3-5-haiku-20241022-v1:0
  #                  gemini-2.0-flash
  #                  deepseek-chat
  #                  gpt-4.1-nano].freeze

  chat_models = %w[gpt-4.1-nano].freeze
  chat_models.each do |model|
    provider = RubyLLM::Models.provider_for(model).slug

    context "with #{provider}/#{model}" do
      let(:chat) { RubyLLM.chat(model: model) }

      describe 'simple type param' do
        it 'returns simple integer responses' do
          expect(chat.with_response_format(:integer).ask("What's 2 + 2?").content).to eq(4)
        end

        it 'returns simple string responses' do
          response = chat.with_response_format(:string).ask("Say 'Hello World' and nothing else.").content
          expect(response).to eq('Hello World')
        end

        it 'returns array response' do
          chat.with_response_format(:array, items: { type: :string })
          response = chat.ask('What are the 2 largest countries? Only respond with country names.').content
          expect(response).to be_a(Array)
        end

        it 'returns object response' do
          chat.with_response_format(:json)
          result = chat.ask('Provide a sample customer data object with name and email keys.')
          expect(result.content).to be_a(Hash)
        end
      end

      describe 'more complex schemas' do
        it 'returns strings within object' do
          chat.with_response_format(:object, properties: { name: { type: :string } })
          response = chat.ask('Provide a sample customer name.').content
          expect(response['name']).to be_a(String)
        end

        it 'returns integers within object' do
          chat.with_response_format(:object, properties: { age: { type: :integer } })
          response = chat.ask('Provide sample customer age between 10 and 100.').content
          expect(response['age']).to be_a(Integer)
        end

        it 'returns arrays within object' do # rubocop:disable RSpec/ExampleLength -- Just trying to meet line length limit
          chat.with_response_format(
            :object,
            properties: { hobbies: { type: :array, items: { type: :string, enum: %w[Soccer Golf Hockey] } } }
          )
          response = chat.ask('Provide at least 1 hobby.').content
          expect(response['hobbies']).to all(satisfy { |hobby| %w[Soccer Golf Hockey].include?(hobby) })
        end
      end
    end
  end
end
