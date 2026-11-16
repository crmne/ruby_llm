# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Gemini do
  include_context 'with configured RubyLLM'

  let(:model_id) { model_for(:gemini, :judgment) }
  let(:image_path) { File.expand_path('../../fixtures/ruby.png', __dir__) }
  let(:questions) { { urgent: { type: :probability, instructions: 'Does this need attention today?' } } }
  let(:endpoint) { 'https://generativelanguage.googleapis.com/v1beta/decisions' }

  it 'routes judgments through the Gemini connection and accounts for input usage' do
    stub = stub_request(:post, endpoint)
           .with(headers: { 'x-goog-api-key' => RubyLLM.config.gemini_api_key }, body: {
                   model: "models/#{model_id}", input: 'Help today.',
                   questions: { urgent: { type: 'noul', instructions: 'Does this need attention today?' } }
                 })
           .to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: {
             answers: { urgent: { type: 'noul', noul: 0.9, confidence: 0.9 } }, usage: { total_input_tokens: 40 }
           }.to_json)

    result = RubyLLM.judge('Help today.', model: model_id, provider: :gemini, questions:)

    expect(result.urgent.probability).to eq(0.9)
    expect(result.model).to eq(model_id)
    expect(result.tokens.to_h).to eq(input_tokens: 40, output_tokens: 0)
    registry_model = RubyLLM.models.find(model_id, provider: :gemini)
    expect(result.cost.total).to eq(RubyLLM::Cost.new(tokens: result.tokens, model: registry_model).total)
    expect(stub).to have_been_requested.once
  end

  it 'preserves the configured base URL and normalizes HTTP errors' do
    context = RubyLLM.context { |config| config.gemini_api_base = 'https://gemini.example.com/v1beta' }
    stub = stub_request(:post, 'https://gemini.example.com/v1beta/decisions')
           .to_return(status: 401, headers: { 'Content-Type' => 'application/json' },
                      body: { error: { message: 'Invalid API key' } }.to_json)

    expect { context.judge('Help', model: model_id, provider: :gemini, questions:) }
      .to raise_error(RubyLLM::UnauthorizedError, 'Invalid API key')
    expect(stub).to have_been_requested.once
  end

  it 'normalizes HTTP 400 safety blocks without losing error details' do
    context = RubyLLM.context { |config| config.redact_error_messages = true }
    %w[safety prohibited_content blocklist image_safety content_blocked].each do |code|
      stub = stub_request(:post, endpoint)
             .with(body: hash_including('input' => code))
             .to_return(status: 400, headers: { 'Content-Type' => 'application/json' },
                        body: { error: { code:, message: 'Blocked private input' } }.to_json)

      expect { context.judge(code, model: model_id, provider: :gemini, questions:) }
        .to raise_error(RubyLLM::ContentFilterError) do |error|
          expect(error.response.status).to eq(400)
          expect(error.provider).to eq('gemini')
          expect(error.error_code).to eq(code)
          expect(error.provider_message).to eq('Blocked private input')
          expect(error.message).not_to include('Blocked private input')
        end
      expect(stub).to have_been_requested.once
    end
  end

  it 'keeps other HTTP 400 errors as bad requests' do
    stub_request(:post, endpoint)
      .to_return(status: 400, headers: { 'Content-Type' => 'application/json' },
                 body: { error: { code: 'invalid_argument', message: 'Too many questions' } }.to_json)

    expect { RubyLLM.judge('Help', model: model_id, provider: :gemini, questions:) }
      .to raise_error(RubyLLM::BadRequestError, 'Too many questions')
  end

  it 'records billed usage when the answers cannot be parsed' do
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = instrumenter }
    stub_request(:post, endpoint).to_return(
      status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { answers: {}, usage: { total_input_tokens: 80 } }.to_json
    )

    expect { context.judge('Help', model: model_id, provider: :gemini, questions:) }
      .to raise_error(RubyLLM::Error, /invalid judgment/)
    usage = instrumenter.events.filter_map { |name, payload| payload if name == 'usage.ruby_llm' }.sole
    expect(usage).to include(operation: :judgment, status: :failed)
    expect(usage[:tokens].to_h).to eq(input_tokens: 80, output_tokens: 0)
  end

  it 'records billed usage when input is blocked' do
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = instrumenter }
    stub_request(:post, endpoint).to_return(
      status: 200, headers: { 'Content-Type' => 'application/json' },
      body: { prompt_feedback: { block_reason: 'SAFETY' }, usage: { total_input_tokens: 50 } }.to_json
    )

    expect { context.judge('Help', model: model_id, provider: :gemini, questions:) }
      .to raise_error(RubyLLM::ContentFilterError, /SAFETY/)
    usage = instrumenter.events.filter_map { |name, payload| payload if name == 'usage.ruby_llm' }.sole
    expect(usage).to include(operation: :judgment, status: :failed)
    expect(usage[:tokens].to_h).to eq(input_tokens: 50, output_tokens: 0)
  end

  context 'with the Decisions API', :live do
    before { skip_without_cassette_or_key('GEMINI_API_KEY') }

    it 'judges all three question types through the compact DSL' do
      id = model_id
      triage = Class.new(RubyLLM::Judge) do
        model id, provider: :gemini
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

      expect(result.urgent.probability).to be_between(0.01, 0.99)
      expect(result.department.choice).to be_in(%i[billing technical other])
      expect(result.department.probabilities.keys).to eq(%i[billing technical other])
      expect(result.frustration.score).to be_between(0, 2)
      expect(result.frustration.probabilities.keys).to eq([0, 1, 2])
      expect(result.tokens.input).to be_positive
      expect(result.tokens.output).to eq(0)
      expect(result.model).to eq(model_id)
    end

    it 'judges an image without text input' do
      result = RubyLLM.judge(with: image_path, model: model_id, provider: :gemini, questions: {
                               logo: { type: :probability, instructions: 'Is this image a logo?' },
                               color: { type: :choice, instructions: 'What is the dominant color?',
                                        options: { red: nil, blue: nil, green: nil } },
                               complexity: { type: :score, instructions: 'How complex is this image?',
                                             levels: ['Simple shape', 'Several shapes', 'Detailed scene'] }
                             })

      expect(result.logo.probability).to be_between(0.01, 0.99)
      expect(result.color.choice).to be_in(%i[red blue green])
      expect(result.complexity.score).to be_between(0, 2)
      expect(result.tokens.input).to be_positive
    end
  end
end
