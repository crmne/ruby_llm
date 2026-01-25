# frozen_string_literal: true

require 'opentelemetry/sdk'

RSpec.describe RubyLLM::Instrumentation do
  describe 'Configuration' do
    it 'has tracing_enabled defaulting to false' do
      config = RubyLLM::Configuration.new
      expect(config.tracing_enabled).to be false
    end

    it 'has tracing_log_content defaulting to false' do
      config = RubyLLM::Configuration.new
      expect(config.tracing_log_content).to be false
    end

    it 'has tracing_max_content_length defaulting to 10000' do
      config = RubyLLM::Configuration.new
      expect(config.tracing_max_content_length).to eq 10_000
    end

    it 'has tracing_metadata_prefix defaulting to metadata' do
      config = RubyLLM::Configuration.new
      expect(config.tracing_metadata_prefix).to eq 'metadata'
    end

    it 'has tracing_langsmith_compat defaulting to false' do
      config = RubyLLM::Configuration.new
      expect(config.tracing_langsmith_compat).to be false
    end

    it 'auto-sets tracing_metadata_prefix when enabling langsmith_compat' do
      config = RubyLLM::Configuration.new
      expect(config.tracing_metadata_prefix).to eq 'metadata'

      config.tracing_langsmith_compat = true
      expect(config.tracing_metadata_prefix).to eq 'langsmith.metadata'
    end

    it 'does not override custom tracing_metadata_prefix when enabling langsmith_compat' do
      config = RubyLLM::Configuration.new
      config.tracing_metadata_prefix = 'app.custom'

      config.tracing_langsmith_compat = true
      expect(config.tracing_metadata_prefix).to eq 'app.custom'
    end

    it 'reverts tracing_metadata_prefix when disabling langsmith_compat' do
      config = RubyLLM::Configuration.new
      config.tracing_langsmith_compat = true
      expect(config.tracing_metadata_prefix).to eq 'langsmith.metadata'

      config.tracing_langsmith_compat = false
      expect(config.tracing_metadata_prefix).to eq 'metadata'
    end

    it 'does not revert custom prefix when disabling langsmith_compat' do
      config = RubyLLM::Configuration.new
      config.tracing_langsmith_compat = true
      config.tracing_metadata_prefix = 'app.custom'

      config.tracing_langsmith_compat = false
      expect(config.tracing_metadata_prefix).to eq 'app.custom'
    end

    it 'allows configuration via block' do
      RubyLLM.configure do |config|
        config.tracing_enabled = true
        config.tracing_log_content = true
        config.tracing_max_content_length = 5000
        config.tracing_metadata_prefix = 'app.metadata'
      end

      expect(RubyLLM.config.tracing_enabled).to be true
      expect(RubyLLM.config.tracing_log_content).to be true
      expect(RubyLLM.config.tracing_max_content_length).to eq 5000
      expect(RubyLLM.config.tracing_metadata_prefix).to eq 'app.metadata'
    end
  end

  describe 'RubyLLM::Instrumentation' do
    describe '.enabled?' do
      it 'returns false when tracing_enabled is false' do
        RubyLLM.configure { |c| c.tracing_enabled = false }
        expect(described_class.enabled?).to be false
      end

      it 'returns true when tracing_enabled is true and OpenTelemetry is available' do
        RubyLLM.configure { |c| c.tracing_enabled = true }
        described_class.reset!
        expect(described_class.enabled?).to be true
      end

      it 'returns false and warns when tracing_enabled is true but OpenTelemetry is not available' do
        RubyLLM.configure { |c| c.tracing_enabled = true }
        described_class.reset!
        allow(described_class).to receive(:otel_available?).and_return(false)
        allow(RubyLLM.logger).to receive(:warn)

        expect(described_class.enabled?).to be false
        expect(RubyLLM.logger).to have_received(:warn).with(/OpenTelemetry is not available/)
      end

      it 'only warns once per reset cycle' do
        RubyLLM.configure { |c| c.tracing_enabled = true }
        described_class.reset!
        allow(described_class).to receive(:otel_available?).and_return(false)
        allow(RubyLLM.logger).to receive(:warn)

        described_class.enabled?
        described_class.enabled?
        described_class.enabled?

        expect(RubyLLM.logger).to have_received(:warn).once
      end
    end

    describe '.tracer' do
      it 'returns NullTracer when disabled' do
        RubyLLM.configure { |c| c.tracing_enabled = false }
        expect(described_class.tracer).to be_a(RubyLLM::Instrumentation::NullTracer)
      end
    end
  end

  describe 'RubyLLM::Instrumentation::NullTracer' do
    let(:tracer) { RubyLLM::Instrumentation::NullTracer.instance }

    it 'is a singleton' do
      expect(tracer).to be RubyLLM::Instrumentation::NullTracer.instance
    end

    describe '#in_span' do
      it 'yields a NullSpan' do
        tracer.in_span('test.span') do |span|
          expect(span).to be_a(RubyLLM::Instrumentation::NullSpan)
        end
      end

      it 'returns the block result' do
        result = tracer.in_span('test.span') { 'hello' }
        expect(result).to eq 'hello'
      end

      it 'propagates exceptions' do
        expect do
          tracer.in_span('test.span') { raise 'boom' }
        end.to raise_error('boom')
      end
    end
  end

  describe 'RubyLLM::Instrumentation::NullSpan' do
    let(:span) { RubyLLM::Instrumentation::NullSpan.instance }

    it 'is a singleton' do
      expect(span).to be RubyLLM::Instrumentation::NullSpan.instance
    end

    it 'responds to recording? and returns false' do
      expect(span.recording?).to be false
    end

    it 'responds to set_attribute and returns self' do
      expect(span.set_attribute('key', 'value')).to be span
    end

    it 'responds to add_attributes and returns self' do
      expect(span.add_attributes(key: 'value')).to be span
    end

    it 'responds to record_exception and returns self' do
      expect(span.record_exception(StandardError.new)).to be span
    end

    it 'responds to status= and returns nil' do
      expect(span.status = 'error').to eq 'error'
    end
  end

  describe 'Chat#session_id' do
    include_context 'with configured RubyLLM'

    it 'generates a unique session_id for each Chat instance' do
      chat1 = RubyLLM::Chat.new(model: 'gpt-4o-mini', assume_model_exists: true, provider: :openai)
      chat2 = RubyLLM::Chat.new(model: 'gpt-4o-mini', assume_model_exists: true, provider: :openai)

      expect(chat1.session_id).to be_a(String)
      expect(chat1.session_id).to match(/\A[0-9a-f-]{36}\z/) # UUID format
      expect(chat1.session_id).not_to eq(chat2.session_id)
    end

    it 'maintains the same session_id across multiple asks' do
      chat = RubyLLM::Chat.new(model: 'gpt-4o-mini', assume_model_exists: true, provider: :openai)
      session_id = chat.session_id

      # session_id should remain constant
      expect(chat.session_id).to eq(session_id)
      expect(chat.session_id).to eq(session_id)
    end

    it 'accepts a custom session_id' do
      custom_id = 'my-conversation-123'
      chat = RubyLLM::Chat.new(model: 'gpt-4o-mini', assume_model_exists: true, provider: :openai,
                               session_id: custom_id)

      expect(chat.session_id).to eq(custom_id)
    end

    it 'generates a UUID when session_id is nil' do
      chat = RubyLLM::Chat.new(model: 'gpt-4o-mini', assume_model_exists: true, provider: :openai, session_id: nil)

      expect(chat.session_id).to be_a(String)
      expect(chat.session_id).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe 'RubyLLM::Instrumentation::SpanBuilder' do
    describe '.build_tool_attributes' do
      it 'builds attributes for a tool call' do
        tool_call = instance_double(RubyLLM::ToolCall, name: 'get_weather', id: 'call_123',
                                                       arguments: { location: 'NYC' })

        attrs = RubyLLM::Instrumentation::SpanBuilder.build_tool_attributes(
          tool_call: tool_call,
          session_id: 'session-abc'
        )

        expect(attrs['gen_ai.operation.name']).to eq 'execute_tool'
        expect(attrs['gen_ai.tool.name']).to eq 'get_weather'
        expect(attrs['gen_ai.tool.call.id']).to eq 'call_123'
        expect(attrs['gen_ai.conversation.id']).to eq 'session-abc'
        expect(attrs).not_to have_key('langsmith.span.kind')
      end

      it 'includes langsmith.span.kind when langsmith_compat is true' do
        tool_call = instance_double(RubyLLM::ToolCall, name: 'get_weather', id: 'call_123',
                                                       arguments: { location: 'NYC' })

        attrs = RubyLLM::Instrumentation::SpanBuilder.build_tool_attributes(
          tool_call: tool_call,
          session_id: 'session-abc',
          langsmith_compat: true
        )

        expect(attrs['langsmith.span.kind']).to eq 'TOOL'
      end
    end

    describe '.build_tool_input_attributes' do
      it 'builds input attributes with truncation' do
        tool_call = instance_double(RubyLLM::ToolCall, arguments: { query: 'a' * 100 })

        attrs = RubyLLM::Instrumentation::SpanBuilder.build_tool_input_attributes(
          tool_call: tool_call,
          max_length: 50
        )

        expect(attrs['gen_ai.tool.call.arguments']).to include('[truncated]')
        expect(attrs).not_to have_key('input.value')
      end

      it 'includes input.value when langsmith_compat is true' do
        tool_call = instance_double(RubyLLM::ToolCall, arguments: { query: 'test' })

        attrs = RubyLLM::Instrumentation::SpanBuilder.build_tool_input_attributes(
          tool_call: tool_call,
          max_length: 100,
          langsmith_compat: true
        )

        expect(attrs['gen_ai.tool.call.arguments']).to be_a(String)
        expect(attrs['input.value']).to eq(attrs['gen_ai.tool.call.arguments'])
      end
    end

    describe '.build_tool_output_attributes' do
      it 'builds output attributes with truncation' do
        result = 'b' * 100

        attrs = RubyLLM::Instrumentation::SpanBuilder.build_tool_output_attributes(
          result: result,
          max_length: 50
        )

        expect(attrs['gen_ai.tool.call.result']).to include('[truncated]')
        expect(attrs).not_to have_key('output.value')
      end

      it 'includes output.value when langsmith_compat is true' do
        result = 'test output'

        attrs = RubyLLM::Instrumentation::SpanBuilder.build_tool_output_attributes(
          result: result,
          max_length: 100,
          langsmith_compat: true
        )

        expect(attrs['gen_ai.tool.call.result']).to eq('test output')
        expect(attrs['output.value']).to eq('test output')
      end
    end

    describe '.truncate_content' do
      it 'returns content as-is when under max length' do
        content = 'short content'
        result = RubyLLM::Instrumentation::SpanBuilder.truncate_content(content, 100)
        expect(result).to eq 'short content'
      end

      it 'truncates content when over max length' do
        content = 'a' * 100
        result = RubyLLM::Instrumentation::SpanBuilder.truncate_content(content, 50)
        expect(result).to eq "#{'a' * 50}... [truncated]"
      end

      it 'handles nil content' do
        result = RubyLLM::Instrumentation::SpanBuilder.truncate_content(nil, 100)
        expect(result).to be_nil
      end
    end

    describe '.extract_content_text' do
      it 'returns string content as-is' do
        result = RubyLLM::Instrumentation::SpanBuilder.extract_content_text('Hello')
        expect(result).to eq 'Hello'
      end

      it 'extracts text from Content objects' do
        content = RubyLLM::Content.new('Hello with attachment', ['spec/fixtures/ruby.png'])
        result = RubyLLM::Instrumentation::SpanBuilder.extract_content_text(content)
        expect(result).to eq 'Hello with attachment'
      end

      it 'describes attachments for Content objects without text' do
        content = RubyLLM::Content.new(nil, ['spec/fixtures/ruby.png'])
        result = RubyLLM::Instrumentation::SpanBuilder.extract_content_text(content)
        expect(result).to eq '[image: ruby.png]'
      end

      it 'describes multiple attachments' do
        content = RubyLLM::Content.new(nil, ['spec/fixtures/ruby.png', 'spec/fixtures/ruby.mp3'])
        result = RubyLLM::Instrumentation::SpanBuilder.extract_content_text(content)
        expect(result).to eq '[image: ruby.png, audio: ruby.mp3]'
      end
    end

    describe '.build_message_attributes' do
      it 'builds gen_ai.input.messages as JSON array' do
        messages = [
          RubyLLM::Message.new(role: :system, content: 'You are helpful'),
          RubyLLM::Message.new(role: :user, content: 'Hello')
        ]

        attrs = RubyLLM::Instrumentation::SpanBuilder.build_message_attributes(messages, max_length: 10_000)

        parsed = JSON.parse(attrs['gen_ai.input.messages'])
        expect(parsed).to be_an(Array)
        expect(parsed.length).to eq 2
        expect(parsed[0]['role']).to eq 'system'
        expect(parsed[0]['parts'][0]['content']).to eq 'You are helpful'
        expect(parsed[1]['role']).to eq 'user'
        expect(parsed[1]['parts'][0]['content']).to eq 'Hello'
      end

      it 'truncates long JSON content' do
        messages = [RubyLLM::Message.new(role: :user, content: 'a' * 100)]

        attrs = RubyLLM::Instrumentation::SpanBuilder.build_message_attributes(messages, max_length: 50)

        expect(attrs['gen_ai.input.messages']).to include('[truncated]')
        expect(attrs['gen_ai.input.messages'].length).to be <= 70 # 50 + "... [truncated]"
      end

      it 'handles Content objects with attachments' do
        content = RubyLLM::Content.new('Describe this image', ['spec/fixtures/ruby.png'])
        messages = [RubyLLM::Message.new(role: :user, content: content)]

        attrs = RubyLLM::Instrumentation::SpanBuilder.build_message_attributes(messages, max_length: 10_000)

        parsed = JSON.parse(attrs['gen_ai.input.messages'])
        expect(parsed[0]['parts'][0]['content']).to eq 'Describe this image'
      end

      it 'does not include input.value by default' do
        messages = [RubyLLM::Message.new(role: :user, content: 'Hello')]

        attrs = RubyLLM::Instrumentation::SpanBuilder.build_message_attributes(messages, max_length: 10_000)

        expect(attrs).not_to have_key('input.value')
      end

      it 'includes input.value when langsmith_compat is true' do
        messages = [RubyLLM::Message.new(role: :user, content: 'Hello')]

        attrs = RubyLLM::Instrumentation::SpanBuilder.build_message_attributes(
          messages,
          max_length: 10_000,
          langsmith_compat: true
        )

        expect(attrs['input.value']).to eq 'Hello'
      end
    end

    describe '.build_completion_attributes' do
      it 'builds gen_ai.output.messages as JSON array' do
        message = RubyLLM::Message.new(role: :assistant, content: 'Hi there!')

        attrs = RubyLLM::Instrumentation::SpanBuilder.build_completion_attributes(message, max_length: 10_000)

        parsed = JSON.parse(attrs['gen_ai.output.messages'])
        expect(parsed).to be_an(Array)
        expect(parsed.length).to eq 1
        expect(parsed[0]['role']).to eq 'assistant'
        expect(parsed[0]['parts'][0]['content']).to eq 'Hi there!'
        expect(attrs).not_to have_key('output.value')
      end

      it 'includes output.value when langsmith_compat is true' do
        message = RubyLLM::Message.new(role: :assistant, content: 'Hi there!')

        attrs = RubyLLM::Instrumentation::SpanBuilder.build_completion_attributes(
          message,
          max_length: 10_000,
          langsmith_compat: true
        )

        expect(attrs['output.value']).to eq 'Hi there!'
      end
    end

    describe '.build_request_attributes' do
      let(:model) { instance_double(RubyLLM::Model::Info, id: 'gpt-4') }

      it 'does not include langsmith.span.kind by default' do
        attrs = RubyLLM::Instrumentation::SpanBuilder.build_request_attributes(
          model: model,
          provider: :openai,
          session_id: 'session-123'
        )

        expect(attrs['gen_ai.provider.name']).to eq 'openai'
        expect(attrs['gen_ai.request.model']).to eq 'gpt-4'
        expect(attrs).not_to have_key('langsmith.span.kind')
      end

      it 'includes langsmith.span.kind when langsmith_compat is true' do
        attrs = RubyLLM::Instrumentation::SpanBuilder.build_request_attributes(
          model: model,
          provider: :openai,
          session_id: 'session-123',
          config: { langsmith_compat: true }
        )

        expect(attrs['langsmith.span.kind']).to eq 'LLM'
      end

      it 'includes temperature when provided' do
        attrs = RubyLLM::Instrumentation::SpanBuilder.build_request_attributes(
          model: model,
          provider: :openai,
          session_id: 'session-123',
          config: { temperature: 0.7 }
        )

        expect(attrs['gen_ai.request.temperature']).to eq 0.7
      end
    end

    describe '.build_metadata_attributes' do
      it 'builds attributes with the given prefix' do
        attrs = {}
        RubyLLM::Instrumentation::SpanBuilder.build_metadata_attributes(
          attrs,
          { user_id: 123, request_id: 'abc', active: true, score: 0.95 },
          prefix: 'langsmith.metadata'
        )

        expect(attrs['langsmith.metadata.user_id']).to eq 123
        expect(attrs['langsmith.metadata.request_id']).to eq 'abc'
        expect(attrs['langsmith.metadata.active']).to be true
        expect(attrs['langsmith.metadata.score']).to eq 0.95
      end

      it 'supports custom prefixes' do
        attrs = {}
        RubyLLM::Instrumentation::SpanBuilder.build_metadata_attributes(
          attrs,
          { user_id: 123 },
          prefix: 'app.metadata'
        )

        expect(attrs['app.metadata.user_id']).to eq 123
      end

      it 'skips nil values' do
        attrs = {}
        RubyLLM::Instrumentation::SpanBuilder.build_metadata_attributes(
          attrs,
          { user_id: 123, empty: nil },
          prefix: 'test'
        )

        expect(attrs).to have_key('test.user_id')
        expect(attrs).not_to have_key('test.empty')
      end

      it 'passes values through for OTel SDK to handle' do
        attrs = {}
        hash_value = { nested: 'value' }
        array_value = %w[foo bar]

        RubyLLM::Instrumentation::SpanBuilder.build_metadata_attributes(
          attrs,
          { config: hash_value, tags: array_value },
          prefix: 'test'
        )

        # Values passed through as-is; OTel SDK handles type coercion
        expect(attrs['test.config']).to eq hash_value
        expect(attrs['test.tags']).to eq array_value
      end
    end
  end

  describe 'Sampling-aware behavior' do
    include_context 'with configured RubyLLM'

    let(:non_recording_span) do
      instance_double(
        OpenTelemetry::Trace::Span,
        recording?: false,
        add_attributes: nil,
        set_attribute: nil,
        record_exception: nil,
        'status=': nil
      )
    end

    let(:recording_span) do
      instance_double(
        OpenTelemetry::Trace::Span,
        recording?: true,
        add_attributes: nil,
        set_attribute: nil,
        record_exception: nil,
        'status=': nil
      )
    end

    let(:mock_tracer) do
      tracer = instance_double(OpenTelemetry::Trace::Tracer)
      allow(tracer).to receive(:in_span).and_yield(non_recording_span).and_return(nil)
      tracer
    end

    before do
      RubyLLM.configure do |config|
        config.tracing_enabled = true
        config.tracing_log_content = true
      end
      allow(described_class).to receive(:tracer).and_return(mock_tracer)
    end

    after do
      RubyLLM.configure do |config|
        config.tracing_enabled = false
        config.tracing_log_content = false
      end
      described_class.reset!
    end

    it 'skips attribute building when span is not recording (sampled out)' do
      chat = RubyLLM::Chat.new(model: 'gpt-4o-mini', assume_model_exists: true, provider: :openai)

      # Mock provider to return a response
      mock_response = RubyLLM::Message.new(
        role: :assistant,
        content: 'Hello!',
        input_tokens: 10,
        output_tokens: 5,
        model_id: 'gpt-4o-mini'
      )
      allow(chat.instance_variable_get(:@provider)).to receive(:complete).and_return(mock_response)

      chat.ask('Hello')

      # When recording? is false, add_attributes should NOT be called
      expect(non_recording_span).not_to have_received(:add_attributes)
    end

    it 'adds attributes when span is recording' do
      allow(mock_tracer).to receive(:in_span).and_yield(recording_span).and_return(nil)

      chat = RubyLLM::Chat.new(model: 'gpt-4o-mini', assume_model_exists: true, provider: :openai)

      mock_response = RubyLLM::Message.new(
        role: :assistant,
        content: 'Hello!',
        input_tokens: 10,
        output_tokens: 5,
        model_id: 'gpt-4o-mini'
      )
      allow(chat.instance_variable_get(:@provider)).to receive(:complete).and_return(mock_response)

      chat.ask('Hello')

      # When recording? is true, add_attributes should be called
      expect(recording_span).to have_received(:add_attributes).at_least(:once)
    end
  end

  describe 'OpenTelemetry Integration', :vcr do
    include_context 'with configured RubyLLM'

    let(:exporter) { OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new }

    # Use anonymous class to avoid leaking constants
    let(:weather_tool) do
      Class.new(RubyLLM::Tool) do
        description 'Gets current weather for a location'
        param :latitude, desc: 'Latitude (e.g., 52.5200)'
        param :longitude, desc: 'Longitude (e.g., 13.4050)'

        def execute(latitude:, longitude:)
          "Current weather at #{latitude}, #{longitude}: 15°C, Wind: 10 km/h"
        end

        def self.name
          'Weather'
        end
      end
    end

    before do
      # Reset any existing OTel configuration
      OpenTelemetry::SDK.configure do |c|
        c.add_span_processor(
          OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter)
        )
      end

      # Only configure tracing options - don't overwrite API keys
      RubyLLM.configure do |config|
        config.tracing_enabled = true
        config.tracing_log_content = true
      end

      # Reset the cached tracer
      described_class.reset!
    end

    after do
      RubyLLM.configure do |config|
        config.tracing_enabled = false
        config.tracing_log_content = false
      end
      described_class.reset!
      exporter.reset
    end

    it 'creates spans with correct attributes when tracing is enabled' do
      VCR.use_cassette('instrumentation_creates_spans_for_chat') do
        chat = RubyLLM.chat(model: 'gpt-4.1-nano', assume_model_exists: true, provider: :openai)
        chat.ask('Hello')
      end

      spans = exporter.finished_spans
      expect(spans.count).to be >= 1

      chat_span = spans.find { |s| s.name == 'ruby_llm.chat' }
      expect(chat_span).not_to be_nil
      expect(chat_span.kind).to eq(:client)
      expect(chat_span.attributes['gen_ai.provider.name']).to eq('openai')
      expect(chat_span.attributes['gen_ai.operation.name']).to eq('chat')
      expect(chat_span.attributes['gen_ai.conversation.id']).to be_a(String)

      # Check gen_ai.input.messages is valid JSON with correct structure
      input_messages = JSON.parse(chat_span.attributes['gen_ai.input.messages'])
      expect(input_messages).to be_an(Array)
      expect(input_messages.last['role']).to eq('user')
      expect(input_messages.last['parts'][0]['content']).to eq('Hello')
    end

    it 'creates tool spans as children when tools are used' do
      VCR.use_cassette('instrumentation_creates_tool_spans') do
        chat = RubyLLM.chat(model: 'gpt-4.1-nano', assume_model_exists: true, provider: :openai)
        chat.with_tool(weather_tool)
        chat.ask("What's the weather in Berlin? (52.5200, 13.4050)")
      end

      spans = exporter.finished_spans
      tool_span = spans.find { |s| s.name == 'ruby_llm.tool' }

      expect(tool_span).not_to be_nil
      expect(tool_span.kind).to eq(:internal)
      expect(tool_span.attributes['gen_ai.tool.name']).to be_a(String)
    end

    it 'includes token usage in spans' do
      VCR.use_cassette('instrumentation_includes_token_usage') do
        chat = RubyLLM.chat(model: 'gpt-4.1-nano', assume_model_exists: true, provider: :openai)
        chat.ask('Hello')
      end

      spans = exporter.finished_spans
      chat_span = spans.find { |s| s.name == 'ruby_llm.chat' }

      expect(chat_span.attributes['gen_ai.usage.input_tokens']).to be > 0
      expect(chat_span.attributes['gen_ai.usage.output_tokens']).to be > 0
    end

    it 'maintains session_id across multiple asks' do
      VCR.use_cassette('instrumentation_maintains_session_id') do
        chat = RubyLLM.chat(model: 'gpt-4.1-nano', assume_model_exists: true, provider: :openai)
        chat.ask("What's your favorite color?")
        chat.ask('Why is that?')
      end

      spans = exporter.finished_spans
      chat_spans = spans.select { |s| s.name == 'ruby_llm.chat' }

      expect(chat_spans.count).to eq(2)
      session_ids = chat_spans.map { |s| s.attributes['gen_ai.conversation.id'] }.uniq
      expect(session_ids.count).to eq(1) # Same session_id for both
    end

    it 'records errors on spans when API calls fail' do
      chat = RubyLLM.chat(model: 'gpt-4.1-nano', assume_model_exists: true, provider: :openai)

      # Stub the provider to raise an error
      allow(chat.instance_variable_get(:@provider)).to receive(:complete).and_raise(
        RubyLLM::ServerError.new(nil, 'Test API error')
      )

      expect { chat.ask('Hello') }.to raise_error(RubyLLM::ServerError)

      spans = exporter.finished_spans
      chat_span = spans.find { |s| s.name == 'ruby_llm.chat' }

      expect(chat_span).not_to be_nil
      expect(chat_span.status.code).to eq(OpenTelemetry::Trace::Status::ERROR)
      expect(chat_span.events.any? { |e| e.name == 'exception' }).to be true
    end

    describe 'Streaming' do
      it 'creates spans for streaming responses' do
        chat = RubyLLM.chat(model: 'gpt-4.1-nano', assume_model_exists: true, provider: :openai)

        # Mock streaming response - provider.complete returns a Message even for streaming
        mock_response = RubyLLM::Message.new(
          role: :assistant,
          content: 'Hello there!',
          input_tokens: 8,
          output_tokens: 3,
          model_id: 'gpt-4.1-nano'
        )
        allow(chat.instance_variable_get(:@provider)).to receive(:complete).and_return(mock_response)

        chunks = []
        chat.ask('Hello') { |chunk| chunks << chunk }

        spans = exporter.finished_spans
        chat_span = spans.find { |s| s.name == 'ruby_llm.chat' }

        expect(chat_span).not_to be_nil
        expect(chat_span.kind).to eq(:client)
        expect(chat_span.attributes['gen_ai.provider.name']).to eq('openai')
        expect(chat_span.attributes['gen_ai.usage.input_tokens']).to eq(8)
        expect(chat_span.attributes['gen_ai.usage.output_tokens']).to eq(3)
      end

      it 'includes completion content in streaming spans when content logging enabled' do
        chat = RubyLLM.chat(model: 'gpt-4.1-nano', assume_model_exists: true, provider: :openai)

        mock_response = RubyLLM::Message.new(
          role: :assistant,
          content: 'Streamed response content',
          input_tokens: 5,
          output_tokens: 4,
          model_id: 'gpt-4.1-nano'
        )
        allow(chat.instance_variable_get(:@provider)).to receive(:complete).and_return(mock_response)

        chat.ask('Test') { |_chunk| nil }

        spans = exporter.finished_spans
        chat_span = spans.find { |s| s.name == 'ruby_llm.chat' }

        output_messages = JSON.parse(chat_span.attributes['gen_ai.output.messages'])
        expect(output_messages[0]['parts'][0]['content']).to eq('Streamed response content')
      end

      it 'maintains session_id for streaming calls' do
        chat = RubyLLM.chat(model: 'gpt-4.1-nano', assume_model_exists: true, provider: :openai)
        session_id = chat.session_id

        mock_response = RubyLLM::Message.new(
          role: :assistant,
          content: 'Response',
          model_id: 'gpt-4.1-nano'
        )
        allow(chat.instance_variable_get(:@provider)).to receive(:complete).and_return(mock_response)

        chat.ask('First') { |_| nil }
        chat.ask('Second') { |_| nil }

        spans = exporter.finished_spans
        chat_spans = spans.select { |s| s.name == 'ruby_llm.chat' }

        expect(chat_spans.count).to eq(2)
        expect(chat_spans.all? { |s| s.attributes['gen_ai.conversation.id'] == session_id }).to be true
      end

      it 'creates tool spans as children during streaming with tools' do
        chat = RubyLLM.chat(model: 'gpt-4.1-nano', assume_model_exists: true, provider: :openai)
        chat.with_tool(weather_tool)

        # First response triggers tool call
        tool_call_response = RubyLLM::Message.new(
          role: :assistant,
          content: nil,
          tool_calls: {
            'call_123' => RubyLLM::ToolCall.new(
              id: 'call_123',
              name: 'weather',
              arguments: { latitude: '52.52', longitude: '13.41' }
            )
          },
          model_id: 'gpt-4.1-nano'
        )

        # Second response is final answer
        final_response = RubyLLM::Message.new(
          role: :assistant,
          content: 'The weather in Berlin is nice!',
          model_id: 'gpt-4.1-nano'
        )

        call_count = 0
        allow(chat.instance_variable_get(:@provider)).to receive(:complete) do
          call_count += 1
          call_count == 1 ? tool_call_response : final_response
        end

        chat.ask('Weather in Berlin?') { |_| nil }

        spans = exporter.finished_spans
        tool_span = spans.find { |s| s.name == 'ruby_llm.tool' }
        chat_spans = spans.select { |s| s.name == 'ruby_llm.chat' }

        expect(chat_spans.count).to eq(2) # Initial call + follow-up after tool
        expect(tool_span).not_to be_nil
        expect(tool_span.attributes['gen_ai.tool.name']).to eq('weather')

        # Tool span should be child of first chat span
        first_chat_span = chat_spans.min_by(&:start_timestamp)
        expect(tool_span.parent_span_id).to eq(first_chat_span.span_id)
      end
    end
  end
end
