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

  describe 'with content' do
    before { described_class.enable(content: true) }

    def json_attribute(span, name)
      JSON.parse(span.attributes.fetch(name))
    end

    it 'records instructions, input messages, and output messages' do
      stub_chat.with_instructions('Be brief').ask('What is Ruby?')

      span = spans.sole
      expect(json_attribute(span, 'gen_ai.system_instructions')).to eq([{ 'type' => 'text', 'content' => 'Be brief' }])
      expect(json_attribute(span, 'gen_ai.input.messages'))
        .to eq([{ 'role' => 'user', 'parts' => [{ 'type' => 'text', 'content' => 'What is Ruby?' }] }])
      expect(json_attribute(span, 'gen_ai.output.messages')).to eq(
        [{ 'role' => 'assistant', 'parts' => [{ 'type' => 'text', 'content' => 'private response' }],
           'finish_reason' => 'stop' }]
      )
    end

    it 'records tool calls and their results in the conversation' do
      call = RubyLLM::ToolCall.new(id: 'call_1', name: 'lookup', arguments: { 'city' => 'Berlin' })
      messages = [RubyLLM::Message.new(role: :user, content: 'Weather?'),
                  RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { 'call_1' => call }),
                  RubyLLM::Message.new(role: :tool, content: 'Sunny', tool_call_id: 'call_1')]
      RubyLLM.instrument('chat.ruby_llm', provider: 'openai', model:, input_messages: messages) { nil }

      expect(json_attribute(spans.sole, 'gen_ai.input.messages').drop(1)).to eq(
        [{ 'role' => 'assistant',
           'parts' => [{ 'type' => 'tool_call', 'id' => 'call_1', 'name' => 'lookup',
                         'arguments' => { 'city' => 'Berlin' } }] },
         { 'role' => 'tool', 'parts' => [{ 'type' => 'tool_call_response', 'id' => 'call_1', 'response' => 'Sunny' }] }]
      )
    end

    it 'describes attachments without their bytes' do
      image = File.expand_path('../fixtures/ruby.png', __dir__)
      stub_chat.ask('Describe this', with: image)

      parts = json_attribute(spans.sole, 'gen_ai.input.messages').first['parts']
      expect(parts.last).to eq('type' => 'attachment', 'modality' => 'image', 'mime_type' => 'image/png',
                               'filename' => 'ruby.png')
      expect(spans.sole.attributes.to_s).not_to include(Base64.strict_encode64(File.binread(image))[0, 40])
    end

    it 'records tool arguments and results' do
      payload = { tool_name: 'lookup', tool_call_id: 'call_1', tool_arguments: { 'city' => 'Berlin' } }
      RubyLLM.instrument('tool_call.ruby_llm', payload) { |event| event[:result] = { 'forecast' => 'sunny' } }

      span = spans.sole
      expect(json_attribute(span, 'gen_ai.tool.call.arguments')).to eq('city' => 'Berlin')
      expect(json_attribute(span, 'gen_ai.tool.call.result')).to eq('forecast' => 'sunny')
    end

    it 'records a text tool result as it is, and nothing for a call without one' do
      RubyLLM.instrument('tool_call.ruby_llm', tool_name: 'lookup', tool_call_id: 'call_1') do |event|
        event[:result] = 'Sunny'
      end
      RubyLLM.instrument('tool_call.ruby_llm', tool_name: 'lookup', tool_call_id: 'call_2') { nil }

      answered, unanswered = spans
      expect(answered.attributes['gen_ai.tool.call.result']).to eq('Sunny')
      expect(unanswered.attributes.keys).not_to include('gen_ai.tool.call.result', 'gen_ai.tool.call.arguments')
    end

    it 'records no output for a chat that raises' do
      chat = stub_chat
      allow(chat.instance_variable_get(:@provider)).to receive(:complete).and_raise(RubyLLM::Error, 'failed')
      allow(RubyLLM.logger).to receive(:warn)

      expect { chat.ask('Hello') }.to raise_error(RubyLLM::Error)
      expect(RubyLLM.logger).not_to have_received(:warn)
      expect(spans.sole.attributes.keys).to include('gen_ai.input.messages')
      expect(spans.sole.attributes.keys).not_to include('gen_ai.output.messages')
    end

    it 'stops recording content when enabled again without it' do
      described_class.enable
      stub_chat.ask('private prompt')

      expect(spans.sole.attributes.keys).not_to include('gen_ai.input.messages', 'gen_ai.output.messages')
    end
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

  describe 'transcription spans' do
    let(:audio) { File.expand_path('../fixtures/ruby.wav', __dir__) }

    def stub_transcription_stream
      events = [
        { type: 'transcript.text.delta', delta: 'private transcript' },
        { type: 'transcript.text.done', text: 'private transcript', usage: { input_tokens: 3, output_tokens: 1 } }
      ].map { |event| "data: #{event.to_json}\n\n" }.join
      stub_request(:post, 'https://api.openai.com/v1/audio/transcriptions')
        .to_return(body: events, headers: { 'Content-Type' => 'text/event-stream' })
    end

    it 'marks a streamed transcription and keeps the span active through its callbacks' do
      stub_transcription_stream
      chunks = []
      result = RubyLLM.transcribe(
        audio, model: model_for(:openai, :streaming_transcription), provider: :openai
      ) do |chunk|
        chunks << chunk
        expect(spans).to be_empty
        expect(OpenTelemetry::Trace.current_span.recording?).to be(true)
      end

      expect(result.text).to eq('private transcript')
      expect(chunks.last).to be_done
      expect(spans.sole.attributes).to include(
        'gen_ai.operation.name' => 'transcription', 'gen_ai.request.stream' => true
      )
      expect(spans.sole.attributes.to_s).not_to include('private')
    end

    it 'keeps the streaming flag when the transcription callback raises' do
      stub_transcription_stream
      previous = OpenTelemetry::Context.current

      expect do
        RubyLLM.transcribe(audio, model: model_for(:openai, :streaming_transcription), provider: :openai) do
          raise 'private callback error'
        end
      end.to raise_error(RuntimeError, 'private callback error')

      expect(OpenTelemetry::Context.current).to equal(previous)
      expect(spans.sole.status.code).to eq(OpenTelemetry::Trace::Status::ERROR)
      expect(spans.sole.attributes).to include('gen_ai.request.stream' => true, 'error.type' => 'RuntimeError')
      expect(spans.sole.attributes.to_s).not_to include('private')
    end

    it 'omits the streaming flag from a buffered transcription' do
      stub_request(:post, 'https://api.openai.com/v1/audio/transcriptions')
        .to_return_json(body: { text: 'private transcript', usage: { input_tokens: 3, output_tokens: 1 } })

      result = RubyLLM.transcribe(audio, model: model_for(:openai, :streaming_transcription), provider: :openai)

      expect(result.text).to eq('private transcript')
      expect(spans.sole.attributes).not_to have_key('gen_ai.request.stream')
    end
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

  describe 'standalone operation response models' do
    def complete_standalone_operation(operation, reported: true)
      provider_slug = { moderate: :openai, rerank: :cohere, judge: :typesafe }.fetch(operation)
      requested_model = case operation
                        when :moderate then RubyLLM.config.default_moderation_model
                        when :rerank then model_for(:cohere, :rerank)
                        when :judge then model_for(:typesafe, :judgment)
                        end
      response_model = requested_model if reported
      response = case operation
                 when :moderate then RubyLLM::Moderation.new(id: 'modr-telemetry', model: response_model, results: [])
                 when :rerank then RubyLLM::Rerank.new(model: response_model, results: [])
                 when :judge then RubyLLM::Judgment.new(model: response_model, answers: {})
                 end
      model_info, adapter = RubyLLM::Models.resolve(requested_model, provider: provider_slug, config: RubyLLM.config)
      allow(RubyLLM::Models).to receive(:resolve).and_return([model_info, adapter])
      allow(adapter).to receive(operation).and_return(response)
      arguments = operation == :rerank ? ['private query', ['private document']] : ['private input']
      options = { model: requested_model, provider: provider_slug }
      options[:questions] = { urgent: { type: :probability, instructions: 'private question' } } if operation == :judge

      result = RubyLLM.public_send(operation, *arguments, **options)
      expect(result).to equal(response)
      [result, requested_model]
    end

    %i[moderate rerank judge].each do |operation|
      it "records the returned model on #{operation} spans without exporting content" do
        result, requested_model = complete_standalone_operation(operation)

        expect(result.model).to eq(requested_model)
        expect(spans.sole.attributes).to include(
          'gen_ai.request.model' => requested_model, 'gen_ai.response.model' => result.model
        )
        expect(spans.sole.attributes.to_s).not_to include('private')
      end

      it "keeps an unknown response model unknown on #{operation} spans" do
        result, requested_model = complete_standalone_operation(operation, reported: false)

        expect(result.model).to be_nil
        expect(spans.sole.attributes['gen_ai.request.model']).to eq(requested_model)
        expect(spans.sole.attributes).not_to have_key('gen_ai.response.model')
      end
    end
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

  it 'records the requested transcription temperature, including an explicit zero' do
    stub_request(:post, 'https://api.openai.com/v1/audio/transcriptions')
      .to_return_json(body: { text: 'private transcript', usage: { input_tokens: 3, output_tokens: 1 } })
    audio = File.expand_path('../fixtures/ruby.wav', __dir__)
    transcription_model = model_for(:openai, :transcription)

    [0.2, 0, nil].each do |temperature|
      RubyLLM.transcribe(audio, model: transcription_model, provider: :openai, temperature: temperature)
    end

    expect(spans.map { |span| span.attributes['gen_ai.request.temperature'] }).to eq([0.2, 0, nil])
    expect(spans.last.attributes).not_to have_key('gen_ai.request.temperature')
    expect(spans.map(&:attributes).to_s).not_to include('private')
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

  it 'traces a code execution run inside its tool call' do
    sandbox = FakeSandbox.new { FakeSandbox.result(exit_code: 2) }
    chat = RubyLLM.context { |config| config.sandbox = sandbox }.chat(model:).with_code_execution
    call = RubyLLM::ToolCall.new(id: 'call_code', name: 'run_code',
                                 arguments: { 'language' => 'shell', 'code' => 'exit 2' })
    RubyLLM.instrument('tool_call.ruby_llm', tool_name: call.name, tool_call_id: call.id) do
      chat.tools[:run_code].call(language: 'shell', code: 'exit 2')
    end

    tool = spans.find { |span| span.name == 'execute_tool run_code' }
    run = spans.find { |span| span.name == 'ruby_llm.code_execution shell' }
    expect(run.parent_span_id).to eq(tool.span_id)
    expect(run.kind).to eq(:internal)
    expect(run.attributes).to include('ruby_llm.code_execution.language' => 'shell',
                                      'ruby_llm.code_execution.exit_code' => 2,
                                      'ruby_llm.code_execution.timed_out' => false)
    expect(run.attributes['ruby_llm.code_execution.duration']).to be_a(Float)
  end
end
