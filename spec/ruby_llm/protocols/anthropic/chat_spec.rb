# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::Chat do
  describe '.build_system_content' do
    let(:logger) { instance_double(Logger, info: nil, debug: nil, error: nil, warn: nil) }

    before { allow(RubyLLM).to receive(:logger).and_return(logger) }

    it 'returns an empty array when no :system messages are present' do
      expect(described_class.build_system_content([])).to eq([])
    end

    it 'returns a single text block for one :system message' do
      msg = RubyLLM::Message.new(role: :system, content: 'Solo system prompt.')

      blocks = described_class.build_system_content([msg])

      expect(blocks).to eq([{ type: 'text', text: 'Solo system prompt.' }])
    end

    it 'returns both text blocks when multiple :system messages are passed' do
      first = RubyLLM::Message.new(role: :system, content: 'Static prompt.')
      second = RubyLLM::Message.new(role: :system, content: 'Per-session context.')

      blocks = described_class.build_system_content([first, second])

      expect(blocks).to eq(
        [
          { type: 'text', text: 'Static prompt.' },
          { type: 'text', text: 'Per-session context.' }
        ]
      )
    end

    it 'does not log a warning when multiple :system messages are passed' do
      first = RubyLLM::Message.new(role: :system, content: 'A')
      second = RubyLLM::Message.new(role: :system, content: 'B')

      described_class.build_system_content([first, second])

      expect(logger).not_to have_received(:warn)
    end

    it 'preserves per-block cache_control on Raw content alongside plain text' do
      cached_raw = RubyLLM::Protocols::Anthropic::Content.new(
        'Cached prefix.',
        cache_control: { type: 'ephemeral' }
      )
      cached_msg = RubyLLM::Message.new(role: :system, content: cached_raw)
      plain_msg = RubyLLM::Message.new(role: :system, content: 'Dynamic suffix.')

      blocks = described_class.build_system_content([cached_msg, plain_msg])

      expect(blocks).to eq(
        [
          { type: 'text', text: 'Cached prefix.', cache_control: { type: 'ephemeral' } },
          { type: 'text', text: 'Dynamic suffix.' }
        ]
      )
    end

    it 'flattens mixed Raw-wrapped and plain string content into a single array' do
      raw = RubyLLM::Content::Raw.new([{ type: 'text', text: 'Raw block.' }])
      raw_msg = RubyLLM::Message.new(role: :system, content: raw)
      plain_msg = RubyLLM::Message.new(role: :system, content: 'Plain block.')

      blocks = described_class.build_system_content([raw_msg, plain_msg])

      expect(blocks).to eq(
        [
          { type: 'text', text: 'Raw block.' },
          { type: 'text', text: 'Plain block.' }
        ]
      )
    end
  end

  describe '.format_message' do
    it 'formats Content attachments before tool calls' do
      text_path = File.expand_path('../../../fixtures/ruby.txt', __dir__)
      tool_calls = {
        'tool_123' => RubyLLM::ToolCall.new(
          id: 'tool_123',
          name: 'test_tool',
          arguments: { 'arg1' => 'value1' }
        )
      }
      message = RubyLLM::Message.new(
        role: :assistant,
        content: RubyLLM::Content.new('Read this before calling the tool', text_path),
        tool_calls: tool_calls
      )

      formatted = described_class.format_message(message)

      expect(formatted[:content].first).to eq({ type: 'text', text: 'Read this before calling the tool' })
      expect(formatted[:content].second).to include(type: 'text')
      expect(formatted[:content].second[:text]).to include("<file name='ruby.txt' mime_type='text/plain'>")
      expect(formatted[:content].third).to include(type: 'tool_use', id: 'tool_123')
    end
  end

  describe '.render_payload' do
    let(:model) { instance_double(RubyLLM::Model::Info, id: 'claude-sonnet-4-5', max_tokens: nil) }

    it 'embeds raw system content blocks unchanged' do
      system_raw = RubyLLM::Protocols::Anthropic::Content.new(
        'avoid greetings',
        cache_control: { type: 'ephemeral' }
      )

      system_message = RubyLLM::Message.new(role: :system, content: system_raw)
      user_message = RubyLLM::Message.new(role: :user, content: 'Hello there')

      payload = described_class.render_payload(
        [system_message, user_message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload[:system]).to eq(system_raw.value)
      expect(payload[:messages].first[:content]).to eq([{ type: 'text', text: 'Hello there' }])
    end

    it 'includes output_config when schema is provided' do
      schema = {
        name: 'response',
        schema: { type: 'object', properties: { name: { type: 'string' } } },
        strict: true
      }
      user_message = RubyLLM::Message.new(role: :user, content: 'Hello')

      payload = described_class.render_payload(
        [user_message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: schema
      )

      expect(payload[:output_config]).to eq(
        format: { type: 'json_schema', schema: { type: 'object', properties: { name: { type: 'string' } } } }
      )
    end

    it 'strips strict key from schema' do
      schema = {
        name: 'response',
        schema: { type: 'object', strict: true, 'strict' => true, properties: { name: { type: 'string' } } },
        strict: true
      }
      user_message = RubyLLM::Message.new(role: :user, content: 'Hello')

      payload = described_class.render_payload(
        [user_message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: schema
      )

      inner_schema = payload.dig(:output_config, :format, :schema)
      expect(inner_schema).not_to have_key(:strict)
      expect(inner_schema).not_to have_key('strict')
    end

    it 'uses canonical wrapped schema format' do
      schema = {
        name: 'PersonSchema',
        schema: {
          type: 'object',
          strict: true,
          properties: { name: { type: 'string' } }
        }
      }
      user_message = RubyLLM::Message.new(role: :user, content: 'Hello')

      payload = described_class.render_payload(
        [user_message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: schema
      )

      expect(payload[:output_config]).to eq(
        format: { type: 'json_schema', schema: { type: 'object', properties: { name: { type: 'string' } } } }
      )
    end

    it 'does not include output_config when schema is nil' do
      user_message = RubyLLM::Message.new(role: :user, content: 'Hello')

      payload = described_class.render_payload(
        [user_message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload).not_to have_key(:output_config)
    end

    it 'does not mutate the original schema' do
      schema = {
        name: 'response',
        schema: { type: 'object', strict: true, properties: { name: { type: 'string' } } },
        strict: true
      }
      user_message = RubyLLM::Message.new(role: :user, content: 'Hello')

      described_class.render_payload(
        [user_message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: schema
      )

      expect(schema[:schema]).to have_key(:strict)
    end
  end

  describe '.render_payload with thinking' do
    let(:user_message) { RubyLLM::Message.new(role: :user, content: 'Hello') }

    def render_payload(model_id:, thinking:, schema: nil, reasoning_options: [])
      model = RubyLLM::Model::Info.new(
        id: model_id,
        provider: 'anthropic',
        metadata: { reasoning_options: reasoning_options }
      )

      described_class.render_payload(
        [user_message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: schema,
        thinking: thinking
      )
    end

    def effort_option(*values)
      { type: 'effort', values: values.map(&:to_s) }
    end

    def budget_option
      { type: 'budget_tokens', min: 1024 }
    end

    it 'sends manual thinking with budget_tokens for budget-only Claude models' do
      payload = render_payload(
        model_id: 'claude-sonnet-4-5',
        thinking: RubyLLM::Thinking::Config.new(budget: 2048),
        reasoning_options: [budget_option]
      )

      expect(payload[:thinking]).to eq(type: 'enabled', budget_tokens: 2048)
      expect(payload).not_to have_key(:output_config)
    end

    it 'sends adaptive thinking with effort for effort-only Claude models' do
      payload = render_payload(
        model_id: 'claude-opus-4-7',
        thinking: RubyLLM::Thinking::Config.new(effort: :xhigh),
        reasoning_options: [effort_option(:low, :medium, :high, :xhigh, :max)]
      )

      expect(payload[:thinking]).to eq(type: 'adaptive')
      expect(payload[:output_config]).to eq(effort: 'xhigh')
    end

    it 'sends adaptive thinking with effort for Claude models that support both thinking options' do
      payload = render_payload(
        model_id: 'claude-opus-4-6',
        thinking: RubyLLM::Thinking::Config.new(effort: :medium),
        reasoning_options: [effort_option(:low, :medium, :high, :max), budget_option]
      )

      expect(payload[:thinking]).to eq(type: 'adaptive')
      expect(payload[:output_config]).to eq(effort: 'medium')
    end

    it 'sends manual thinking with budget for Claude models that support both thinking options' do
      payload = render_payload(
        model_id: 'claude-sonnet-4-6',
        thinking: RubyLLM::Thinking::Config.new(budget: 4096),
        reasoning_options: [effort_option(:low, :medium, :high, :max), budget_option]
      )

      expect(payload[:thinking]).to eq(type: 'enabled', budget_tokens: 4096)
      expect(payload).not_to have_key(:output_config)
    end

    it 'merges adaptive thinking effort with schema output_config' do
      schema = {
        name: 'response',
        schema: { type: 'object', properties: { name: { type: 'string' } } }
      }

      payload = render_payload(
        model_id: 'claude-opus-4-7',
        thinking: RubyLLM::Thinking::Config.new(effort: :high),
        schema: schema,
        reasoning_options: [effort_option(:low, :medium, :high, :xhigh, :max)]
      )

      expect(payload[:thinking]).to eq(type: 'adaptive')
      expect(payload[:output_config]).to eq(
        effort: 'high',
        format: { type: 'json_schema', schema: { type: 'object', properties: { name: { type: 'string' } } } }
      )
    end

    it 'omits thinking when effort is none' do
      payload = render_payload(
        model_id: 'claude-opus-4-7',
        thinking: RubyLLM::Thinking::Config.new(effort: :none),
        reasoning_options: [effort_option(:low, :medium, :high, :xhigh, :max)]
      )

      expect(payload).not_to have_key(:thinking)
      expect(payload).not_to have_key(:output_config)
    end

    it 'raises when a budget is used with effort-only Claude models' do
      expect do
        render_payload(
          model_id: 'claude-opus-4-7',
          thinking: RubyLLM::Thinking::Config.new(budget: 2048),
          reasoning_options: [effort_option(:low, :medium, :high, :xhigh, :max)]
        )
      end.to raise_error(ArgumentError, /budget is not supported/)
    end

    it 'raises when effort is used with budget-only Claude models' do
      expect do
        render_payload(
          model_id: 'claude-sonnet-4-5',
          thinking: RubyLLM::Thinking::Config.new(effort: :medium),
          reasoning_options: [budget_option]
        )
      end.to raise_error(ArgumentError, /effort is not supported/)
    end
  end

  describe '#parse_completion_response' do
    it 'captures cache usage metrics on the message' do
      response_body = {
        'model' => 'claude-sonnet-4-5-20250929',
        'content' => [{ 'type' => 'text', 'text' => 'Hi!' }],
        'usage' => {
          'input_tokens' => 42,
          'output_tokens' => 5,
          'cache_read_input_tokens' => 21,
          'cache_creation_input_tokens' => 7
        }
      }

      response = instance_double(Faraday::Response, body: response_body)

      message = RubyLLM::Protocols::Anthropic.allocate.send(:parse_completion_response, response)

      expect(message.input_tokens).to eq(42)
      expect(message.output_tokens).to eq(5)
      expect(message.cached_tokens).to eq(21)
      expect(message.cache_creation_tokens).to eq(7)
    end
  end
end
