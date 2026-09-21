# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::TypeSafe do
  include_context 'with configured RubyLLM'

  let(:model_id) { model_for(:typesafe, :judgment) }
  let(:questions) { { urgent: { type: :probability, instructions: 'Does this need attention today?' } } }

  it 'registers its configuration and authenticates with a bearer token' do
    config = RubyLLM::Configuration.new
    config.typesafe_api_key = 'test-key'
    config.typesafe_api_base = 'https://typesafe.example/v1-proxy'
    provider = described_class.new(config)

    expect(RubyLLM::Provider.resolve(:typesafe)).to eq(described_class)
    expect(provider.api_base).to eq('https://typesafe.example/v1-proxy')
    expect(provider.headers).to eq('Authorization' => 'Bearer test-key')
  end

  it 'uses the bundled catalog without requiring an explicit provider' do
    model = RubyLLM.models.find(model_id)

    expect(model.provider).to eq('typesafe')
    expect(model.type).to eq(:judgment)
    expect(model.supports?(:judgment)).to be(true)
    expect(RubyLLM.models.chat_models.map(&:id)).not_to include(model_id)
  end

  it 'retries overloads, resolving dynamic input once and accounting for both attempts' do
    calls = 0
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context do |config|
      config.max_retries = 1
      config.instrumenter = instrumenter
    end
    stub_request(:post, 'https://api.typesafe.ai/v1/systemone')
      .to_return(status: 529, body: { detail: 'Overloaded' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
      .then.to_return(status: 200, body: {
        model: model_id, answers: { urgent: { type: 'noul', noul: 0.9 } },
        usage: { input_tokens: 100, output_tokens: 10 }
      }.to_json, headers: { 'Content-Type' => 'application/json' })

    result = context.judge(lambda {
      calls += 1
      'Please help today.'
    }, model: model_id, questions:)

    expect(calls).to eq(1)
    expect(result.ruby_llm_usage_entries.map(&:status)).to eq(%i[failed succeeded])
    expect(result.tokens.input).to eq(100)
    expect(result.cost.total).to be_nil
    expect(instrumenter.events.count { |name, _| name == 'usage.ruby_llm' }).to eq(2)
  end

  it 'reports normalized errors through the shared transport' do
    stub_request(:post, 'https://api.typesafe.ai/v1/systemone')
      .to_return(status: 401, body: { detail: 'Invalid API key' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    expect { RubyLLM.judge('Help', model: model_id, questions:) }
      .to raise_error(RubyLLM::UnauthorizedError, 'Invalid API key')
  end

  it 'reports the message of a refusal rather than its JSON envelope' do
    refusal = { detail: { message: 'Your organization has no available TypeSafe API credits' } }
    stub_request(:post, 'https://api.typesafe.ai/v1/systemone')
      .to_return(status: 402, body: refusal.to_json, headers: { 'Content-Type' => 'application/json' })

    expect { RubyLLM.judge('Help', model: model_id, questions:) }
      .to raise_error(RubyLLM::PaymentRequiredError, 'Your organization has no available TypeSafe API credits')
  end

  context 'with the TypeSafe API', :live do
    before { skip_without_cassette_or_key('TYPESAFE_API_KEY') }

    it 'judges all three question types through the compact DSL' do
      id = model_id
      triage = Class.new(RubyLLM::Judge) do
        model id
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
      expect(result[:department].probabilities.keys).to contain_exactly(:billing, :technical, :other)
      expect(result[:frustration].score).to be_between(0, 2)
      expect(result[:frustration].probabilities.keys).to eq([0, 1, 2])
      expect(result.tokens.input).to be_positive
      expect(result.tokens.output).to be_positive
      expect(result.model).to start_with('jev-')
    end

    it 'preserves structured descriptions and arbitrary choice names' do
      definitions = {
        urgent: { type: :probability, instructions: { question: 'Is action needed today?' },
                  criteria: { yes: { deadline: 'today' }, no: ['No deadline', 'Later'] } },
        department: { type: :choice, instructions: ['Which team?', 'Pick the most relevant team'],
                      options: { 'Billing & payments' => { handles: %w[Charges Refunds] }, 'Other' => nil } },
        frustration: { type: :score, instructions: 'How frustrated is the customer?',
                       levels: [{ description: 'Calm and polite' }, ['Frustrated', 'Still civil'], 'Angry or hostile'] }
      }
      result = RubyLLM.judge(['Please refund the duplicate charge today.'], model: model_id, questions: definitions)

      expect(result[:department].choice).to be_in(['Billing & payments', 'Other'])
      expect(result[:frustration].levels).to eq(
        [{ 'description' => 'Calm and polite' }, ['Frustrated', 'Still civil'], 'Angry or hostile']
      )
    end

    it 'accepts omitted instructions when criteria describe the judgment' do
      result = RubyLLM.judge('Please refund my duplicate charge.', model: model_id, questions: {
                               department: { type: :choice,
                                             options: { billing: 'Payments and refunds', technical: 'Bugs' } },
                               urgent: { type: :probability, criteria: { yes: 'Needs action today', no: nil } }
                             })

      expect(result[:department].choice).to be_in(%i[billing technical])
      expect(result[:urgent].probability).to be_between(0, 1)
    end

    it 'lists the available judgment models' do
      models = described_class.new(RubyLLM.config).list_models

      expect(models.map(&:id)).to include(model_id)
      expect(models.map(&:type).uniq).to eq([:judgment])
    end
  end
end
