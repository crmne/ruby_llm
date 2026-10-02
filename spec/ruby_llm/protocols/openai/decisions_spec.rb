# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::OpenAI::Decisions do
  include_context 'with configured RubyLLM'

  let(:model) { RubyLLM::Model.new(id: model_for(:openai, :judgment), provider: 'openai') }
  let(:protocol) { described_class.new(RubyLLM::Providers::OpenAI.new(RubyLLM.config), model) }
  let(:questions) do
    {
      'urgent' => RubyLLM::Judge::Question.new(:urgent, type: :probability, instructions: 'Is this urgent?'),
      'team' => RubyLLM::Judge::Question.new('team', type: :choice, instructions: 'Which team?',
                                                     criteria: { 'Billing & payments' => nil, other: 'Other' }),
      'severity' => RubyLLM::Judge::Question.new(:severity, type: :score, instructions: 'How severe?',
                                                            criteria: ['Minor', %w[Major Blocking]])
    }.transform_values { |question| question.resolve(RubyLLM::Judge.new) }
  end
  let(:body) do
    {
      'model' => 'gpt-6-luna-2026-09-22',
      'answers' => [
        { 'type' => 'predicate', 'name' => 'urgent', 'probability' => 0.9 },
        { 'type' => 'choice', 'name' => 'team', 'choice' => 'Billing & payments', 'confidence' => 0.8,
          'probabilities' => [{ 'value' => 'other', 'probability' => 0.1 },
                              { 'value' => 'Billing & payments', 'probability' => 0.9 }] },
        { 'type' => 'score', 'name' => 'severity', 'score' => 0.2, 'confidence' => 0.7,
          'probabilities' => [{ 'value' => 0, 'label' => '0', 'probability' => 0.8 },
                              { 'value' => 1, 'label' => '1', 'probability' => 0.2 }] }
      ],
      'usage' => { 'input_tokens' => 120, 'output_tokens' => 3, 'input_tokens_details' => { 'cached_tokens' => 20 } }
    }
  end
  let(:response) { instance_double(Faraday::Response, body:) }

  def render(input = 'Help', questions: self.questions, **options)
    protocol.render_judgment_payload(input, questions:, model: model.id, **options)
  end

  it 'renders ordered questions with the Decisions vocabulary' do
    payload = render

    expect(payload[:model]).to eq('gpt-6-luna')
    expect(payload[:input]).to eq('Help')
    expect(payload[:questions]).to eq(
      [
        { type: 'predicate', name: 'urgent', instructions: 'Is this urgent?' },
        { type: 'choice', name: 'team', instructions: 'Which team?',
          choices: [{ value: 'Billing & payments' }, { value: 'other', description: 'Other' }] },
        { type: 'score', name: 'severity', instructions: 'How severe?',
          levels: [{ label: '0', description: 'Minor' }, { label: '1', description: '["Major","Blocking"]' }] }
      ]
    )
  end

  it 'sends structured input and descriptions as JSON text' do
    question = RubyLLM::Judge::Question.new(:team, type: :choice, instructions: { ask: 'Which team?' },
                                                   criteria: { billing: { handles: %w[Refunds] }, other: nil })

    payload = render({ message: 'Help' }, questions: { 'team' => question })

    expect(payload[:input]).to eq('{"message":"Help"}')
    expect(payload[:questions].first).to include(
      instructions: '{"ask":"Which team?"}',
      choices: [{ value: 'billing', description: '{"handles":["Refunds"]}' }, { value: 'other' }]
    )
  end

  it 'adds yes and no descriptions to the predicate instructions' do
    question = RubyLLM::Judge::Question.new(:urgent, type: :probability, instructions: 'Is this urgent?',
                                                     criteria: { yes: 'A deadline today', 'false' => nil })
    implicit = RubyLLM::Judge::Question.new(:urgent, type: :probability, criteria: { no: 'No deadline' })

    expect(render(questions: { 'urgent' => question })[:questions].first[:instructions])
      .to eq("Is this urgent?\nYes: A deadline today")
    expect(render(questions: { 'urgent' => implicit })[:questions].first[:instructions]).to eq('No: No deadline')
  end

  it 'sends images inline in a message with the input text' do
    path = File.expand_path('../../../fixtures/ruby.png', __dir__)
    data_uri = "data:image/png;base64,#{Base64.strict_encode64(File.binread(path))}"
    image = RubyLLM::Attachment.new(path)

    expect(render('Classify this page', with: [image])[:input]).to eq(
      [{ type: 'message', role: 'user',
         content: [{ type: 'input_text', text: 'Classify this page' }, { type: 'input_image', image_url: data_uri }] }]
    )
    expect(render(nil, with: [image])[:input].first[:content]).to eq([{ type: 'input_image', image_url: data_uri }])
    expect(render('', with: [image])[:input].first[:content]).to eq([{ type: 'input_image', image_url: data_uri }])
    expect(render(nil, with: [RubyLLM::Attachment.new(path, resolution: :low)])[:input].first[:content])
      .to eq([{ type: 'input_image', image_url: data_uri, detail: 'low' }])
    expect(render(nil, with: [RubyLLM::Attachment.new(path, resolution: :original)])[:input].first[:content])
      .to eq([{ type: 'input_image', image_url: data_uri, detail: 'original' }])
  end

  it 'downloads image URLs to send them inline' do
    stub_request(:get, 'https://example.com/receipt.png')
      .to_return(status: 200, body: 'png', headers: { 'Content-Type' => 'image/png' })

    expect(render(nil, with: [RubyLLM::Attachment.new('https://example.com/receipt.png')])[:input].first[:content])
      .to eq([{ type: 'input_image', image_url: "data:image/png;base64,#{Base64.strict_encode64('png')}" }])
  end

  it 'sends uploaded images by file ID and rejects attachments Decisions cannot express' do
    uploaded = RubyLLM::Attachment.new(
      RubyLLM::UploadedFile.new(id: 'file-123', filename: 'receipt.png', mime_type: 'image/png')
    )
    document = RubyLLM::Attachment.new('https://example.com/contract.pdf')

    expect(render(nil, with: [uploaded])[:input].first[:content]).to eq([{ type: 'input_image', file_id: 'file-123' }])
    expect { render(with: [document]) }.to raise_error(RubyLLM::UnsupportedAttachmentError, %r{application/pdf})
  end

  it 'leaves question limits and missing instructions to the API' do
    many = 65.times.to_h do |n|
      [n.to_s, RubyLLM::Judge::Question.new(n.to_s, type: :probability, instructions: 'Is this urgent?')]
    end
    single = RubyLLM::Judge::Question.new(:team, type: :choice, instructions: 'Which team?', criteria: { a: nil })
    bare = RubyLLM::Judge::Question.new(:urgent, type: :probability)

    expect(render(questions: many)[:questions].size).to eq(65)
    expect(render(questions: { 'team' => single })[:questions].first[:choices]).to eq([{ value: 'a' }])
    expect(render(questions: { 'urgent' => bare })[:questions]).to eq([{ type: 'predicate', name: 'urgent' }])
  end

  it 'prevents provider options from replacing the questions, model, or input behind the parser' do
    %w[questions input model].each do |key|
      expect { render(provider_options: { key => {} }) }.to raise_error(ArgumentError, /#{key}/)
    end
    expect(render(provider_options: { service_tier: 'flex' })[:service_tier]).to eq('flex')
  end

  it 'parses answers in question order into declared names and option types' do
    judgment = protocol.parse_judgment_response(response, questions:)

    expect(judgment.answers.keys).to eq([:urgent, 'team', :severity])
    expect(judgment[:urgent].probability).to eq(0.9)
    expect(judgment['team'].choice).to eq('Billing & payments')
    expect(judgment['team'].probabilities).to eq('Billing & payments' => 0.9, other: 0.1)
    expect(judgment[:severity].score).to eq(0.2)
    expect(judgment[:severity].levels).to eq(['Minor', %w[Major Blocking]])
    expect(judgment[:severity].probabilities).to eq(0 => 0.8, 1 => 0.2)
    expect(judgment.model).to eq('gpt-6-luna-2026-09-22')
    expect([judgment.tokens.input, judgment.tokens.output, judgment.tokens.cache_read]).to eq([100, 3, 20])
  end

  it 'records reasoning tokens and tolerates missing usage' do
    reasoning = body.merge('usage' => body['usage'].merge('output_tokens_details' => { 'reasoning_tokens' => 2 }))
    parse = ->(parsed) { protocol.parse_judgment_response(instance_double(Faraday::Response, body: parsed), questions:) }

    expect(parse.call(reasoning).tokens.thinking).to eq(2)
    expect(parse.call(body.except('usage')).tokens.input).to be_nil
  end

  it 'turns a malformed body into a RubyLLM error' do
    invalid = [
      'Internal error',
      body.except('answers'),
      body.except('model'),
      body.merge('answers' => body['answers'].take(2)),
      body.merge('answers' => [body['answers'][0], body['answers'][1].merge('choice' => 'sales'), body['answers'][2]])
    ]

    invalid.each do |invalid_body|
      expect do
        protocol.parse_judgment_response(instance_double(Faraday::Response, body: invalid_body), questions:)
      end.to raise_error(RubyLLM::Error, /OpenAI Decisions returned an invalid judgment/)
    end
  end
end
