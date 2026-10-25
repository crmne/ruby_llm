# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenRouter::Judgments do
  include_context 'with configured RubyLLM'

  let(:model_id) { model_for(:openrouter, :judgment) }
  let(:protocol) do
    provider = RubyLLM::Providers::OpenRouter.new(RubyLLM.config)
    RubyLLM::Providers::OpenRouter::SystemOne.new(provider, RubyLLM::Model.new(id: model_id, provider: 'openrouter'))
  end
  let(:questions) { { urgent: { type: :probability, instructions: 'Does this need attention today?' } } }
  let(:question_objects) do
    { 'urgent' => RubyLLM::Judge::Question.new(:urgent, type: :probability, instructions: 'Urgent?') }
  end
  let(:fixtures) { File.expand_path('../../../fixtures', __dir__) }

  def render(input, with: [], provider_options: {})
    protocol.send(:render_judgment_payload, input, questions: question_objects, model: model_id, with:,
                                                   provider_options:)
  end

  it 'routes judgments through System One and chats through Chat Completions' do
    provider = RubyLLM::Providers::OpenRouter.new(RubyLLM.config)

    expect(provider.resolve_protocol(nil, nil, operation: :judge)).to eq(RubyLLM::Providers::OpenRouter::SystemOne)
    expect(provider.resolve_protocol(nil, nil).ancestors).to include(RubyLLM::Providers::OpenRouter::ChatCompletions)
  end

  it 'judges through Decisions even when chat uses a configured protocol, keeping the reported cost' do
    context = RubyLLM.context { |config| config.openrouter_protocol = :responses }
    stub = stub_request(:post, 'https://openrouter.ai/api/alpha/decisions')
           .with(headers: { 'Authorization' => "Bearer #{RubyLLM.config.openrouter_api_key}" }, body: {
                   model: model_id, state: 'Please help today.',
                   questions: { urgent: { type: 'noul', instructions: 'Does this need attention today?' } }
                 })
           .to_return(status: 200, headers: { 'Content-Type' => 'application/json' }, body: {
             model: 'typesafe/jev-1.14-20261014', answers: { urgent: { type: 'noul', noul: 0.9 } },
             usage: { input_tokens: 40, output_tokens: 1, cost: 0.00001 }
           }.to_json)

    result = context.judge('Please help today.', model: model_id, provider: :openrouter,
                                                 assume_model_exists: true, questions:)

    expect(result.urgent.probability).to eq(0.9)
    expect(result.model).to eq('typesafe/jev-1.14-20261014')
    expect(result.tokens.input).to eq(40)
    expect(result.tokens.reported_cost).to eq(0.00001)
    expect(result.cost.total).to eq(0.00001)
    expect(stub).to have_been_requested.once
  end

  it 'puts media in the state array as content parts' do
    image = RubyLLM::Attachment.new(File.join(fixtures, 'ruby.png'), resolution: :low)
    audio = RubyLLM::Attachment.new(File.join(fixtures, 'ruby.mp3'))
    video = RubyLLM::Attachment.new(File.join(fixtures, 'ruby_clip.mp4'))
    audio_part = { type: 'input_audio', input_audio: { data: audio.encoded, format: 'mp3' } }

    payload = render('Look', with: [image, audio, video])

    expect(payload[:state]).to eq(
      ['Look', { type: 'image_url', image_url: { url: image.for_llm, detail: 'low' } }, audio_part,
       { type: 'video_url', video_url: { url: video.for_llm } }]
    )
    expect(payload[:questions]['urgent']).to eq(type: 'noul', instructions: 'Urgent?')
    expect(payload).not_to have_key(:images)
    expect(render('Help')[:state]).to eq('Help')
    expect(render(%w[a b], with: [audio])[:state]).to eq(['a', 'b', audio_part])
    expect(render(nil, with: [RubyLLM::Attachment.new(File.join(fixtures, 'ruby.png'))])[:state])
      .to eq([{ type: 'image_url', image_url: { url: image.for_llm } }])
    expect(render('Help', provider_options: { session_id: 'ticket-1' })[:session_id]).to eq('ticket-1')
  end

  it 'inlines remote images and videos, which Decisions models accept only as data URLs' do
    png = File.binread(File.join(fixtures, 'ruby.png'))
    mp4 = File.binread(File.join(fixtures, 'ruby_clip.mp4'))
    stub_request(:get, 'https://example.com/ruby.png').to_return(body: png, headers: { 'Content-Type' => 'image/png' })
    stub_request(:get, 'https://example.com/clip.mp4').to_return(body: mp4, headers: { 'Content-Type' => 'video/mp4' })

    state = render('Look', with: [RubyLLM::Attachment.new('https://example.com/ruby.png'),
                                  RubyLLM::Attachment.new('https://example.com/clip.mp4')])[:state]

    expect(state).to eq(
      ['Look', { type: 'image_url', image_url: { url: "data:image/png;base64,#{Base64.strict_encode64(png)}" } },
       { type: 'video_url', video_url: { url: "data:video/mp4;base64,#{Base64.strict_encode64(mp4)}" } }]
    )
  end

  it 'rejects uploaded files and attachments Decisions cannot carry' do
    uploaded = RubyLLM::Attachment.new(
      RubyLLM::UploadedFile.new(id: 'file-123', filename: 'receipt.png', mime_type: 'image/png')
    )

    expect { render('Help', with: [uploaded]) }.to raise_error(RubyLLM::UnsupportedAttachmentError, %r{image/png})
    expect { render('Help', with: [RubyLLM::Attachment.new(File.join(fixtures, 'sample.pdf'))]) }
      .to raise_error(RubyLLM::UnsupportedAttachmentError, %r{application/pdf})
  end

  it 'reports normalized OpenRouter errors' do
    stub_request(:post, 'https://openrouter.ai/api/alpha/decisions')
      .to_return(status: 401, body: { error: { code: 401, message: 'No auth credentials found' } }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    expect { RubyLLM.judge('Help', model: model_id, provider: :openrouter, assume_model_exists: true, questions:) }
      .to raise_error(RubyLLM::UnauthorizedError, 'No auth credentials found')
  end

  context 'with the Decisions API', :live do
    before { skip_without_cassette_or_key('OPENROUTER_API_KEY') }

    it 'judges all three question types through the compact DSL' do
      id = model_id
      triage = Class.new(RubyLLM::Judge) do
        model id, provider: :openrouter, assume_model_exists: true
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
      expect(result.model).to start_with('typesafe/jev-')
      expect(result.cost.total).to eq(result.raw.body.dig('usage', 'cost'))
    end

    it 'judges an image without text input' do
      result = RubyLLM.judge(with: File.join(fixtures, 'ruby.png'), model: model_for(:openrouter, :judgment_multimodal),
                             provider: :openrouter, assume_model_exists: true, questions: {
                               logo: { type: :probability, instructions: 'Is this image a logo?' },
                               color: { type: :choice, instructions: 'What is the dominant color?',
                                        options: { red: nil, blue: nil, green: nil } }
                             })

      expect(result.logo.probability).to be_between(0, 1)
      expect(result.color.choice).to be_in(%i[red blue green])
      expect(result.tokens.input).to be_positive
    end

    it 'judges a remote image by its URL' do
      result = RubyLLM.judge(with: 'https://raw.githubusercontent.com/crmne/ruby_llm/main/spec/fixtures/ruby.png',
                             model: model_for(:openrouter, :judgment_multimodal), provider: :openrouter,
                             assume_model_exists: true, questions: {
                               red: { type: :probability, instructions: 'Is the image mostly red?' }
                             })

      expect(result.red.probability).to be_between(0, 1)
      expect(result.tokens.input).to be_positive
    end

    it 'judges audio and video alongside text' do
      result = RubyLLM.judge(
        'A short clip about Ruby.',
        with: [File.join(fixtures, 'ruby.mp3'), File.join(fixtures, 'ruby_clip.mp4')],
        model: model_for(:openrouter, :judgment_multimodal), provider: :openrouter, assume_model_exists: true,
        questions: { about_ruby: { type: :probability,
                                   instructions: 'Do the audio or the video mention the Ruby programming language?' } }
      )

      expect(result.about_ruby.probability).to be_between(0, 1)
      expect(result.tokens.input).to be_positive
      expect(result.cost.total).to be_a(Float)
    end
  end
end
