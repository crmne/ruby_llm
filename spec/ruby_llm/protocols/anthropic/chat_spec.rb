# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::Chat do
  describe '.parse_completion_response' do
    it 'preserves raw stop_reason as finish_reason' do
      protocol = RubyLLM::Protocols::Anthropic.allocate
      response = instance_double(
        Faraday::Response,
        body: {
          'model' => 'claude-sonnet-4-5',
          'content' => [{ 'type' => 'text', 'text' => 'Hello' }],
          'stop_reason' => 'max_tokens',
          'usage' => {}
        }
      )

      message = protocol.send(:parse_completion_response, response)

      expect(message.finish_reason).to eq('max_tokens')
    end
  end

  describe '.parse_citation' do
    it 'accepts URL schemes regardless of case' do
      citation = described_class.parse_citation({ 'url' => 'HTTPS://example.com/source' })

      expect(citation.url).to eq('HTTPS://example.com/source')
    end
  end

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

    it 'adds cache_control to a system message marked as a cache boundary' do
      msg = RubyLLM::Message.new(role: :system, content: 'Stable instructions').cache_until_here

      blocks = described_class.build_system_content([msg])

      expect(blocks).to eq(
        [
          {
            type: 'text',
            text: 'Stable instructions',
            cache_control: { type: 'ephemeral' }
          }
        ]
      )
    end

    it 'uses configured cache_control for a system cache boundary' do
      msg = RubyLLM::Message.new(role: :system, content: 'Stable instructions').cache_until_here

      blocks = described_class.build_system_content([msg], caching: { ttl: '1h' })

      expect(blocks.dig(0, :cache_control)).to eq(type: 'ephemeral', ttl: '1h')
    end
  end

  describe '.format_messages' do
    it 'drops a turn that rendered no content blocks' do
      messages = [
        RubyLLM::Message.new(role: :user, content: 'Hello'),
        RubyLLM::Message.new(role: :assistant, content: ''),
        RubyLLM::Message.new(role: :user, content: 'Still there?')
      ]

      expect(described_class.format_messages(messages)).to eq(
        [
          { role: 'user', content: [{ type: 'text', text: 'Hello' }] },
          { role: 'user', content: [{ type: 'text', text: 'Still there?' }] }
        ]
      )
    end

    it 'adds cache_control to a tool result marked as a cache boundary' do
      message = RubyLLM::Message.new(role: :tool, content: 'result', tool_call_id: 'tool_1').cache_until_here

      rendered = described_class.format_messages([message], caching: { ttl: '1h' })

      expect(rendered.first[:content].last[:cache_control]).to eq(type: 'ephemeral', ttl: '1h')
    end
  end

  describe '.apply_files_beta' do
    it 'adds the Files API beta when a message references an uploaded file' do
      file = RubyLLM::UploadedFile.new(id: 'file_123', filename: 'proposal.pdf', mime_type: 'application/pdf')
      message = RubyLLM::Message.new(role: :user, content: 'Summarize this', attachments: [file])
      payload = { messages: described_class.format_messages([message]) }

      expect(described_class.apply_files_beta({}, payload)).to eq('anthropic-beta' => 'files-api-2025-04-14')
    end

    it 'leaves the headers alone without a file reference' do
      payload = { messages: [{ role: 'user', content: [{ type: 'text', text: 'Hello' }] }] }

      expect(described_class.apply_files_beta({}, payload)).to eq({})
    end
  end

  describe '.format_message' do
    it 'formats attachments before tool calls' do
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
        content: 'Read this before calling the tool',
        attachments: [text_path],
        tool_calls: tool_calls
      )

      formatted = described_class.format_message(message)

      expect(formatted[:content].first).to eq({ type: 'text', text: 'Read this before calling the tool' })
      expect(formatted[:content].second).to include(type: 'text')
      expect(formatted[:content].second[:text]).to include("<file name='ruby.txt' mime_type='text/plain'>")
      expect(formatted[:content].third).to include(type: 'tool_use', id: 'tool_123')
    end

    it 'does not send finish_reason back to the provider' do
      message = RubyLLM::Message.new(role: :assistant, content: 'Done', finish_reason: 'MAX_TOKENS')

      formatted = described_class.format_message(message)

      expect(formatted).not_to have_key(:finish_reason)
      expect(formatted[:content].first).to eq({ type: 'text', text: 'Done' })
    end

    it 'adds cache_control to a user message marked as a cache boundary' do
      message = RubyLLM::Message.new(role: :user, content: 'Long context').cache_until_here

      formatted = described_class.format_message(message)

      expect(formatted[:content].last).to include(cache_control: { type: 'ephemeral' })
    end
  end

  describe '.render_payload' do
    let(:model) { instance_double(RubyLLM::Model, id: 'claude-sonnet-4-5', max_output_tokens: nil) }

    it 'groups consecutive tool results into a single user message' do
      tool_calls = {
        'tool_1' => RubyLLM::ToolCall.new(id: 'tool_1', name: 'inspect', arguments: {}),
        'tool_2' => RubyLLM::ToolCall.new(id: 'tool_2', name: 'date_calculator', arguments: {})
      }
      messages = [
        RubyLLM::Message.new(role: :user, content: 'Check the date'),
        RubyLLM::Message.new(role: :assistant, content: '', tool_calls: tool_calls),
        RubyLLM::Message.new(role: :tool, content: 'Context inspected', tool_call_id: 'tool_1'),
        RubyLLM::Message.new(role: :tool, content: '2026-07-21', tool_call_id: 'tool_2')
      ]

      payload = described_class.render_payload(
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload[:messages].length).to eq(3)
      expect(payload[:messages].last).to eq(
        role: 'user',
        content: [
          {
            type: 'tool_result',
            tool_use_id: 'tool_1',
            content: [{ type: 'text', text: 'Context inspected' }]
          },
          {
            type: 'tool_result',
            tool_use_id: 'tool_2',
            content: [{ type: 'text', text: '2026-07-21' }]
          }
        ]
      )
    end

    it 'adds top-level automatic cache_control when caching is enabled without explicit boundaries' do
      payload = described_class.render_payload(
        [RubyLLM::Message.new(role: :user, content: 'Hello there')],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: nil,
        caching: { ttl: '1h' }
      )

      expect(payload[:cache_control]).to eq(type: 'ephemeral', ttl: '1h')
    end

    it 'does not add top-level cache_control when an explicit boundary is present' do
      message = RubyLLM::Message.new(role: :user, content: 'Long context').cache_until_here

      payload = described_class.render_payload(
        [message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: nil,
        caching: { ttl: '1h' }
      )

      expect(payload).not_to have_key(:cache_control)
      expect(payload.dig(:messages, 0, :content, -1, :cache_control)).to eq(type: 'ephemeral', ttl: '1h')
    end

    it 'rejects caching options it cannot render' do
      expect do
        described_class.render_payload(
          [RubyLLM::Message.new(role: :user, content: 'Hello there')],
          tools: {},
          temperature: nil,
          model: model,
          stream: false,
          schema: nil,
          caching: { retention: '24h' }
        )
      end.to raise_error(ArgumentError, /Anthropic prompt caching accepts :ttl/)
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
      model = RubyLLM::Model.new(
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

    it 'sends a budget as enabled thinking' do
      payload = render_payload(
        model_id: 'claude-sonnet-4-5',
        thinking: RubyLLM::Thinking::Config.new(budget: 2048),
        reasoning_options: [budget_option]
      )

      expect(payload[:thinking]).to eq(type: 'enabled', budget_tokens: 2048)
      expect(payload).not_to have_key(:output_config)
    end

    it 'turns on adaptive thinking beside effort on generations without a budget' do
      payload = render_payload(
        model_id: 'claude-opus-4-7',
        thinking: RubyLLM::Thinking::Config.new(effort: :xhigh),
        reasoning_options: [effort_option(:low, :medium, :high, :xhigh, :max)]
      )

      expect(payload[:thinking]).to eq(type: 'adaptive')
      expect(payload[:output_config]).to eq(effort: 'xhigh')
    end

    it 'sizes a budget from the effort on generations that take one' do
      payload = render_payload(
        model_id: 'claude-opus-4-5',
        thinking: RubyLLM::Thinking::Config.new(effort: :medium),
        reasoning_options: [effort_option(:low, :medium, :high), budget_option]
      )

      expect(payload[:thinking]).to eq(type: 'enabled', budget_tokens: 4095)
      expect(payload[:output_config]).to eq(effort: 'medium')
    end

    it 'keeps the effort budget under max_tokens and above the minimum' do
      low = render_payload(
        model_id: 'claude-sonnet-4-5',
        thinking: RubyLLM::Thinking::Config.new(effort: :low),
        reasoning_options: [budget_option]
      )

      expect(low[:thinking]).to eq(type: 'enabled', budget_tokens: 1024)
      expect(low[:output_config]).to eq(effort: 'low')
    end

    it 'resolves a bare with_thinking to a request Claude honors' do
      model = RubyLLM::Model.new(
        id: 'claude-opus-4-8',
        provider: 'anthropic',
        metadata: { reasoning_options: [effort_option(:low, :medium, :high, :xhigh, :max)] }
      )
      thinking = RubyLLM::Thinking::Config.default.resolve(model)

      payload = render_payload(model_id: 'claude-opus-4-8', thinking: thinking,
                               reasoning_options: [effort_option(:low, :medium, :high, :xhigh, :max)])

      expect(payload[:thinking]).to eq(type: 'adaptive')
      expect(payload[:output_config]).to eq(effort: 'medium')
    end

    it 'sends a budget the registry does not advertise' do
      payload = render_payload(
        model_id: 'claude-opus-4-7',
        thinking: RubyLLM::Thinking::Config.new(budget: 2048),
        reasoning_options: [effort_option(:low, :medium, :high, :xhigh, :max)]
      )

      expect(payload[:thinking]).to eq(type: 'enabled', budget_tokens: 2048)
    end

    it 'sends effort and budget side by side' do
      payload = render_payload(
        model_id: 'claude-opus-4-5',
        thinking: RubyLLM::Thinking::Config.new(effort: :high, budget: 4096),
        reasoning_options: [effort_option(:low, :medium, :high), budget_option]
      )

      expect(payload[:thinking]).to eq(type: 'enabled', budget_tokens: 4096)
      expect(payload[:output_config]).to eq(effort: 'high')
    end

    it 'asks for adaptive thinking when a display is set without a budget' do
      payload = render_payload(
        model_id: 'claude-opus-4-7',
        thinking: RubyLLM::Thinking::Config.new(effort: :high, display: :summarized),
        reasoning_options: [effort_option(:low, :medium, :high, :xhigh, :max)]
      )

      expect(payload[:thinking]).to eq(type: 'adaptive', display: 'summarized')
      expect(payload[:output_config]).to eq(effort: 'high')
    end

    it 'carries a display on enabled thinking when a budget is set' do
      payload = render_payload(
        model_id: 'claude-sonnet-4-6',
        thinking: RubyLLM::Thinking::Config.new(budget: 4096, display: :summarized),
        reasoning_options: [effort_option(:low, :medium, :high, :max), budget_option]
      )

      expect(payload[:thinking]).to eq(type: 'enabled', budget_tokens: 4096, display: 'summarized')
    end

    it 'merges thinking effort with schema output_config' do
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

      expect(message.tokens.input).to eq(42)
      expect(message.tokens.output).to eq(5)
      expect(message.tokens.cache_read).to eq(21)
      expect(message.tokens.cache_write).to eq(7)
    end
  end

  describe '.build_thinking_block' do
    let(:protocol) { RubyLLM::Protocols::Anthropic.allocate }

    it 'is nil without thinking' do
      expect(protocol.send(:build_thinking_block, nil)).to be_nil
    end

    it 'sends thinking text with its signature' do
      thinking = RubyLLM::Thinking.new(text: 'why', signature: 'sig')

      expect(protocol.send(:build_thinking_block, thinking)).to eq(
        type: 'thinking', thinking: 'why', signature: 'sig'
      )
    end

    it 'omits a missing signature' do
      expect(protocol.send(:build_thinking_block, RubyLLM::Thinking.new(text: 'why'))).to eq(
        type: 'thinking', thinking: 'why'
      )
    end

    it 'sends a signature-only block as redacted thinking' do
      expect(protocol.send(:build_thinking_block, RubyLLM::Thinking.new(signature: 'sig'))).to eq(
        type: 'redacted_thinking', data: 'sig'
      )
    end
  end

  describe '.prepend_thinking_block' do
    let(:protocol) { RubyLLM::Protocols::Anthropic.allocate }

    it 'puts the stored thinking block first' do
      blocks = [{ type: 'text', text: 'hi' }]
      message = RubyLLM::Message.new(role: :assistant, content: 'hi',
                                     thinking: RubyLLM::Thinking.new(text: 'why'))

      result = protocol.send(:prepend_thinking_block, blocks, message)

      expect(result.first[:type]).to eq('thinking')
    end

    it 'leaves the blocks alone when the message has no thinking' do
      blocks = [{ type: 'text', text: 'hi' }]
      message = RubyLLM::Message.new(role: :assistant, content: 'hi')

      expect(protocol.send(:prepend_thinking_block, blocks, message)).to eq(blocks)
    end
  end

  describe 'thinking replay' do
    let(:protocol) { RubyLLM::Protocols::Anthropic.allocate }

    it 'replays a stored thinking block even when the request asks for no thinking' do
      message = RubyLLM::Message.new(
        role: :assistant, content: '',
        tool_calls: { 'toolu_1' => RubyLLM::ToolCall.new(id: 'toolu_1', name: 'weather', arguments: {}) },
        thinking: RubyLLM::Thinking.new(text: 'why', signature: 'sig')
      )

      formatted = protocol.send(:format_message, message, thinking: nil)

      expect(formatted[:content].map { |block| block[:type] }).to eq(%w[thinking tool_use])
    end

    it 'keeps a display-omitted thinking block as thinking, not redacted data' do
      blocks = [{ 'type' => 'thinking', 'thinking' => '', 'signature' => 'sig' }, { 'type' => 'text', 'text' => 'hi' }]
      thinking = RubyLLM::Thinking.build(
        text: protocol.send(:extract_thinking_content, blocks),
        signature: protocol.send(:extract_thinking_signature, blocks)
      )

      expect(protocol.send(:build_thinking_block, thinking)).to eq(type: 'thinking', thinking: '', signature: 'sig')
    end
  end

  describe '.inject_cache_control' do
    let(:protocol) { RubyLLM::Protocols::Anthropic.allocate }

    it 'leaves empty blocks alone' do
      expect(protocol.send(:inject_cache_control, [])).to eq([])
    end

    it 'leaves a block that already carries cache_control alone' do
      blocks = [{ type: 'text', text: 'hi', cache_control: { type: 'ephemeral' } }]

      expect(protocol.send(:inject_cache_control, blocks)).to eq(blocks)
    end

    it 'leaves a trailing block it cannot annotate alone' do
      expect(protocol.send(:inject_cache_control, ['plain'])).to eq(['plain'])
    end

    it 'annotates the trailing block' do
      blocks = [{ type: 'text', text: 'hi' }]

      expect(protocol.send(:inject_cache_control, blocks).last[:cache_control]).to eq(type: 'ephemeral')
    end
  end

  describe '.extract_thinking_signature' do
    let(:protocol) { RubyLLM::Protocols::Anthropic.allocate }

    it 'reads the data field off a redacted thinking block' do
      blocks = [{ 'type' => 'redacted_thinking', 'data' => 'blob' }]

      expect(protocol.send(:extract_thinking_signature, blocks)).to eq('blob')
    end

    it 'is nil when no block carries thinking' do
      expect(protocol.send(:extract_thinking_signature, [{ 'type' => 'text' }])).to be_nil
      expect(protocol.send(:extract_thinking_content, [{ 'type' => 'text' }])).to be_nil
    end

    it 'falls back to the text field of a thinking block' do
      blocks = [{ 'type' => 'thinking', 'text' => 'why' }]

      expect(protocol.send(:extract_thinking_content, blocks)).to eq('why')
    end
  end

  describe '.build_thinking_payload' do
    let(:protocol) { RubyLLM::Protocols::Anthropic.allocate }
    let(:model) { RubyLLM::Model.new(id: 'claude-3-haiku', provider: 'anthropic') }

    def build(thinking)
      protocol.send(:build_thinking_payload, thinking, model, 4096)
    end

    it 'is nil when thinking is off or explicitly none' do
      expect(build(nil)).to be_nil
      expect(build(RubyLLM::Thinking::Config.new(effort: :none))).to be_nil
    end

    it 'sends effort alone when the registry lists no thinking controls' do
      expect(build(RubyLLM::Thinking::Config.new(effort: :high))).to eq(
        output_config: { effort: 'high' }
      )
    end

    it 'keeps a budget out of output_config' do
      expect(build(RubyLLM::Thinking::Config.new(budget: 1024))).to eq(
        thinking: { type: 'enabled', budget_tokens: 1024 }
      )
    end

    it 'asks for adaptive thinking to carry a display without a budget' do
      expect(build(RubyLLM::Thinking::Config.new(display: :summarized))).to eq(
        thinking: { type: 'adaptive', display: 'summarized' }
      )
    end
  end

  describe '.warn_unsupported_citations' do
    it 'warns when citations are asked of a model without them' do
      allow(RubyLLM.logger).to receive(:warn)
      protocol = RubyLLM::Protocols::Anthropic.allocate
      model = instance_double(
        RubyLLM::Model, id: 'claude-3-haiku', supports?: false, reasoning_option: nil, max_output_tokens: 4096
      )

      protocol.send(
        :render_payload, [RubyLLM::Message.new(role: :user, content: 'Hi')],
        tools: {}, temperature: nil, model: model, citations: true
      )

      expect(RubyLLM.logger).to have_received(:warn).with(/does not support citations/)
    end
  end

  describe '.render_count_tokens_payload' do
    it 'keeps the messages request shape without max_tokens or stream' do
      model = RubyLLM::Model.new(id: 'claude-haiku-4-5', provider: 'anthropic')
      messages = [
        RubyLLM::Message.new(role: :system, content: 'Be terse.'),
        RubyLLM::Message.new(role: :user, content: 'Hello')
      ]

      payload = described_class.render_count_tokens_payload(messages, tools: {}, model: model)

      expect(payload[:model]).to eq('claude-haiku-4-5')
      expect(payload[:messages]).to eq([{ role: 'user', content: [{ type: 'text', text: 'Hello' }] }])
      expect(payload[:system]).to eq([{ type: 'text', text: 'Be terse.' }])
      expect(payload).not_to have_key(:max_tokens)
      expect(payload).not_to have_key(:stream)
    end
  end

  describe '.parse_count_tokens_response' do
    it 'reads input_tokens' do
      response = instance_double(Faraday::Response, body: { 'input_tokens' => 42 })

      expect(described_class.parse_count_tokens_response(response)).to eq(42)
    end
  end

  describe 'provider-managed file support' do
    let(:protocol) { RubyLLM::Protocols::Anthropic.allocate }

    it 'accepts images, PDFs and text files' do
      expect(protocol.send(:provider_file_upload_limit)).to be_positive
      expect(
        protocol.send(:provider_file_attachable?,
                      RubyLLM::Attachment.new(StringIO.new('x'), filename: 'a.pdf'))
      ).to be(true)
      expect(
        protocol.send(:provider_file_attachable?,
                      RubyLLM::Attachment.new(StringIO.new('x'), filename: 'a.docx'))
      ).to be(false)
    end
  end
end
