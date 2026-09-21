# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::SystemOne do
  include_context 'with configured RubyLLM'

  let(:model) { RubyLLM::Model.new(id: model_for(:typesafe, :judgment), provider: 'typesafe') }
  let(:protocol) { Object.new.extend(described_class::Judgments, described_class::Responses, described_class::Models) }
  let(:questions) do
    {
      'urgent' => RubyLLM::Judge::Question.new(:urgent, type: :probability),
      'team' => RubyLLM::Judge::Question.new('team', type: :choice,
                                                     criteria: { 'Billing & payments' => nil, other: 'Other' }),
      'severity' => RubyLLM::Judge::Question.new(:severity, type: :score, criteria: ['Minor', %w[Major Blocking]])
    }.transform_values { |question| question.resolve(RubyLLM::Judge.new) }
  end
  let(:body) do
    {
      'model' => 'jev-1.13.0',
      'answers' => {
        'urgent' => { 'type' => 'noul', 'noul' => 0.9 },
        'team' => { 'type' => 'choice', 'choice' => 'Billing & payments', 'confidence' => 0.8,
                    'probabilities' => { 'Billing & payments' => 0.9, 'other' => 0.1 } },
        'severity' => { 'type' => 'score', 'score' => 0.1, 'confidence' => 0.8,
                        'legend' => { '1' => %w[Major Blocking], '0' => 'Minor' },
                        'probabilities' => { '1' => 0.1, '0' => 0.9 } }
      },
      'usage' => { 'input_tokens' => 100, 'output_tokens' => 20 }
    }
  end
  let(:response) { instance_double(Faraday::Response, body:) }

  it 'renders normalized questions with the native request vocabulary' do
    payload = protocol.send(:render_judgment_payload, { message: 'Help' }, questions:, model: model.id)

    expect(payload[:state]).to eq(message: 'Help')
    expect(payload[:questions]['urgent']).to eq(type: 'noul')
    expect(payload[:questions]['team']).to eq(type: 'choice', criteria: { 'Billing & payments' => nil, other: 'Other' })
  end

  it 'maps yes/no descriptions to the native boolean criteria' do
    question = RubyLLM::Judge::Question.new(:urgent, type: :probability,
                                                     criteria: { yes: { deadline: 'today' }, no: nil })

    expect(protocol.send(:render_question, question)[:criteria]).to eq('true' => { deadline: 'today' }, 'false' => nil)
  end

  it 'enforces provider limits without putting them in the domain' do
    choice = RubyLLM::Judge::Question.new(:team, type: :choice, criteria: 256.times.to_h { |n| [n.to_s, nil] })
    score = RubyLLM::Judge::Question.new(:score, type: :score, criteria: Array.new(11, 'A level'))

    expect { protocol.send(:render_question, choice) }.to raise_error(ArgumentError, /255/)
    expect { protocol.send(:render_question, score) }.to raise_error(ArgumentError, /10/)
  end

  it 'prevents provider options from replacing the questions, model, or input behind the parser' do
    %w[questions state model].each do |key|
      expect do
        protocol.send(:render_judgment_payload, 'Help', questions:, model: model.id, provider_options: { key => {} })
      end.to raise_error(ArgumentError, /judgment arguments/)
    end
  end

  it 'parses all result fields and preserves declared key types' do
    result = protocol.send(:parse_judgment_response, response, questions:)

    expect(result.model).to eq('jev-1.13.0')
    expect(result.raw).to equal(response)
    expect(result[:team].choice).to eq('Billing & payments')
    expect(result[:team].probabilities).to eq('Billing & payments' => 0.9, other: 0.1)
    expect(result[:severity].levels).to eq(['Minor', %w[Major Blocking]])
    expect(result[:severity].probabilities.keys).to eq([0, 1])
    expect(result.tokens.output).to eq(20)
  end

  it 'rejects missing and unexpected answers rather than returning partial results' do
    body['answers'].delete('urgent')

    expect { protocol.send(:parse_judgment_response, response, questions:) }
      .to raise_error(RubyLLM::Error, /different question IDs/)
  end

  it 'rejects incorrect answer types, out-of-range probabilities, and unrecognized options' do
    modifications = [
      -> { body['answers']['urgent']['type'] = 'choice' },
      -> { body['answers']['urgent']['noul'] = 1.1 },
      -> { body['answers']['team']['choice'] = 'unknown' },
      -> { body['answers']['team']['confidence'] = '0.9' },
      -> { body['answers']['severity']['score'] = -1 },
      -> { body['answers']['severity']['legend'].delete('0') }
    ]
    original = JSON.generate(body)
    modifications.each do |change|
      body.replace(JSON.parse(original))
      change.call
      expect { protocol.send(:parse_judgment_response, response, questions:) }.to raise_error(RubyLLM::Error) do |error|
        expect(error.response).to equal(response)
      end
    end
  end

  it 'preserves unknown usage rather than replacing it with zero' do
    body['usage'] = {}

    expect(protocol.send(:parse_judgment_response, response, questions:).tokens.input).to be_nil
  end

  it 'normalizes validation error details' do
    error_response = instance_double(Faraday::Response, body: {
                                       'detail' => [{ 'loc' => %w[body questions urgent], 'msg' => 'Invalid question' }]
                                     })

    provider = RubyLLM::Providers::TypeSafe.new(RubyLLM.config)
    expect(provider.parse_error(error_response)).to eq('body.questions.urgent: Invalid question')
  end

  it 'reads the message of an error detail object' do
    detail = { 'message' => 'Your organization has no available TypeSafe API credits' }
    error_response = instance_double(Faraday::Response, body: { 'detail' => detail })

    provider = RubyLLM::Providers::TypeSafe.new(RubyLLM.config)
    expect(provider.parse_error(error_response)).to eq('Your organization has no available TypeSafe API credits')
  end

  it 'passes an error detail string through' do
    error_response = instance_double(Faraday::Response, body: { 'detail' => 'Overloaded' })

    provider = RubyLLM::Providers::TypeSafe.new(RubyLLM.config)
    expect(provider.parse_error(error_response)).to eq('Overloaded')
  end

  it 'parses catalog facts without inventing limits or pricing' do
    catalog = instance_double(Faraday::Response, body: {
                                'models' => [{ 'name' => model.id, 'description' => 'System One model',
                                               'release_date' => '2026-09-10T18:38:01Z' }]
                              })
    entry = protocol.send(:parse_list_models_response, catalog, 'typesafe').first

    expect(entry.id).to eq(model.id)
    expect(entry.type).to eq(:judgment)
    expect(entry.supports?(:judgment)).to be(true)
    expect(entry.context_window).to be_nil
    expect(entry.pricing.to_h).to eq({})
  end
end
