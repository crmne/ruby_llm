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

  describe 'error handling' do
    CHAT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      context "with #{provider}/#{model}" do
        let(:chat) { RubyLLM.chat(model: model, provider: provider) }

        before do
          # Sabotage the API key after initialization
          RubyLLM::Provider.remote_providers.each_key do |slug|
            RubyLLM.config.public_send("#{slug}_api_key=", 'invalid-key')
          end
        end

        it 'raises appropriate auth error' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
          skip('Only valid for remote providers') if RubyLLM::Provider.providers[provider].local?
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
    CHAT_MODELS.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      context "#{provider}/#{model}" do # rubocop:disable RSpec/ContextWording
        let(:chat) { RubyLLM.chat(model: model, provider: provider) }

        it 'handles invalid message format errors' do # rubocop:disable RSpec/MultipleExpectations,RSpec/ExampleLength
          skip('OpenRouter gets stuck with an invalid message format') if provider == :openrouter
          skip("Gemini doesn't throw an error for invalid message format") if provider == :gemini
          # Try to mess up the message format
          bad_content = { type: 'text', wrong: 'format' }
          chat.add_message(role: :user, content: bad_content)

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

        it 'handles context length exceeded errors' do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
          skip('Ollama does not throw an error for context length exceeded') if provider == :ollama
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
          end
        end
      end
    end
  end
end
