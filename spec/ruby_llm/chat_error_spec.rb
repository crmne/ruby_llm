# frozen_string_literal: true

require 'spec_helper'

RSpec::Matchers.define :include_words do |*words|
  match do |actual|
    words.all? { |word| actual.downcase.include?(word.downcase) }
  end

  failure_message do |actual|
    "expected '#{actual}' to include all words: #{words.join(', ')}"
  end
end

RSpec::Matchers.define :look_like_json do
  match do |actual|
    actual.strip.start_with?('{') || actual.strip.start_with?('[')
  end

  failure_message do |actual|
    "expected '#{actual}' to look like JSON"
  end

  failure_message_when_negated do |actual|
    "expected '#{actual}' not to look like JSON"
  end
end

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  chat_models = %w[
    claude-3-5-haiku-20241022
    anthropic.claude-3-5-haiku-20241022-v1:0
    gemini-2.0-flash
    deepseek-chat
    gpt-4.1-nano
    anthropic/claude-3.5-sonnet
  ].freeze

  describe 'error handling' do
    chat_models.each do |model|
      provider = RubyLLM::Models.provider_for(model).slug
      context "with #{provider}/#{model}" do
        let(:chat) { RubyLLM.chat(model: model) }

        before do
          # Sabotage the API key after initialization
          RubyLLM::Provider.providers.each_key do |slug|
            RubyLLM.config.public_send("#{slug}_api_key=", 'invalid-key')
          end
        end

        it 'raises appropriate auth error' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
          expect { chat.ask('Hello') }.to raise_error do |error|
            expect(error).to be_a(RubyLLM::Error)
            expect(error.class.ancestors).to include(RubyLLM::Error)
            expect(error.response).to be_present
            expect(error.message).to be_present
            # Error should be human readable
            expect(error.message).not_to look_like_json
            # Should be properly capitalized readable text
            expect(error.message).to match(/^[A-Za-z]/)
          end
        end
      end
    end
  end

  describe 'real error scenarios' do
    chat_models.each do |model|
      provider = RubyLLM::Models.provider_for(model).slug
      context "#{provider}/#{model}" do # rubocop:disable RSpec/ContextWording
        let(:chat) { RubyLLM.chat(model: model) }

        it 'handles invalid message format errors' do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
          skip('OpenRouter gets stuck with an invalid message format') if provider == 'openrouter'
          # Try to mess up the message format
          bad_content = { type: 'text', wrong: 'format' }
          chat.add_message(role: :user, content: bad_content)

          unless provider == 'gemini' # Gemini doesn't throw an error for invalid message format
            expect { chat.ask('hi') }.to raise_error(RubyLLM::Error) do |e|
              # Basic error format checks
              expect(e.message).not_to look_like_json
              expect(e.message).to match(/^[A-Za-z]/)

              # Provider specific messages
              case provider
              when 'deepseek'
                expect(e.message).to include_words('deserialize', 'content')
              when 'gemini'
                expect(e.message).to include_words('part', 'content')
              else
                expect(e.message).to include_words('message', 'content')
              end
            end
          end
        end

        it 'handles context length exceeded errors' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
          # Create a huge conversation
          massive_text = 'a' * 1_000_000

          # Create a few copies in the conversation
          5.times do
            chat.add_message(role: :user, content: massive_text)
            chat.add_message(role: :assistant, content: massive_text)
          end

          expect { chat.ask('Hi') }.to raise_error(RubyLLM::Error) do |e|
            # Basic error format checks
            expect(e.message).not_to look_like_json
            expect(e.message).to match(/^[A-Za-z]/)

            # Provider specific messages
            case provider
            when 'anthropic', 'bedrock'
              expect(e.message).to include_words('bytes')
            when 'gemini'
              expect(e.message).to include_words('token')
            when 'openai'
              expect(e.message).to include_words('large')
            when 'deepseek', 'openrouter'
              expect(e.message).to include_words('tokens', 'length')
            else
              expect(e.message).to include_words('limit')
            end
          end
        end
      end
    end
  end
end
