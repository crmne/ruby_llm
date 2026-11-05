# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Azure::Decisions do
  include_context 'with configured RubyLLM'

  let(:model_id) { model_for(:azure, :judgment) }
  let(:decisions_url) { 'https://rubyllm.services.ai.azure.com/openai/v1/decisions?api-version=v1' }
  let(:questions) { { urgent: { type: :probability, instructions: 'Does this need attention today?' } } }

  def provider_for(api_base)
    config = RubyLLM::Configuration.new.tap do |c|
      c.azure_api_base = api_base
      c.azure_api_key = 'azure-key'
    end

    RubyLLM::Providers::Azure.new(config)
  end

  def decision(probability)
    { status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { model: model_id, answers: [{ type: 'predicate', name: 'urgent', probability: }],
              usage: { input_tokens: 40, output_tokens: 0 } }.to_json }
  end

  describe '#judgment_url' do
    it 'posts to the openai/v1 decisions endpoint from a resource, openai/v1, or deployment base' do
      urls = %w[
        https://res.openai.azure.com
        https://res.openai.azure.com/openai/v1
        https://res.openai.azure.com/openai/deployments/luna
      ].map { |base| described_class.new(provider_for(base)).judgment_url }

      expect(urls).to all(eq('https://res.openai.azure.com/openai/v1/decisions?api-version=v1'))
    end
  end

  it 'names the v1 API version over a dated one the configured base carries' do
    context = RubyLLM.context do |config|
      config.azure_api_base = 'https://res.openai.azure.com/openai/deployments/luna/chat/completions?api-version=2024-05-01-preview'
    end
    stub = stub_request(:post, 'https://res.openai.azure.com/openai/v1/decisions?api-version=v1').to_return(decision(0.9))

    context.judge('Please help today.', model: model_id, provider: :azure, questions:)

    expect(stub).to have_been_requested.once
  end

  it 'routes judgments to Decisions even when chat uses a configured protocol' do
    context = RubyLLM.context { |config| config.azure_protocol = :responses }
    stub = stub_request(:post, decisions_url)
           .with(headers: { 'api-key' => RubyLLM.config.azure_api_key }, body: {
                   model: model_id, input: 'Please help today.',
                   questions: [{ type: 'predicate', name: 'urgent', instructions: 'Does this need attention today?' }]
                 })
           .to_return(decision(0.9))

    result = context.judge('Please help today.', model: model_id, provider: :azure, questions:)

    expect(result.urgent.probability).to eq(0.9)
    expect(stub).to have_been_requested.once
  end

  it 'prices usage from the model registry' do
    stub_request(:post, decisions_url).to_return(decision(0.9))

    result = RubyLLM.judge('Please help today.', model: model_id, provider: :azure, questions:)

    registry_model = RubyLLM.models.find(model_id, provider: :azure)
    expect(result.tokens.input).to eq(40)
    expect(result.cost.total).to eq(RubyLLM::Cost.new(tokens: result.tokens, model: registry_model).total)
  end

  it 'reports normalized Azure errors' do
    stub_request(:post, decisions_url)
      .to_return(status: 401, body: { error: { code: '401', message: 'Access denied due to invalid subscription key' } }
                   .to_json, headers: { 'Content-Type' => 'application/json' })

    expect { RubyLLM.judge('Help', model: model_id, provider: :azure, questions:) }
      .to raise_error(RubyLLM::UnauthorizedError, 'Access denied due to invalid subscription key')
  end

  context 'with the Decisions API', :live do
    before { skip_without_cassette_or_key('AZURE_API_KEY') }

    it 'judges all three question types through the compact DSL' do
      id = model_id
      triage = Class.new(RubyLLM::Judge) do
        model id, provider: :azure
        probability :urgent, 'Does the customer explicitly need action today?'
        choice :department, 'Which team should handle this message?' do
          billing 'Payments and refunds'
          other nil
        end
        score :frustration, 'How frustrated is the customer?', ['Calm and polite', 'Angry or hostile']
      end

      result = triage.judge('I was charged twice. Please refund the duplicate charge today.')

      expect(result[:urgent].probability).to be_between(0, 1)
      expect(result[:department].probabilities.keys).to eq(%i[billing other])
      expect(result[:frustration].probabilities.keys).to eq([0, 1])
      expect(result.tokens.input).to be_positive
    end

    it 'judges an image without text input' do
      image_path = File.expand_path('../../../fixtures/ruby.png', __dir__)

      result = RubyLLM.judge(with: image_path, model: model_id, provider: :azure, questions: {
                               logo: { type: :probability, instructions: 'Is this image a logo?' }
                             })

      expect(result.logo.probability).to be_between(0, 1)
    end
  end
end
