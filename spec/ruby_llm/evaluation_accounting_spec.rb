# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Evaluation do
  include_context 'with configured RubyLLM'

  def task_model = model_for(:anthropic)
  def review_model = model_for(:openai)
  def embedding_model = model_for(:openai, :embedding)
  let(:cases) { [RubyLLM::Evaluation::Case.new(name: 'greeting', inputs: 'Hello')] }
  let(:review_body) do
    { model: review_model,
      choices: [{ index: 0, message: { role: 'assistant', content: JSON.generate(verdicts) }, finish_reason: 'stop' }],
      usage: { prompt_tokens: 100, completion_tokens: 20,
               prompt_tokens_details: { cached_tokens: 10 }, completion_tokens_details: { reasoning_tokens: 3 } } }
  end
  let(:verdicts) { { correct: { verdict: 'pass', reason: 'A greeting.' } } }
  let(:evaluation) do
    model = task_model
    Class.new(RubyLLM::Evaluation) do
      evaluation :correct, 'The output greets the user'

      define_method(:perform) do |input|
        RubyLLM.chat(model:, provider: :anthropic).ask(input).content
      end

      def assertions
        refute_empty output
      end
    end
  end

  def json_response(body)
    { status: 200, headers: { 'Content-Type' => 'application/json' }, body: body.to_json }
  end

  before do
    evaluation.evaluator(model: review_model, provider: :openai, protocol: :chat_completions)
    task_reply = { id: 'msg_1', type: 'message', role: 'assistant', model: task_model,
                   content: [{ type: 'text', text: 'Hello' }], stop_reason: 'end_turn',
                   usage: { input_tokens: 9, output_tokens: 2,
                            cache_creation_input_tokens: 4, cache_read_input_tokens: 6 } }
    embedding = { model: embedding_model, data: [{ embedding: [0.1, 0.2] }], usage: { prompt_tokens: 3 } }
    stub_request(:post, 'https://api.anthropic.com/v1/messages').to_return(json_response(task_reply))
    stub_request(:post, 'https://api.openai.com/v1/chat/completions').to_return { json_response(review_body) }
    stub_request(:post, 'https://api.openai.com/v1/embeddings').to_return(json_response(embedding))
  end

  it 'accounts for plain-text returns, every repetition, and the standard token buckets' do
    report = evaluation.run(dataset: cases, repetitions: 2)
    trial = report.first

    expect(report).to be_passed
    expect(trial.result).to eq('Hello')
    expect(report.tokens).to be_a(RubyLLM::Tokens)
    expect(report.cost).to be_a(RubyLLM::Cost)
    expect(report.tokens.to_h).to eq(input_tokens: 198, output_tokens: 44, cache_read_tokens: 32,
                                     cache_write_tokens: 8, thinking_tokens: 6)
    expect(trial.task_tokens.input).to eq(9)
    expect(trial.evaluator_tokens.input).to eq(90)
    expect(trial.cost.total).to be_within(1e-12).of(trial.task_cost.total + trial.evaluator_cost.total)
    expect(report.cost.total).to be_within(1e-12).of(trial.cost.total * 2)
    expect(report.to_h).to include(tokens: report.tokens.to_h, cost: report.cost.to_h)
    expect(trial.to_h).to include(task_tokens: trial.task_tokens.to_h, evaluator_tokens: trial.evaluator_tokens.to_h)
  end

  it 'counts calls in setup and teardown even when their results are discarded' do
    model = embedding_model
    evaluation.define_method(:setup) { RubyLLM.embed('Setup', model:, provider: :openai) }
    evaluation.define_method(:teardown) { RubyLLM.embed('Cleanup', model:, provider: :openai) }

    trial = evaluation.run(dataset: cases).first

    expect(trial.task_tokens.input).to eq(15)
    expect(trial.tokens.input).to eq(105)
  end

  it 'keeps task usage when model grading is disabled' do
    model = task_model
    evaluation = Class.new(described_class) do
      evaluator false

      define_method(:perform) do |input|
        RubyLLM.chat(model:, provider: :anthropic).ask(input)
      end

      def assertions
        refute_empty output
      end
    end
    report = evaluation.run(dataset: cases)

    expect(report).to be_passed
    expect(report.first.evaluations).to be_empty
    expect(report.first.evaluator_tokens.input).to be_nil
    expect(report.tokens.to_h).to eq(report.first.task_tokens.to_h)
    expect(report.cost.total).to eq(report.first.task_cost.total)
    expect(report.tokens.input).to eq(9)
    expect(WebMock).not_to have_requested(:post, 'https://api.openai.com/v1/chat/completions')
  end

  it 'excludes a returned conversation history that was billed before the run' do
    chat = RubyLLM.chat(model: task_model, provider: :anthropic)
    chat.ask('Earlier question')
    evaluation.define_method(:perform) do |input|
      chat.ask(input)
      chat
    end

    trial = evaluation.run(dataset: cases).first

    expect(chat.tokens.input).to eq(18)
    expect(trial.task_tokens.input).to eq(9)
  end

  it 'sends every turn to the evaluator when perform returns a multi-turn chat' do
    model = task_model
    evaluation.define_method(:perform) do |questions|
      chat = RubyLLM.chat(model:, provider: :anthropic)
      questions.each { |question| chat.ask(question) }
      chat
    end
    request_body = nil
    stub_request(:post, 'https://api.openai.com/v1/chat/completions').to_return do |request|
      request_body = JSON.parse(request.body)
      json_response(review_body)
    end
    dataset = [RubyLLM::Evaluation::Case.new(name: 'conversation', inputs: ['First question', 'Follow-up'])]
    trial = evaluation.run(dataset:).first
    evidence = JSON.parse(request_body.fetch('messages').last.fetch('content')).fetch('actual')

    expect(trial).to be_passed
    expect(evidence.fetch('messages').map { |message| message.fetch('content') })
      .to eq(['First question', 'Hello', 'Follow-up', 'Hello'])
    expect(trial.output).to eq('Hello')
    expect(trial.task_tokens.input).to eq(18)
  end

  it 'keeps billed usage when application code fails after receiving a response' do
    model = task_model
    evaluation.define_method(:perform) do |input|
      RubyLLM.chat(model:, provider: :anthropic).ask(input)
      raise 'Application failed'
    end

    trial = evaluation.run(dataset: cases).first

    expect(trial.status).to eq(:error)
    expect(trial.tokens.input).to eq(9)
    expect(trial.cost.total).to be_positive
    expect(trial.evaluator_tokens.to_h).to be_empty
  end

  it 'keeps the known evaluator cost when the returned assessment is malformed' do
    verdicts.clear
    trial = evaluation.run(dataset: cases).first

    expect(trial.status).to eq(:error)
    expect(trial.evaluator_tokens.input).to eq(90)
    expect(trial.evaluator_cost.total).to be_positive
    expect(trial.cost.total).to be_positive
  end

  it 'preserves unknown totals when a failed evaluator attempt may have been billed' do
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(status: 500, body: { error: { message: 'Failed after acceptance' } }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
    trial = evaluation.run(dataset: cases).first

    expect(trial.status).to eq(:error)
    expect(trial.task_cost.total).to be_positive
    expect(trial.evaluator_cost.total).to be_nil
    expect(trial.cost.total).to be_nil
    expect(trial.tokens.input).to eq(9)
  end

  it 'counts a grouped evaluator request once for all its criteria' do
    evaluation.evaluation :concise, 'The output is brief'
    verdicts[:concise] = { verdict: 'pass', reason: 'One word.' }
    trial = evaluation.run(dataset: cases).first

    expect(trial.evaluations.size).to eq(2)
    expect(trial.evaluator_tokens.input).to eq(90)
  end

  it 'includes model calls made inside an evaluator tool' do
    model = embedding_model
    tool = Class.new(RubyLLM::Tool) do
      description 'Look up the greeting policy.'
      define_method(:execute) { RubyLLM.embed('Policy', model:, provider: :openai).vectors }
    end
    stub_const('EvaluationPolicyLookup', tool)
    reviewer = Class.new(RubyLLM::Agent)
    reviewer.model(review_model, provider: :openai, protocol: :chat_completions)
    reviewer.tools(tool)
    evaluation.evaluator(reviewer)
    tool_reply = { model: review_model, choices: [{ index: 0, finish_reason: 'tool_calls', message: {
      role: 'assistant', content: nil,
      tool_calls: [{ id: 'call_1', type: 'function', function: { name: 'evaluation_policy_lookup', arguments: '{}' } }]
    } }], usage: { prompt_tokens: 12, completion_tokens: 4 } }
    stub_request(:post, 'https://api.openai.com/v1/chat/completions')
      .to_return(json_response(tool_reply), json_response(review_body))

    trial = evaluation.run(dataset: cases).first

    expect(trial).to be_passed
    expect(trial.evaluator_tokens.input).to eq(105)
    expect(trial.evaluator_tokens.output).to eq(24)
  end

  it 'includes child threads and fibers without mixing concurrent evaluations or unrelated calls' do
    ready = Queue.new
    proceed = Queue.new
    model = task_model
    evaluation.define_method(:perform) do |input|
      ready << true
      proceed.pop
      Thread.new { RubyLLM.chat(model:, provider: :anthropic).ask(input) }.join
      Fiber.new { RubyLLM.chat(model:, provider: :anthropic).ask(input).content }.resume
    end
    threads = Array.new(2) { Thread.new { evaluation.run(dataset: cases) } }
    2.times { ready.pop }
    RubyLLM.embed('Unrelated', model: embedding_model, provider: :openai)
    2.times { proceed << true }
    reports = threads.map(&:value)

    expect(reports).to all(be_passed)
    expect(reports.map { |report| report.first.task_tokens.input }).to eq([18, 18])
    expect(reports.map { |report| report.tokens.input }).to eq([108, 108])
  end

  it 'counts nested evaluations as task work and restores the outer scope' do
    inner = Class.new(evaluation)
    inner.define_method(:perform, evaluation.instance_method(:perform))
    inner_cases = cases
    evaluation.define_method(:perform) do |_input|
      inner.run(dataset: inner_cases)
      'Hello'
    end
    trial = evaluation.run(dataset: cases).first

    expect(trial.task_tokens.input).to eq(99)
    expect(trial.evaluator_tokens.input).to eq(90)
    expect(trial.tokens.input).to eq(189)
  end

  it 'keeps a finished report unchanged when detached work completes later' do
    proceed = Queue.new
    thread = nil
    model = task_model
    evaluation.define_method(:perform) do |input|
      thread = Thread.new do
        proceed.pop
        RubyLLM.chat(model:, provider: :anthropic).ask(input)
      end
      'Hello'
    end
    report = evaluation.run(dataset: cases)
    proceed << true

    expect(thread.value.content).to eq('Hello')
    expect(report.tokens.input).to eq(90)
    expect(report.first.task_tokens.to_h).to be_empty
  end
end
