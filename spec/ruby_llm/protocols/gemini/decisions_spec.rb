# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Decisions do
  include_context 'with configured RubyLLM'

  let(:model) { RubyLLM.models.find(model_for(:gemini, :judgment), provider: :gemini) }
  let(:protocol) { described_class.new(RubyLLM::Providers::Gemini.new(RubyLLM.config), model) }
  let(:questions) do
    {
      'urgent' => RubyLLM::Judge::Question.new(:urgent, type: :probability, instructions: 'Is this urgent?'),
      'team' => RubyLLM::Judge::Question.new('team', type: :choice, instructions: 'Which team?',
                                                     criteria: { 'Billing & payments' => nil, other: 'Other' }),
      'severity' => RubyLLM::Judge::Question.new(:severity, type: :score, instructions: 'How severe?',
                                                            criteria: %w[Minor Major])
    }.transform_values { |question| question.resolve(RubyLLM::Judge.new) }
  end
  let(:body) do
    {
      'answers' => {
        'severity' => { 'type' => 'score', 'score' => 0.2, 'confidence' => 0.8,
                        'legend' => { '1' => 'Major', '0' => 'Minor' },
                        'probabilities' => { '1' => 0.2, '0' => 0.8 } },
        'team' => { 'type' => 'choice', 'choice' => 'Billing & payments', 'confidence' => 0.9,
                    'probabilities' => { 'other' => 0.1, 'Billing & payments' => 0.9 } },
        'urgent' => { 'type' => 'noul', 'noul' => 0.9, 'confidence' => 0.9 }
      },
      'usage' => { 'total_input_tokens' => 120 }
    }
  end
  let(:response) { instance_double(Faraday::Response, body:) }

  def render(input = 'Help', questions: self.questions, **options)
    protocol.render_judgment_payload(input, questions:, model: model.id, **options)
  end

  it 'renders named questions with the Decisions vocabulary' do
    expect(render).to eq(
      model: "models/#{model.id}", input: 'Help', questions: {
        'urgent' => { type: 'noul', instructions: 'Is this urgent?' },
        'team' => { type: 'choice', instructions: 'Which team?',
                    criteria: { 'Billing & payments' => '', 'other' => 'Other' } },
        'severity' => { type: 'score', instructions: 'How severe?', criteria: %w[Minor Major] }
      }
    )
  end

  it 'sends structured input and question descriptions as JSON text' do
    question = RubyLLM::Judge::Question.new(:team, type: :choice, instructions: { ask: 'Which team?' },
                                                   criteria: { billing: { handles: %w[Refunds] }, other: nil })
    payload = render({ message: 'Help' }, questions: { 'team' => question })

    expect(payload[:input]).to eq('{"message":"Help"}')
    expect(payload[:questions]['team']).to include(
      instructions: '{"ask":"Which team?"}', criteria: { 'billing' => '{"handles":["Refunds"]}', 'other' => '' }
    )
    expect(render(%w[Help Now])[:input]).to eq('["Help","Now"]')
  end

  it 'maps yes/no criteria and structured score levels to the native format' do
    probability = RubyLLM::Judge::Question.new(:urgent, type: :probability,
                                                        criteria: { yes: { deadline: 'today' }, 'false' => nil })
    score = RubyLLM::Judge::Question.new(:severity, type: :score, criteria: ['Minor', %w[Major Blocking]])
    payload = render(questions: { 'urgent' => probability, 'severity' => score })

    expect(payload[:questions]['urgent'][:criteria])
      .to eq('true_description' => '{"deadline":"today"}', 'false_description' => '')
    expect(payload[:questions]['severity'][:criteria]).to eq(['Minor', '["Major","Blocking"]'])
  end

  it 'maps true/false aliases to probability descriptions without changing choice option names' do
    probability = RubyLLM::Judge::Question.new(:urgent, type: :probability,
                                                        criteria: { 'true' => 'Today', no: 'Later' })
    choice = RubyLLM::Judge::Question.new(:answer, type: :choice,
                                                   criteria: { 'true' => 'Correct', 'false' => 'Incorrect' })
    payload = render(questions: { 'urgent' => probability, 'answer' => choice })

    expect(payload[:questions]['urgent'][:criteria])
      .to eq('true_description' => 'Today', 'false_description' => 'Later')
    expect(payload[:questions]['answer'][:criteria]).to eq('true' => 'Correct', 'false' => 'Incorrect')
  end

  it 'sends inline images with optional text' do
    image_path = File.expand_path('../../../fixtures/ruby.png', __dir__)
    image = RubyLLM::Attachment.new(image_path)
    image_part = { type: 'image', mime_type: 'image/png', data: Base64.strict_encode64(File.binread(image_path)) }

    expect(render('Classify this', with: [image])[:input]).to eq([{ type: 'text', text: 'Classify this' }, image_part])
    expect(render(nil, with: [image])[:input]).to eq([image_part])
    expect(render('', with: [image])[:input]).to eq([image_part])
  end

  it 'preserves image resolution and maps original to the highest resolution' do
    image_path = File.expand_path('../../../fixtures/ruby.png', __dir__)
    %i[low medium high ultra_high original].each do |resolution|
      image = RubyLLM::Attachment.new(image_path, resolution:)
      expected = resolution == :original ? 'ultra_high' : resolution.to_s

      expect(render(nil, with: [image])[:input].first[:resolution]).to eq(expected)
    end
  end

  it 'uses image URLs and uploaded file URIs without downloading the bytes' do
    uri = 'https://generativelanguage.googleapis.com/v1beta/files/receipt'
    uploaded = RubyLLM::Attachment.new(
      RubyLLM::UploadedFile.new(id: 'files/receipt', uri:, filename: 'receipt.png', mime_type: 'image/png')
    )
    remote = RubyLLM::Attachment.new('https://example.com/image.png', mime_type: 'image/png')

    expect(render(nil, with: [uploaded, remote])[:input]).to eq(
      [{ type: 'image', mime_type: 'image/png', uri: },
       { type: 'image', mime_type: 'image/png', uri: 'https://example.com/image.png' }]
    )
  end

  it 'sends audio, video, and PDFs as their own parts, and text files as text' do
    files = { 'ruby.wav' => 'audio', 'ruby.mp4' => 'video', 'sample.pdf' => 'document' }.map do |name, type|
      [RubyLLM::Attachment.new(File.expand_path("../../../fixtures/#{name}", __dir__)), type]
    end
    notes = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.txt', __dir__))

    input = render(nil, with: files.map(&:first) + [notes])[:input]

    expect(input.first(3)).to eq(files.map do |file, type|
      { type:, mime_type: file.mime_type, data: file.encoded }
    end)
    expect(input.last).to eq(type: 'text', text: notes.content)
  end

  it 'keeps resolution for images only' do
    video = RubyLLM::Attachment.new(File.expand_path('../../../fixtures/ruby.mp4', __dir__), resolution: :low)

    expect(render(nil, with: [video])[:input].first).not_to have_key(:resolution)
  end

  it 'rejects attachments the Decisions API has no part for' do
    archive = RubyLLM::Attachment.new('https://example.com/files.zip', mime_type: 'application/zip')

    expect { render(with: [archive]) }.to raise_error(RubyLLM::UnsupportedAttachmentError, %r{application/zip})
  end

  it 'leaves question limits and missing instructions to the API' do
    choice = RubyLLM::Judge::Question.new(:team, type: :choice, criteria: { only: nil })
    bare = RubyLLM::Judge::Question.new(:urgent, type: :probability)

    expect(render(questions: { 'team' => choice })[:questions]['team'][:criteria]).to eq('only' => '')
    expect(render(questions: { 'urgent' => bare })[:questions]['urgent']).to eq(type: 'noul')
  end

  it 'prevents provider options from replacing model, input, or questions' do
    %w[model input questions].each do |key|
      [key, key.to_sym].each do |name|
        expect { render(provider_options: { name => {} }) }.to raise_error(ArgumentError, /#{key}/)
      end
    end
    expect(render(provider_options: { extra: true })[:extra]).to be(true)
  end

  it 'matches reordered answers to declared question and option names' do
    judgment = protocol.parse_judgment_response(response, questions:)

    expect(judgment.answers.keys).to eq([:urgent, 'team', :severity])
    expect(judgment.urgent.probability).to eq(0.9)
    expect(judgment.urgent).not_to respond_to(:confidence)
    expect(judgment.team.choice).to eq('Billing & payments')
    expect(judgment.team.probabilities).to eq('Billing & payments' => 0.9, other: 0.1)
    expect(judgment.team.confidence).to eq(0.9)
    expect(judgment.severity.score).to eq(0.2)
    expect(judgment.severity.levels).to eq(%w[Minor Major])
    expect(judgment.severity.probabilities).to eq(0 => 0.8, 1 => 0.2)
    expect(judgment.severity.confidence).to eq(0.8)
    expect(judgment.model).to eq(model.id)
    expect(judgment.raw).to equal(response)
    expect(judgment.tokens.to_h).to eq(input_tokens: 120, output_tokens: 0)
  end

  it 'preserves structured score levels through the request and response' do
    levels = ['Minor', { 'impact' => 'Outage' }, %w[Major Blocking]]
    question = RubyLLM::Judge::Question.new(:severity, type: :score, criteria: levels)
    score_questions = { 'severity' => question.resolve(RubyLLM::Judge.new) }

    expect(render(questions: score_questions)[:questions]['severity'][:criteria])
      .to eq(['Minor', '{"impact":"Outage"}', '["Major","Blocking"]'])

    body['answers'] = {
      'severity' => { 'type' => 'score', 'score' => 0.5, 'confidence' => 0.8,
                      'legend' => { '2' => '["Major","Blocking"]', '0' => 'Minor', '1' => '{"impact":"Outage"}' },
                      'probabilities' => { '2' => 0.1, '0' => 0.6, '1' => 0.3 } }
    }
    result = protocol.parse_judgment_response(response, questions: score_questions).severity

    expect(result.levels).to eq(levels)
    expect(result.score).to eq(0.5)
    expect(result.probabilities).to eq(0 => 0.6, 1 => 0.3, 2 => 0.1)
    expect(result.confidence).to eq(0.8)
  end

  it 'preserves unknown input usage' do
    body.delete('usage')

    expect(protocol.parse_judgment_response(response, questions:).tokens.to_h).to eq(output_tokens: 0)
  end

  it 'normalizes malformed responses and answers that cannot map to their questions' do
    changes = [
      -> { body.delete('answers') },
      -> { body['answers'].delete('urgent') },
      -> { body['answers']['urgent'] = { 'type' => 'choice', 'choice' => 'other' } },
      -> { body['answers']['team']['choice'] = 'unknown' },
      -> { body['answers']['team']['probabilities'].delete('other') },
      -> { body['answers']['severity']['probabilities'].delete('0') },
      -> { body['answers'] = [] }
    ]
    original = JSON.generate(body)
    changes.each do |change|
      body.replace(JSON.parse(original))
      change.call
      expect { protocol.parse_judgment_response(response, questions:) }
        .to raise_error(RubyLLM::Error, /Gemini Decisions returned an invalid judgment/) do |error|
          expect(error.response).to equal(response)
        end
    end
  end
end
