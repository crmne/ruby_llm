# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Bedrock::Guardrails do
  include_context 'with configured RubyLLM'

  let(:endpoint) { 'https://bedrock-runtime.us-west-2.amazonaws.com/guardrail/test-guardrail/version/1/apply' }
  let(:clear) { { action: 'NONE', assessments: [], usage: { contentPolicyUnits: 1 } } }
  let(:blocked) do
    {
      action: 'GUARDRAIL_INTERVENED',
      assessments: [{ contentPolicy: { filters: [{ type: 'VIOLENCE', confidence: 'HIGH', action: 'BLOCKED' }] } }],
      outputs: [{ text: 'Blocked by the configured policy.' }], usage: { contentPolicyUnits: 1 }
    }
  end

  before do
    RubyLLM.config.bedrock_guardrail_id = 'test-guardrail'
    RubyLLM.config.bedrock_guardrail_version = '1'
  end

  it 'signs a model-free request and preserves the original policy assessment without invented scores or usage' do
    request = stub_request(:post, endpoint).with do |req|
      expect(JSON.parse(req.body)).to eq('source' => 'INPUT', 'content' => [{ 'text' => { 'text' => 'Review this.' } }])
      expect(req.headers['Authorization']).to include('/us-west-2/bedrock/aws4_request')
    end.to_return_json(body: blocked, headers: { 'x-amzn-requestid' => 'request-1' })
    allow(RubyLLM::Models).to receive(:find).and_call_original

    result = RubyLLM.moderate('Review this.', provider: :bedrock)

    expect(result).to have_attributes(id: 'request-1', model: nil, flagged?: true, flagged_categories: ['VIOLENCE'])
    expect(result.category_scores).to eq({})
    expect(result.raw).to eq(JSON.parse(JSON.generate(blocked)))
    expect(result.tokens.to_h).to eq({})
    expect(result.cost.total).to be_nil
    expect(result.ruby_llm_usage_entries).to contain_exactly(have_attributes(model: nil, status: :succeeded))
    expect(RubyLLM::Models).not_to have_received(:find)
    expect(request).to have_been_requested.once
  end

  it 'returns one verdict per input and records each successful request once' do
    stub_request(:post, endpoint).to_return_json(body: clear).then.to_return_json(body: blocked)
    capture = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = capture }

    result = context.moderate(['First text', 'Second text'], provider: :bedrock)

    expect(result.results.map(&:flagged?)).to eq([false, true])
    expect(result.raw.map { |response| response['action'] }).to eq(%w[NONE GUARDRAIL_INTERVENED])
    expect(result.id).to be_nil
    expect(result.ruby_llm_usage_entries.map(&:status)).to eq(%i[succeeded succeeded])
    usage = capture.events.filter_map { |name, payload| payload if name == 'usage.ruby_llm' }
    expect(usage).to all(include(model: nil, status: :succeeded))
    expect(usage.length).to eq(2)
  end

  it 'preserves successful attempts when a later input fails' do
    stub_request(:post, endpoint).to_return_json(body: clear).then.to_return_json(status: 500,
                                                                                  body: { message: 'Failed' })
    capture = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = capture }

    expect { context.moderate(%w[First Second], provider: :bedrock) }.to raise_error(RubyLLM::ServerError)

    usage = capture.events.filter_map { |name, payload| payload if name == 'usage.ruby_llm' }
    expect(usage.map { |attempt| attempt[:status] }).to eq(%i[succeeded failed])
    expect(usage.map { |attempt| attempt[:tokens].to_h }).to eq([{}, {}])
  end

  it 'reports anonymization and named policy interventions while retaining categorical confidence' do
    assessment = {
      topicPolicy: { topics: [{ name: 'Restricted topic', action: 'BLOCKED' }] },
      sensitiveInformationPolicy: { piiEntities: [{ type: 'EMAIL', action: 'ANONYMIZED' }],
                                    regexes: [{ name: 'Account number', action: 'ANONYMIZED' }] },
      wordPolicy: { customWords: [{ match: 'restricted', action: 'BLOCKED' }],
                    managedWordLists: [{ type: 'PROFANITY', action: 'NONE' }] },
      contentPolicy: { filters: [{ type: 'HATE', confidence: 'NONE', action: 'NONE' }] }
    }
    stub_request(:post, endpoint).to_return_json(body: blocked.merge(assessments: [assessment]))

    result = RubyLLM.moderate('Review this.', provider: :bedrock)

    expect(result.flagged_categories).to contain_exactly('Restricted topic', 'EMAIL', 'Account number',
                                                         'wordPolicy.customWords')
    expect(result.category_scores).to be_empty
  end

  it 'serializes PNG and JPEG images and permits output policy options' do
    images = %w[png jpeg].map do |extension|
      RubyLLM::Attachment.new(StringIO.new('image bytes'), filename: "image.#{extension}")
    end
    request = stub_request(:post, endpoint).with do |req|
      body = JSON.parse(req.body)
      expect(body['source']).to eq('OUTPUT')
      expect(body['outputScope']).to eq('FULL')
      expected = images.map do |image|
        { 'image' => { 'format' => image.mime_type.delete_prefix('image/'), 'source' => { 'bytes' => image.encoded } } }
      end
      expect(body['content'].drop(1)).to eq(expected)
    end.to_return_json(body: clear)

    result = RubyLLM.moderate('Caption', with: images, provider: :bedrock,
                                         provider_options: { source: 'OUTPUT', outputScope: 'FULL' })

    expect(result).not_to be_flagged
    expect(request).to have_been_requested.once
  end

  it 'rejects ambiguous or unsupported input and explicitly supplied models before networking' do
    image = RubyLLM::Attachment.new(StringIO.new('image'), filename: 'image.png')
    unsupported = RubyLLM::Attachment.new(StringIO.new('image'), filename: 'image.webp')
    expect do
      RubyLLM.moderate(['one'], with: image, provider: :bedrock)
    end.to raise_error(ArgumentError, /one text input/)
    expect { RubyLLM.moderate(with: unsupported, provider: :bedrock) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
    expect { RubyLLM.moderate([], provider: :bedrock) }.to raise_error(ArgumentError, /nonempty array/)
    expect { RubyLLM.moderate('text', model: model_for(:bedrock), provider: :bedrock) }
      .to raise_error(ArgumentError, /does not accept a model/)
    expect(a_request(:post, endpoint)).not_to have_been_made
  end

  it 'normalizes documented option keys without allowing the input or resource to be replaced' do
    request = stub_request(:post, endpoint).with do |req|
      expect(JSON.parse(req.body)).to eq('source' => 'OUTPUT', 'outputScope' => 'FULL',
                                         'content' => [{ 'text' => { 'text' => 'Original input' } }])
    end.to_return_json(body: clear)
    RubyLLM.moderate('Original input', provider: :bedrock,
                                       provider_options: { 'source' => 'OUTPUT', 'outputScope' => 'FULL' })

    %w[content model guardrailIdentifier guardrailVersion].each do |key|
      expect { RubyLLM.moderate('Original input', provider: :bedrock, provider_options: { key => 'override' }) }
        .to raise_error(ArgumentError, /only support source and outputScope/)
    end
    expect(request).to have_been_requested.once
  end

  it 'requires an explicitly configured guardrail and version' do
    RubyLLM.config.bedrock_guardrail_version = nil
    expect do
      RubyLLM.moderate('text', provider: :bedrock)
    end.to raise_error(RubyLLM::ConfigurationError, /guardrail_version/)
    expect(a_request(:post, endpoint)).not_to have_been_made
  end

  it 'rejects an empty or unrecognized successful response instead of treating it as safe' do
    stub_request(:post, endpoint).to_return_json(body: {})
    expect { RubyLLM.moderate('text', provider: :bedrock) }.to raise_error(RubyLLM::Error, /no recognized verdict/)
  end

  it 'does not change model requirements for other operations or providers' do
    expect(RubyLLM::Providers::Bedrock.model_required?(operation: :chat)).to be(true)
    expect(RubyLLM::Providers::OpenAI.model_required?(operation: :moderate)).to be(true)
    resolved, = RubyLLM::Models.resolve(nil, operation: :moderate,
                                             default_model: RubyLLM.config.default_moderation_model)
    expect(resolved.id).to eq(RubyLLM.config.default_moderation_model)
  end

  it 'applies an explicitly selected existing guardrail and reports its actual verdict', :live do
    identifier = ENV.fetch('BEDROCK_GUARDRAIL_ID', nil)
    version = ENV.fetch('BEDROCK_GUARDRAIL_VERSION', nil)
    unless identifier && version
      skip 'Set BEDROCK_GUARDRAIL_ID and BEDROCK_GUARDRAIL_VERSION to an authorized existing policy'
    end

    RubyLLM.config.bedrock_guardrail_id = identifier
    RubyLLM.config.bedrock_guardrail_version = version
    result = RubyLLM.moderate('Ruby is a programming language.', provider: :bedrock)

    expect(result.model).to be_nil
    expect(result.raw['action']).to be_in(%w[NONE GUARDRAIL_INTERVENED])
    expect(result.flagged?).to eq(result.raw['action'] == 'GUARDRAIL_INTERVENED')
    expect(result.tokens.to_h).to eq({})
    expect(result.category_scores).to eq({})
  end
end
