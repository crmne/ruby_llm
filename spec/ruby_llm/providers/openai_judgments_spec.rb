# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenAI do
  include_context 'with configured RubyLLM'

  let(:model_id) { model_for(:openai, :judgment) }
  let(:image_path) { File.expand_path('../../fixtures/ruby.png', __dir__) }
  let(:questions) { { urgent: { type: :probability, instructions: 'Does this need attention today?' } } }

  it 'routes judgments to Decisions even when chat uses a configured protocol' do
    context = RubyLLM.context { |config| config.openai_protocol = :chat_completions }
    stub = stub_request(:post, 'https://api.openai.com/v1/decisions').to_return(
      status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { model: model_id, answers: [{ type: 'predicate', name: 'urgent', probability: 0.2 }],
              usage: { input_tokens: 10, output_tokens: 1 } }.to_json
    )

    expect(context.judge('Help', model: model_id, provider: :openai, questions:).urgent.probability).to eq(0.2)
    expect(stub).to have_been_requested.once
  end

  it 'judges through the OpenAI connection and prices usage from the model registry' do
    stub = stub_request(:post, 'https://api.openai.com/v1/decisions')
           .with(headers: { 'Authorization' => "Bearer #{RubyLLM.config.openai_api_key}" }, body: {
                   model: model_id, input: 'Please help today.',
                   questions: [{ type: 'predicate', name: 'urgent', instructions: 'Does this need attention today?' }]
                 })
           .to_return(status: 200, body: {
             model: model_id, answers: [{ type: 'predicate', name: 'urgent', probability: 0.9 }],
             usage: { input_tokens: 40, output_tokens: 1 }
           }.to_json, headers: { 'Content-Type' => 'application/json' })

    result = RubyLLM.judge('Please help today.', model: model_id, provider: :openai, questions:)

    expect(result.urgent.probability).to eq(0.9)
    expect(result.tokens.input).to eq(40)
    registry_model = RubyLLM.models.find(model_id, provider: :openai)
    expect(result.cost.total).to eq(RubyLLM::Cost.new(tokens: result.tokens, model: registry_model).total)
    expect(stub).to have_been_requested.once
  end

  it 'reports normalized OpenAI errors' do
    stub_request(:post, 'https://api.openai.com/v1/decisions')
      .to_return(status: 401, body: { error: { message: 'Incorrect API key provided' } }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    expect { RubyLLM.judge('Help', model: model_id, provider: :openai, questions:) }
      .to raise_error(RubyLLM::UnauthorizedError, 'Incorrect API key provided')
  end

  context 'with the Decisions API', :live do
    before { skip_without_cassette_or_key('OPENAI_API_KEY') }

    it 'judges all three question types through the compact DSL' do
      id = model_id
      triage = Class.new(RubyLLM::Judge) do
        model id, provider: :openai
        probability :urgent, 'Does the customer explicitly need action today?' do
          yes 'Explicitly asks for action today'
          no 'No deadline or a later deadline'
        end
        choice :department, 'Which team should handle this message?' do
          billing 'Payments and refunds'
          technical 'Bugs and integrations'
          other nil
        end
        score :frustration, 'How frustrated is the customer?',
              ['Calm and polite', 'Expresses frustration', 'Angry or hostile']
      end

      result = triage.judge do
        message 'I was charged twice. Please refund the duplicate charge today.'
      end

      expect(result[:urgent].probability).to be_between(0, 1)
      expect(result[:department].choice).to be_in(%i[billing technical other])
      expect(result[:department].probabilities.keys).to eq(%i[billing technical other])
      expect(result[:frustration].score).to be_between(0, 2)
      expect(result[:frustration].probabilities.keys).to eq([0, 1, 2])
      expect(result.tokens.input).to be_positive
      expect(result.tokens.output).to be_positive
      expect(result.model).to start_with('gpt-6-luna')
    end

    it 'judges an image without text input' do
      result = RubyLLM.judge(with: image_path, model: model_id, provider: :openai, questions: {
                               logo: { type: :probability, instructions: 'Is this image a logo?' },
                               color: { type: :choice, instructions: 'What is the dominant color?',
                                        options: { red: nil, blue: nil, green: nil } }
                             })

      expect(result.logo.probability).to be_between(0, 1)
      expect(result.color.choice).to be_in(%i[red blue green])
      expect(result.tokens.input).to be_positive
    end
  end
end
