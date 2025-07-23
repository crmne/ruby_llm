# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe 'with params' do
    # Supported params vary by provider, and to lesser degree, by model.

    # Providers [:openai, :ollama, :deepseek] support {response_format: {type: 'json_object'}}
    # to guarantee a JSON object is returned.
    # (Note that :openrouter may accept the parameter but silently ignore it.)
    CHAT_MODELS.select { |model_info| %i[openai ollama deepseek].include?(model_info[:provider]) }.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} supports response_format param" do # rubocop:disable RSpec/ExampleLength
        chat = RubyLLM
               .chat(model: model, provider: provider)
               .with_params(response_format: { type: 'json_object' })

        response = chat.ask('What is the square root of 64? Answer with a JSON object with the key `result`.')

        json_response = JSON.parse(response.content)
        expect(json_response).to eq({ 'result' => 8 })
      end
    end

    # Provider [:gemini] supports a {generationConfig: {responseMimeType: ..., responseSchema: ...} } param,
    # which can specify a JSON schema, requiring a deep_merge of params into the payload.
    CHAT_MODELS.select { |model_info| model_info[:provider] == :gemini }.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} supports responseSchema param" do # rubocop:disable RSpec/ExampleLength
        chat = RubyLLM
               .chat(model: model, provider: provider)
               .with_params(
                 generationConfig: {
                   responseMimeType: 'application/json',
                   responseSchema: {
                     type: 'OBJECT',
                     properties: { result: { type: 'NUMBER' } }
                   }
                 }
               )

        response = chat.ask('What is the square root of 64? Answer with a JSON object with the key `result`.')

        json_response = JSON.parse(response.content)
        expect(json_response).to eq({ 'result' => 8 })
      end
    end

    # Provider [:anthropic] supports a service_tier param.
    CHAT_MODELS.select { |model_info| model_info[:provider] == :anthropic }.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} supports service_tier param" do # rubocop:disable RSpec/ExampleLength
        chat = RubyLLM
               .chat(model: model, provider: provider)
               .with_params(service_tier: 'standard_only')

        chat.add_message(
          role: :user,
          content: 'What is the square root of 64? Answer with a JSON object with the key `result`.'
        )

        # :anthropic does not support {response_format: {type: 'json_object'}},
        # but can be steered this way by adding a leading '{' as assistant.
        # (This leading '{' must be prepended to response.content before parsing.)
        chat.add_message(
          role: :assistant,
          content: '{'
        )

        response = chat.complete

        json_response = JSON.parse('{' + response.content) # rubocop:disable Style/StringConcatenation
        expect(json_response).to eq({ 'result' => 8 })
      end
    end

    # Providers [:openrouter, :bedrock] supports a {top_k: ...} param to remove low-probability next tokens.
    CHAT_MODELS.select { |model_info| %i[openrouter bedrock].include?(model_info[:provider]) }.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} supports top_k param" do # rubocop:disable RSpec/ExampleLength
        chat = RubyLLM
               .chat(model: model, provider: provider)
               .with_params(top_k: 5)

        chat.add_message(
          role: :user,
          content: 'What is the square root of 64? Answer with a JSON object with the key `result`.'
        )

        # See comment on :anthropic example above for explanation of steering the model toward a JSON object response.
        chat.add_message(
          role: :assistant,
          content: '{'
        )

        response = chat.complete

        json_response = JSON.parse('{' + response.content) # rubocop:disable Style/StringConcatenation
        expect(json_response).to eq({ 'result' => 8 })
      end
    end
  end
end
