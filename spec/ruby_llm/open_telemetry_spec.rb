# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/open_telemetry'
require 'open3'

RSpec.describe RubyLLM::OpenTelemetry do
  include_context 'with configured RubyLLM'

  include_context 'with OpenTelemetry tracing'

  let(:model) { model_for(:openai, :temperature) }
  let(:response) do
    RubyLLM::Message.new(role: :assistant, content: 'private response', model: model, finish_reason: :stop,
                         input_tokens: 10, output_tokens: 5, cache_read_tokens: 3, cache_write_tokens: 2,
                         thinking_tokens: 1)
  end

  def stub_chat(context = RubyLLM)
    context.chat(model: model).tap do |chat|
      allow(chat.instance_variable_get(:@provider)).to receive(:complete).and_return(response)
    end
  end

  it 'does not load OpenTelemetry when requiring or eager loading RubyLLM' do
    script = <<~SCRIPT
      require 'ruby_llm'
      Zeitwerk::Loader.eager_load_all
      abort 'loaded OpenTelemetry' if defined?(::OpenTelemetry)
    SCRIPT
    output, status = Open3.capture2e('bundle', 'exec', 'ruby', '-e', script)
    expect(status.success?).to be(true), output
  end

  it 'works with only the API without configuring an SDK' do
    script = <<~SCRIPT
      require 'ruby_llm'
      require 'opentelemetry-api'
      provider = OpenTelemetry.tracer_provider
      RubyLLM::OpenTelemetry.enable
      result = RubyLLM.instrument('chat.ruby_llm', provider: 'openai') { :ok }
      abort 'changed return value' unless result == :ok
      abort 'configured SDK' if defined?(OpenTelemetry::SDK)
      abort 'replaced provider' unless OpenTelemetry.tracer_provider.equal?(provider)
    SCRIPT
    output, status = Open3.capture2e('bundle', 'exec', 'ruby', '-e', script)
    expect(status.success?).to be(true), output
  end

  it 'reports a useful error when the optional API is missing' do
    allow(described_class).to receive(:require).with('opentelemetry-api').and_raise(LoadError)

    expect { described_class.enable }.to raise_error(LoadError, /opentelemetry-api.*Gemfile/)
  end

  it 'traces a chat under the application span without capturing content' do
    chat = stub_chat.with_temperature(0.2).with_max_output_tokens(100)
    result = provider.tracer('application').in_span('request') { chat.ask('private prompt') }

    expect(result).to eq(response)
    chat_span, parent = spans
    expect(chat_span.name).to eq("chat #{model}")
    expect(chat_span.kind).to eq(:client)
    expect(chat_span.parent_span_id).to eq(parent.span_id)
    expect(chat_span.instrumentation_scope.name).to eq('ruby_llm')
    expect(chat_span.attributes).to include(
      'gen_ai.operation.name' => 'chat', 'gen_ai.provider.name' => 'openai',
      'gen_ai.request.model' => model, 'gen_ai.response.model' => model,
      'gen_ai.request.temperature' => 0.2, 'gen_ai.request.max_tokens' => 100,
      'gen_ai.response.finish_reasons' => ['stop'],
      'gen_ai.usage.input_tokens' => 15, 'gen_ai.usage.output_tokens' => 5,
      'gen_ai.usage.cache_read.input_tokens' => 3, 'gen_ai.usage.cache_write.input_tokens' => 2,
      'gen_ai.usage.reasoning.output_tokens' => 1
    )
    expect(chat_span.attributes.to_s).not_to include('private', 'gen_ai.system', 'conversation.id')
    expect(chat_span.status.code).to eq(OpenTelemetry::Trace::Status::UNSET)
  end

  it 'preserves Rails subscribers, their payloads, and event-only notifications' do
    events = []
    subscription = ActiveSupport::Notifications.subscribe(/\.ruby_llm$/) { |event| events << event }
    context = RubyLLM.context { |config| config.instrumenter = ActiveSupport::Notifications }
    stub_chat(context).ask('private prompt')

    expect(context.config.instrumenter).to eq(ActiveSupport::Notifications)
    expect(events.map(&:name)).to contain_exactly('chat.ruby_llm', 'usage.ruby_llm')
    expect(events.find { |event| event.name == 'chat.ruby_llm' }.payload[:response]).to eq(response)
    expect(spans.size).to eq(1)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  it 'enables once and disables without shutting down the application provider' do
    described_class.enable
    stub_chat.ask('first')
    described_class.disable
    stub_chat.ask('second')
    provider.tracer('application').in_span('still running') { nil }

    expect(spans.map(&:name)).to eq(["chat #{model}", 'still running'])
  end

  it 'keeps the span active through streaming callbacks and the final response' do
    chat = stub_chat
    adapter = chat.instance_variable_get(:@provider)
    chunk = RubyLLM::Chunk.new(role: :assistant, content: 'private chunk')
    allow(adapter).to receive(:complete) do |&block|
      block.call(chunk)
      expect(spans).to be_empty
      response
    end
    seen = []
    chat.ask('private prompt') do |value|
      seen << value
      expect(OpenTelemetry::Trace.current_span.recording?).to be(true)
    end

    expect(seen).to eq([chunk])
    expect(spans.one?).to be(true)
    expect(spans.first.attributes['gen_ai.request.stream']).to be(true)
    expect(spans.first.attributes['gen_ai.usage.output_tokens']).to eq(5)
  end

  it 'finishes failed spans and restores context without exporting exception messages' do
    chat = stub_chat
    error = RubyLLM::Error.new('private error detail')
    allow(chat.instance_variable_get(:@provider)).to receive(:complete).and_raise(error)
    previous = OpenTelemetry::Context.current

    expect { chat.ask('private prompt') }.to(raise_error { |raised| expect(raised).to equal(error) })
    expect(OpenTelemetry::Context.current).to equal(previous)
    expect(spans.first.status.code).to eq(OpenTelemetry::Trace::Status::ERROR)
    expect(spans.first.attributes['error.type']).to eq('RubyLLM::Error')
    expect(spans.first.events).to be_nil
    expect(spans.first.attributes.to_s).not_to include('private')
  end

  it 'finishes spans on cancellation' do
    expect do
      RubyLLM.instrument('chat.ruby_llm', model: model, provider: 'openai') { raise RubyLLM::CancelledError }
    end.to raise_error(RubyLLM::CancelledError)

    expect(spans.first.attributes['error.type']).to eq('RubyLLM::CancelledError')
  end

  it 'finishes spans on nonlocal returns' do
    result = catch(:done) do
      RubyLLM.instrument('chat.ruby_llm', model: model, provider: 'openai') { throw :done, :ok }
    end

    expect(result).to eq(:ok)
    expect(spans.size).to eq(1)
  end

  it 'isolates a tracing failure from the application operation' do
    allow(provider).to receive(:tracer).and_raise(StandardError, 'private exporter failure')
    allow(RubyLLM.logger).to receive(:warn)

    expect(stub_chat.ask('hello')).to eq(response)
    expect(RubyLLM.logger).to have_received(:warn).with('OpenTelemetry instrumentation failed (StandardError)')
  end

  it 'traces embeddings without exporting inputs or vectors' do
    embedding_model = model_for(:openai, :embedding)
    embedding = RubyLLM::Embedding.new(vectors: [0.1, 0.2], model: embedding_model, input_tokens: 8)
    model_info, adapter = RubyLLM::Models.resolve(embedding_model, config: RubyLLM.config)
    allow(RubyLLM::Models).to receive(:resolve).and_return([model_info, adapter])
    allow(adapter).to receive(:embed).and_return(embedding)

    expect(RubyLLM.embed('private input', model: embedding_model, dimensions: 2)).to eq(embedding)
    expect(spans.first.name).to eq("embeddings #{embedding_model}")
    expect(spans.first.attributes).to include('gen_ai.embeddings.dimension.count' => 2,
                                              'gen_ai.usage.input_tokens' => 8)
    expect(spans.first.attributes.to_s).not_to include('private', '0.1', 'output_tokens')
  end

  it 'keeps transport retries inside a single model span' do
    context = RubyLLM.context do |config|
      config.max_retries = 1
      config.retry_interval = 0
    end
    stub_request(:post, 'https://api.openai.com/v1/chat/completions').to_return(
      { status: 500, headers: { 'Content-Type' => 'application/json' },
        body: { error: { message: 'retry' } }.to_json },
      { status: 200, headers: { 'Content-Type' => 'application/json' },
        body: { model: model, choices: [{ message: { role: 'assistant', content: 'done' }, finish_reason: 'stop' }],
                usage: { prompt_tokens: 5, completion_tokens: 2 } }.to_json }
    )

    context.chat(model: model, provider: :openai, protocol: :chat_completions).ask('Hello')

    expect(spans.size).to eq(1)
    expect(spans.first.attributes['gen_ai.usage.input_tokens']).to eq(5)
    expect(spans.first.status.code).to eq(OpenTelemetry::Trace::Status::UNSET)
  end

  it 'keeps fallback usage on the model span that incurred it' do
    fallback = model_for(:anthropic)
    chat = RubyLLM.chat(model: model).with_fallbacks(fallback)
    primary = chat.provider
    fallback_model, fallback_provider = RubyLLM::Models.resolve(fallback, config: RubyLLM.config)
    allow(RubyLLM::Models).to receive(:resolve).and_call_original
    allow(RubyLLM::Models).to receive(:resolve).with(fallback, any_args).and_return([fallback_model, fallback_provider])
    allow(primary).to receive(:complete) do |_messages, usage_recorder:, **|
      entry = RubyLLM::Accounting::Usage::Entry.new(
        operation: :chat, provider: primary.slug, model: model, status: :failed,
        tokens: RubyLLM::Tokens.new(input: 7, output: 1)
      )
      usage_recorder.call(entry)
      raise RubyLLM::ServiceUnavailableError, 'try another model'
    end
    fallback_response = RubyLLM::Message.new(role: :assistant, content: 'done', model: fallback,
                                             input_tokens: 4, output_tokens: 2)
    allow(fallback_provider).to receive(:complete).and_return(fallback_response)

    result = chat.ask('Hello')

    expect(result.tokens.input).to eq(11)
    expect(spans.map { |span| span.attributes['gen_ai.usage.input_tokens'] }).to eq([7, 4])
    expect(spans.map { |span| span.attributes['gen_ai.provider.name'] }).to eq(%w[openai anthropic])
  end

  it 'omits unknown token counts and preserves reported zeroes' do
    RubyLLM.instrument('embedding.ruby_llm', provider: 'openai', tokens: RubyLLM::Tokens.new(input: 0)) { :ok }

    expect(spans.first.attributes).to include('gen_ai.usage.input_tokens' => 0)
    expect(spans.first.attributes).not_to have_key('gen_ai.usage.output_tokens')
  end

  it 'uses conventional provider names and output types without copying arbitrary metadata' do
    RubyLLM.instrument('image.ruby_llm', provider: 'vertexai', model: model,
                                         prompt: 'private prompt', metadata: { secret: 'private metadata' }) { :ok }
    RubyLLM.instrument('speech.ruby_llm', provider: 'azure', model: model, input: 'private speech') { :ok }

    expect(spans.map { |span| span.attributes['gen_ai.provider.name'] }).to eq(%w[gcp.vertex_ai azure.ai.openai])
    expect(spans.map { |span| span.attributes['gen_ai.output.type'] }).to eq(%w[image speech])
    expect(spans.map(&:name)).to eq(["generate_content #{model}", "generate_content #{model}"])
    expect(spans.map(&:attributes).to_s).not_to include('private', 'secret')
  end

  it 'keeps distinct operations isolated when fibers interleave' do
    run = lambda do
      RubyLLM.instrument('chat.ruby_llm', provider: 'openai', model: model) do
        current = OpenTelemetry::Trace.current_span.context.span_id
        Fiber.yield(current)
        expect(OpenTelemetry::Trace.current_span.context.span_id).to eq(current)
      end
    end
    first = Fiber.new(&run)
    second = Fiber.new(&run)

    expect(first.resume).not_to eq(second.resume)
    second.resume
    first.resume

    expect(spans.size).to eq(2)
    expect(spans.map(&:parent_span_id)).to eq([OpenTelemetry::Trace::INVALID_SPAN_ID] * 2)
  end

  it 'restores the parent when a streaming callback raises' do
    chat = stub_chat
    chunk = RubyLLM::Chunk.new(role: :assistant, content: 'hello')
    allow(chat.provider).to receive(:complete).and_yield(chunk)
    error = RuntimeError.new('callback failed')
    provider.tracer('application').in_span('request') do |parent|
      expect { chat.ask('hello') { raise error } }.to raise_error(error)
      expect(OpenTelemetry::Trace.current_span).to equal(parent)
    end

    expect(spans.first.attributes['error.type']).to eq('RuntimeError')
    expect(spans.first.status.code).to eq(OpenTelemetry::Trace::Status::ERROR)
  end

  it 'finishes an active span after tracing is disabled' do
    RubyLLM.instrument('chat.ruby_llm', model:, provider: 'openai') do
      described_class.disable
      stub_chat.ask('untraced')
      expect(spans).to be_empty
    end

    expect(spans.size).to eq(1)
  end

  it 'continues to notify a custom instrumenter after tracing is disabled' do
    instrumenter = CaptureInstrumenter.new
    context = RubyLLM.context { |config| config.instrumenter = instrumenter }
    chat = stub_chat(context)
    chat.ask('traced')
    described_class.disable
    chat.ask('untraced')

    expect(instrumenter.events.count { |name, _payload| name == 'chat.ruby_llm' }).to eq(2)
    expect(spans.size).to eq(1)
  end

  it 'allows application work to run when the sampler drops the trace' do
    dropped = OpenTelemetry::SDK::Trace::TracerProvider.new(sampler: OpenTelemetry::SDK::Trace::Samplers::ALWAYS_OFF)
    allow(OpenTelemetry).to receive(:tracer_provider).and_return(dropped)

    expect(stub_chat.ask('hello')).to eq(response)
    expect(spans).to be_empty
  ensure
    dropped.shutdown
  end

  it 'closes a span even when recording its response attributes fails' do
    tracer = provider.tracer('ruby_llm', RubyLLM::VERSION)
    allow(tracer).to receive(:start_span).and_wrap_original do |original, *args, **kwargs|
      original.call(*args, **kwargs).tap do |span|
        allow(span).to receive(:add_attributes).and_raise(StandardError, 'exporter failure')
      end
    end
    allow(RubyLLM.logger).to receive(:warn)

    expect(stub_chat.ask('hello')).to eq(response)
    expect(spans.size).to eq(1)
  end

  %i[threads fibers].each do |mode|
    it "traces a complete HTTP chat and overlapping nested tools using #{mode}" do
      chat_model = model
      key = OpenTelemetry::Context.create_key('test-context')
      observed = Queue.new
      stub_const('TelemetryNestedChat', Class.new(RubyLLM::Tool) do
        parameter :label

        define_method(:execute) do |label:|
          before = OpenTelemetry::Trace.current_span.context.span_id
          sleep 0.01
          RubyLLM.chat(model: chat_model, protocol: :chat_completions).ask(label)
          observed << [before, OpenTelemetry::Trace.current_span.context.span_id, OpenTelemetry::Context.current.value(key)]
          label
        end
      end)
      stub_request(:post, 'https://api.openai.com/v1/chat/completions').to_return do |request|
        body = JSON.parse(request.body)
        message = { role: 'assistant', content: 'done' }
        if body['tools'] && body['messages'].last['role'] == 'user'
          message[:tool_calls] = %w[alpha beta].map do |label|
            { id: label, type: 'function',
              function: { name: 'telemetry_nested_chat', arguments: { label: }.to_json } }
          end
        end
        finish_reason = message[:tool_calls] ? 'tool_calls' : 'stop'
        { headers: { 'Content-Type' => 'application/json' },
          body: { model: chat_model, choices: [{ message:, finish_reason: }],
                  usage: { prompt_tokens: 4, completion_tokens: 2 } }.to_json }
      end
      OpenTelemetry::Context.with_current(OpenTelemetry::Context.current.set_value(key, 'preserved')) do
        RubyLLM.workflow('nested tools') do
          chat = RubyLLM.chat(model:, protocol: :chat_completions).with_tools(TelemetryNestedChat)
                        .with_tool_options(concurrency: mode)
          expect(chat.ask('Run both tools').content).to eq('done')
        end
      end

      workflow = spans.find { |span| span.name == 'invoke_workflow nested tools' }
      tools = spans.select { |span| span.name == 'execute_tool telemetry_nested_chat' }
      expect(spans.size).to eq(7)
      expect(tools.map(&:parent_span_id)).to eq([workflow.span_id] * 2)
      expect(tools.map(&:start_timestamp).max).to be < tools.map(&:end_timestamp).min
      tools.each do |tool|
        expect(spans.count { |span| span.parent_span_id == tool.span_id }).to eq(1)
      end
      observations = Array.new(observed.size) { observed.pop }
      expect(observations).to match_array(tools.map { |tool| [tool.span_id, tool.span_id, 'preserved'] })
      expect(OpenTelemetry::Context.current.value(key)).to be_nil
    end

    it "parents concurrent tools and nested calls to their workflow step using #{mode}" do
      calls = 2.times.to_h do |index|
        [index, RubyLLM::ToolCall.new(id: "call_#{index}", name: 'lookup', arguments: {})]
      end
      previous = OpenTelemetry::Context.current
      RubyLLM.workflow('answer') do |workflow|
        workflow.step('lookup') do
          RubyLLM::Chat::ToolConcurrency.run(mode, calls) do |call|
            RubyLLM.instrument('tool_call.ruby_llm', tool_name: call.name, tool_call_id: call.id) do
              RubyLLM.instrument('chat.ruby_llm', model: model, provider: 'openai') { :ok }
            end
          end
        end
      end

      workflow = spans.find { |span| span.name == 'invoke_workflow answer' }
      step = spans.find { |span| span.name == 'ruby_llm.workflow_step lookup' }
      tools = spans.select { |span| span.name == 'execute_tool lookup' }
      chats = spans.select { |span| span.name == "chat #{model}" }
      expect(step.parent_span_id).to eq(workflow.span_id)
      expect(tools.size).to eq(2)
      expect(tools.map(&:parent_span_id)).to eq([step.span_id, step.span_id])
      expect(chats.map(&:parent_span_id)).to match_array(tools.map(&:span_id))
      expect(tools.map(&:kind)).to eq(%i[internal internal])
      expect(OpenTelemetry::Context.current).to equal(previous)
    end
  end
end
