# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#with_max_output_tokens' do
    {
      openai: { model: 'gpt-4.1-nano', key: :max_output_tokens },
      anthropic: { model: 'claude-haiku-4-5', key: :max_tokens },
      deepseek: { model: 'deepseek-chat', key: :max_tokens }
    }.each do |provider, config|
      it "maps to #{config[:key]} for #{provider}" do
        payload = RubyLLM.chat(model: config[:model], provider: provider).with_max_output_tokens(1234).render

        expect(payload[config[:key]]).to eq(1234)
      end
    end

    it 'maps to generationConfig.maxOutputTokens for gemini' do
      payload = RubyLLM.chat(model: 'gemini-2.5-flash', provider: :gemini).with_max_output_tokens(1234).render

      expect(payload.dig(:generationConfig, :maxOutputTokens)).to eq(1234)
    end

    it 'clears the limit with without_max_output_tokens' do
      payload = RubyLLM.chat(model: 'gpt-4.1-nano', provider: :openai)
                       .with_max_output_tokens(1234).without_max_output_tokens.render

      expect(payload).not_to have_key(:max_output_tokens)
    end

    it 'rejects nil, pointing to without_max_output_tokens' do
      expect { RubyLLM.chat.with_max_output_tokens(nil) }.to raise_error(ArgumentError, /without_max_output_tokens/)
    end
  end

  describe 'with params' do
    it 'clears provider options with without_provider_options' do
      chat = RubyLLM.chat.with_provider_options(max_tokens: 100)

      chat.without_provider_options

      expect(chat.provider_options).to eq({})
    end

    it 'rejects nil, pointing to without_provider_options' do
      chat = RubyLLM.chat

      expect { chat.with_provider_options(nil) }.to raise_error(ArgumentError, /without_provider_options/)
    end

    it 'requires provider options' do
      chat = RubyLLM.chat

      expect { chat.with_provider_options }.to raise_error(ArgumentError)
    end

    # Supported params vary by provider, and to lesser degree, by model.

    # Providers [:openai, :ollama, :deepseek] support a JSON object mode param.
    # On Chat Completions it's {response_format: {type: 'json_object'}}; on the
    # Responses API (OpenAI's default) it's {text: {format: {type: 'json_object'}}}.
    # (Note that :openrouter may accept the parameter but silently ignore it.)
    CHAT_MODELS.select { |model_info| %i[openai ollama deepseek].include?(model_info[:provider]) }.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      json_object_params = if provider == :openai
                             { text: { format: { type: 'json_object' } } }
                           else
                             { response_format: { type: 'json_object' } }
                           end
      it "#{provider}/#{model} supports response_format param" do
        chat = RubyLLM
               .chat(model: model, provider: provider)
               .with_provider_options(**json_object_params)

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
      it "#{provider}/#{model} supports responseSchema param" do
        chat = RubyLLM
               .chat(model: model, provider: provider)
               .with_provider_options(
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
      it "#{provider}/#{model} supports service_tier param" do
        chat = RubyLLM
               .chat(model: model, provider: provider)
               .with_provider_options(service_tier: 'standard_only')

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

        response = chat.generate

        json_response = JSON.parse('{' + response.content) # rubocop:disable Style/StringConcatenation
        expect(json_response).to eq({ 'result' => 8 })
      end
    end

    # Providers [:openrouter, :bedrock] support a top_k param to remove low-probability next tokens.
    # OpenRouter takes {top_k: ...} at the top level. The Bedrock Converse API takes model-specific
    # inference fields in additionalModelRequestFields, and Amazon Nova nests them under inferenceConfig
    # as {additionalModelRequestFields: {inferenceConfig: {topK: ...}}}.
    CHAT_MODELS.select { |model_info| %i[openrouter bedrock].include?(model_info[:provider]) }.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      top_k_params = if provider == :bedrock
                       { additionalModelRequestFields: { inferenceConfig: { topK: 5 } } }
                     else
                       { top_k: 5 }
                     end
      it "#{provider}/#{model} supports top_k param" do
        chat = RubyLLM
               .chat(model: model, provider: provider)
               .with_provider_options(**top_k_params)

        chat.add_message(
          role: :user,
          content: 'What is the square root of 64? Answer with a JSON object with the key `result`.'
        )

        # See comment on :anthropic example above for explanation of steering the model toward a JSON object response.
        chat.add_message(
          role: :assistant,
          content: '{'
        )

        response = chat.generate

        json_response = JSON.parse('{' + response.content) # rubocop:disable Style/StringConcatenation
        expect(json_response).to eq({ 'result' => 8 })
      end
    end
  end
end
