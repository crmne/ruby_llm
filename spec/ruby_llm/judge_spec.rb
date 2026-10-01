# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Judge do
  include_context 'with configured RubyLLM'

  let(:model_id) { model_for(:typesafe, :judgment) }
  let(:response_body) do
    {
      model: model_id,
      answers: { urgent: { type: 'noul', noul: 0.9 } },
      usage: { input_tokens: 100, output_tokens: 10 }
    }
  end
  let(:judge_class) do
    id = model_id
    Class.new(described_class) do
      model id, provider: :typesafe, assume_model_exists: true
      probability :urgent, 'Does this need attention today?'
    end
  end
  let(:requests) { [] }

  before do
    stub_request(:post, 'https://api.typesafe.ai/v1/systemone').to_return do |request|
      requests << JSON.parse(request.body)
      { status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' } }
    end
  end

  it 'judges plain text and returns a typed probability with accounting' do
    result = judge_class.judge('Please help today.')

    expect(requests.first).to eq(
      'model' => model_id, 'state' => 'Please help today.',
      'questions' => { 'urgent' => { 'type' => 'noul', 'instructions' => 'Does this need attention today?' } }
    )
    expect(result).to be_a(RubyLLM::Judgment)
    expect(result[:urgent]).to be_a(RubyLLM::Probability)
    expect(result[:urgent].probability).to eq(0.9)
    expect(result.tokens.input).to eq(100)
    expect(result.tokens.output).to eq(10)
    expect(result.cost.total).to be_nil
    expect(result.ruby_llm_usage_entries.first.operation).to eq(:judgment)
  end

  it 'builds nested input data with one request' do
    judge_class.judge do
      message 'Please help today.'
      customer do
        plan 'Pro'
        previous_contacts 2
      end
    end

    expect(requests.size).to eq(1)
    expect(requests.first['state']).to eq(
      'message' => 'Please help today.', 'customer' => { 'plan' => 'Pro', 'previous_contacts' => 2 }
    )
  end

  it 'accepts arrays, hashes, procs, and blocks returning input' do
    values = ['Please help', { message: 'Please help' }, ['First message', 'Second message']]
    values.each do |value|
      judge_class.judge(value)
      judge_class.judge(-> { value })
      judge_class.judge { value }
    end

    expect(requests.map { |request| request['state'] }).to eq(
      values.flat_map { |value| [JSON.parse(value.to_json)] * 3 }
    )
  end

  it 'accepts an explicit block receiver' do
    judge_class.judge { |data| data.message 'Please help today.' }

    expect(requests.first['state']).to eq('message' => 'Please help today.')
  end

  it 'keeps successive judgments independent' do
    judge = judge_class.new
    judge.judge('First')
    judge.judge('Second')

    expect(requests.map { |request| request['state'] }).to eq(%w[First Second])
  end

  it 'resolves declared inputs and procs once per judgment, including nested values' do
    calls = []
    id = model_id
    configured = Class.new(described_class) do
      inputs :ticket
      model lambda {
        calls << :model
        id
      }, provider: :typesafe, assume_model_exists: true
      probability :urgent, lambda {
        calls << :question
        { question: 'Is this urgent?', deadline: ticket }
      } do
        yes lambda {
          calls << :criteria
          "Due #{ticket}"
        }
        no 'No deadline'
      end
    end

    configured.judge(ticket: 'today') { message "Please help #{ticket}" }

    expect(calls).to contain_exactly(:model, :question, :criteria)
    expect(requests.first['state']).to eq('message' => 'Please help today')
    expect(requests.first.dig('questions', 'urgent')).to include(
      'instructions' => { 'question' => 'Is this urgent?', 'deadline' => 'today' },
      'criteria' => { 'true' => 'Due today', 'false' => 'No deadline' }
    )
  end

  it 'inherits configuration while allowing a subclass to replace a question' do
    child = Class.new(judge_class) { probability :urgent, 'Does this require an immediate response?' }
    child.judge('Help')
    judge_class.judge('Help')

    expect(requests.map { |request| request.dig('questions', 'urgent', 'instructions') }).to eq(
      ['Does this require an immediate response?', 'Does this need attention today?']
    )
    expect(child.model).to eq(judge_class.model)
  end

  it 'isolates mutable question definitions from their original data' do
    descriptions = { yes: +'Today', no: +'Later' }
    configured = Class.new(judge_class) { probability :urgent, 'Is it urgent?', descriptions }
    descriptions[:yes].replace('Changed')

    configured.judge('Help')

    expect(requests.first.dig('questions', 'urgent', 'criteria', 'true')).to eq('Today')
  end

  it 'supports one-off questions through the top-level entry point' do
    result = RubyLLM.judge('Help', model: model_id, provider: :typesafe, assume_model_exists: true,
                                   questions: { urgent: { type: :probability, instructions: 'Is this urgent?' } })

    expect(result[:urgent].probability).to eq(0.9)
  end

  it 'supports isolated contexts and forwards provider options and instrumentation metadata' do
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context do |config|
      config.typesafe_api_key = 'tenant-key'
      config.instrumenter = instrumenter
    end
    context.judge('Help', model: model_id, provider: :typesafe, assume_model_exists: true,
                          provider_options: { extension: { enabled: true } }, metadata: { ticket_id: 42 },
                          questions: { urgent: { type: :probability, instructions: 'Is this urgent?' } })

    expect(a_request(:post, 'https://api.typesafe.ai/v1/systemone')
      .with(headers: { 'Authorization' => 'Bearer tenant-key' })).to have_been_made.once
    expect(requests.first['extension']).to eq('enabled' => true)
    event = instrumenter.events.find { |name, _| name == 'judgment.ruby_llm' }
    expect(event.last).to include(metadata: { ticket_id: 42 }, question_count: 1, attachment_count: 0)
  end

  it 'accepts images with or without input and rejects them on text-only protocols before sending' do
    image = 'https://example.com/receipt.png'

    expect { judge_class.judge('Help', with: image) }.to raise_error(RubyLLM::UnsupportedAttachmentError, %r{image/png})
    expect { judge_class.judge(with: [image]) }.to raise_error(RubyLLM::UnsupportedAttachmentError)
    expect { judge_class.judge(with: []) }.to raise_error(ArgumentError, /Judgment input/)
    expect(requests).to be_empty
  end

  it 'rejects missing or unknown runtime inputs' do
    configured = Class.new(judge_class) { inputs :ticket }

    expect { configured.new }.to raise_error(ArgumentError, /Missing judge inputs: ticket/)
    expect { configured.new(ticket: 'Help', extra: true) }.to raise_error(ArgumentError, /Unknown judge inputs: extra/)
  end

  it 'rejects duplicate questions, including String and Symbol spellings' do
    expect { judge_class.probability 'urgent', 'Another question' }.to raise_error(ArgumentError, /Duplicate question/)
    expect { judge_class.judge('Help', questions: { urgent: { type: :probability } }) }
      .to raise_error(ArgumentError, /Duplicate question/)
  end

  it 'rejects conflicting input and block declarations before sending a request' do
    expect { judge_class.judge('Help') { 'Other input' } }.to raise_error(ArgumentError, /input or a block/)
    expect do
      judge_class.judge do
        message 'Help'
        { another: 'value' }
      end
    end.to raise_error(ArgumentError, /declare fields or return a value/)
    expect(requests).to be_empty
  end

  it 'rejects duplicate data keys and non-JSON values without stringifying them' do
    [Object.new, Float::NAN, { message: Float::INFINITY }, { message: 'A', 'message' => 'B' }].each do |value|
      expect { judge_class.judge(value) }.to raise_error(ArgumentError)
    end
    expect do
      judge_class.judge do
        message 'A'
        message 'B'
      end
    end.to raise_error(ArgumentError, /Duplicate judgment field/)
    expect(requests).to be_empty
  end

  it 'requires questions and non-nil input' do
    expect { described_class.judge('Help') }.to raise_error(ArgumentError, /at least one question/)
    expect { judge_class.judge(nil) }.to raise_error(ArgumentError, /Judgment input/)
  end

  context 'with a default judgment model' do
    let(:judge_class) do
      Class.new(described_class) { probability :urgent, 'Does this need attention today?' }
    end

    it 'uses the configured model without a model declaration' do
      RubyLLM.config.default_judgment_model = model_id

      result = judge_class.judge('Please help today.')

      expect(requests.first['model']).to eq(model_id)
      expect(result.urgent.probability).to eq(0.9)
      expect(judge_class.model).to eq({})
    end

    it 'resolves the global default at each call, including inherited judges' do
      child = Class.new(judge_class).new
      RubyLLM.config.default_judgment_model = model_id
      child.judge('First')
      RubyLLM.config.default_judgment_model = 'jev-preview'
      child.judge('Second')

      expect(requests.map { |request| request['model'] }).to eq([model_id, 'jev-preview'])
    end

    it 'uses the default for one-off questions' do
      RubyLLM.config.default_judgment_model = model_id
      result = RubyLLM.judge('Help', questions: { urgent: { type: :probability, instructions: 'Is this urgent?' } })

      expect(requests.first['model']).to eq(model_id)
      expect(result.urgent.probability).to eq(0.9)
    end

    it 'uses an isolated context default for classes and one-off questions' do
      RubyLLM.config.default_judgment_model = model_id
      context = RubyLLM.context { |config| config.default_judgment_model = 'jev-preview' }

      judge_class.judge('Help', context:)
      context.judge('Help', questions: { urgent: { type: :probability, instructions: 'Is this urgent?' } })

      expect(requests.map { |request| request['model'] }).to eq(%w[jev-preview jev-preview])
      expect(RubyLLM.config.default_judgment_model).to eq(model_id)
    end

    it 'prefers a class model over the default and a call model over both' do
      RubyLLM.config.default_judgment_model = 'jev-preview'
      judge_class.model(model_id)
      judge_class.judge('First')
      judge_class.judge('Second', model: 'jev-preview')

      expect(requests.map { |request| request['model'] }).to eq([model_id, 'jev-preview'])
    end

    it 'uses the default when a call explicitly resets the model to nil' do
      RubyLLM.config.default_judgment_model = 'jev-preview'
      judge_class.model(model_id)
      judge_class.judge('Help', model: nil)

      expect(requests.first['model']).to eq('jev-preview')
    end

    it 'requires a model when the default is unset' do
      RubyLLM.config.default_judgment_model = nil

      expect { judge_class.judge('Help') }.to raise_error(ArgumentError, /model/)
      expect(requests).to be_empty
      expect(judge_class.judge('Help', model: model_id)).to be_a(RubyLLM::Judgment)
    end
  end

  it 'rejects unsupported providers through the provider contract' do
    expect do
      judge_class.judge('Help', model: model_for(:anthropic), provider: :anthropic)
    end.to raise_error(RubyLLM::Error, /doesn't support judgments/)
  end

  it 'lets OpenAI reject chat models through Decisions' do
    model = model_for(:openai)
    stub = stub_request(:post, 'https://api.openai.com/v1/decisions').to_return(
      status: 404, headers: { 'Content-Type' => 'application/json' },
      body: { error: { message: "The model `#{model}` does not exist or you do not have access to it." } }.to_json
    )

    expect { judge_class.judge('Help', model:, provider: :openai) }.to raise_error(RubyLLM::Error, /does not exist/)
    expect(stub).to have_been_requested.once
  end

  context 'with all question types' do
    let(:response_body) do
      {
        model: model_id,
        answers: {
          urgent: { type: 'noul', noul: 0.9 },
          department: { type: 'choice', choice: 'billing', probabilities: { billing: 0.9, other: 0.1 },
                        confidence: 0.8 },
          frustration: { type: 'score', score: 0.25, confidence: 0.5,
                         probabilities: { '0' => 0.75, '1' => 0.25 },
                         legend: { '0' => { description: 'Calm' }, '1' => %w[Angry Hostile] } }
        },
        usage: { input_tokens: 200, output_tokens: 30 }
      }
    end

    before do
      judge_class.choice(:department, ['Which team?', 'Pick one']) do
        billing do
          handles %w[Charges Refunds]
          excludes 'Account access'
        end
        other nil
      end
      judge_class.score(:frustration, 'How frustrated?') { [{ description: 'Calm' }, %w[Angry Hostile]] }
    end

    it 'preserves structured criteria, typed choices, fractional scores, distributions, and confidence' do
      result = judge_class.judge('Help')

      expect(requests.first.dig('questions', 'department', 'criteria')).to eq(
        'billing' => { 'handles' => %w[Charges Refunds], 'excludes' => 'Account access' }, 'other' => nil
      )
      expect(result.department).to be_a(RubyLLM::Choice)
      expect(result[:department].choice).to eq(:billing)
      expect(result[:department].probabilities).to eq(billing: 0.9, other: 0.1)
      expect(result[:department].confidence).to eq(0.8)
      expect(result.frustration).to be_a(RubyLLM::Score)
      expect(result[:frustration].score).to eq(0.25)
      expect(result[:frustration].levels).to eq([{ 'description' => 'Calm' }, %w[Angry Hostile]])
      expect(result[:frustration].probabilities).to eq(0 => 0.75, 1 => 0.25)
      expect(result[:frustration].confidence).to eq(0.5)
    end
  end
end
