# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe 'with options' do
    CHAT_MODELS.select { |model_info| %i[deepseek openai openrouter ollama].include?(model_info[:provider]) }.each do |model_info| # rubocop:disable Layout/LineLength
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} supports response_format option" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM
               .chat(model: model, provider: provider)
               .with_options(response_format: { type: 'json_object' })

        response = chat.ask('What is the square root of 64? Answer with a JSON object with the key `result`.')

        json_object = JSON.parse(response.content)
        expect(json_object).to eq({ 'result' => 8 })

        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end
    end

    CHAT_MODELS.select { |model_info| model_info[:provider] == :anthropic }.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} supports service_tier option" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM
               .chat(model: model, provider: provider)
               .with_options(service_tier: 'standard_only')

        response = chat.ask('What is the square root of 64? Answer with a JSON object with the key `result`.')

        json_object = JSON.parse(response.content)
        expect(json_object).to eq({ 'result' => 8 })

        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end
    end

    CHAT_MODELS.select { |model_info| model_info[:provider] == :gemini }.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} supports responseSchema option" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM
               .chat(model: model, provider: provider)
               .with_options(generationConfig: {
                               responseMimeType: 'application/json',
                               responseSchema: {
                                 type: 'OBJECT',
                                 properties: { result: { type: 'NUMBER' } }
                               }
                             })

        response = chat.ask('What is the square root of 64? Answer with a JSON object with the key `result`.')

        json_object = JSON.parse(response.content)
        expect(json_object).to eq({ 'result' => 8 })

        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end
    end

    CHAT_MODELS.select { |model_info| model_info[:provider] == :bedrock }.each do |model_info|
      model = model_info[:model]
      provider = model_info[:provider]
      it "#{provider}/#{model} supports top_k option" do # rubocop:disable RSpec/ExampleLength,RSpec/MultipleExpectations
        chat = RubyLLM
               .chat(model: model, provider: provider)
               .with_options(top_k: 5)

        response = chat.ask('What is the square root of 64? Answer with a JSON object with the key `result`.')

        json_object = JSON.parse(response.content)
        expect(json_object).to eq({ 'result' => 8 })

        expect(response.role).to eq(:assistant)
        expect(response.input_tokens).to be_positive
        expect(response.output_tokens).to be_positive
      end
    end
  end
end
