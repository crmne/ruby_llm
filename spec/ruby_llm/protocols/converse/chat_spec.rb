# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Converse::Chat do
  describe '.parse_completion_body' do
    it 'exposes AWS inputTokens as-is (already non-cached) and keeps cache buckets separate' do
      # Per AWS, inputTokens already excludes cache; a real payload sends the non-cached count
      # directly, with cache read/write reported separately.
      response_body = {
        'modelId' => 'anthropic.claude-sonnet-4-5-20250929-v1:0',
        'output' => {
          'message' => {
            'content' => [{ 'text' => 'Hi!' }]
          }
        },
        'usage' => {
          'inputTokens' => 50,
          'outputTokens' => 5,
          'cacheReadInputTokens' => 40,
          'cacheWriteInputTokens' => 10
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.tokens.input).to eq(50)
      expect(message.tokens.output).to eq(5)
      expect(message.tokens.cache_read).to eq(40)
      expect(message.tokens.cache_write).to eq(10)
    end

    it 'does not subtract cache buckets or floor to zero when the cached prefix exceeds fresh input' do
      response_body = {
        'modelId' => 'anthropic.claude-sonnet-4-5-20250929-v1:0',
        'output' => {
          'message' => {
            'content' => [{ 'text' => 'Hi!' }]
          }
        },
        'usage' => {
          'inputTokens' => 3,
          'outputTokens' => 5,
          'cacheReadInputTokens' => 7714,
          'cacheWriteInputTokens' => 327
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.tokens.input).to eq(3)
      expect(message.tokens.cache_read).to eq(7714)
      expect(message.tokens.cache_write).to eq(327)
    end

    it 'preserves raw stopReason as finish_reason' do
      response_body = {
        'modelId' => 'amazon.nova-lite-v1:0',
        'output' => {
          'message' => {
            'content' => [{ 'text' => 'Hi!' }]
          }
        },
        'stopReason' => 'guardrail_intervened',
        'usage' => {}
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.finish_reason).to eq('guardrail_intervened')
    end

    it 'falls back to the request model when Bedrock omits modelId' do
      response_body = {
        'output' => {
          'message' => {
            'content' => [{ 'text' => 'Hi!' }]
          }
        },
        'usage' => {}
      }

      provider = double(config: RubyLLM.config, connection: nil)
      model = instance_double(RubyLLM::Model, id: 'openai.gpt-oss-120b-1:0')
      protocol = RubyLLM::Protocols::Converse.new(provider, model)
      response = instance_double(Faraday::Response, body: response_body)
      message = protocol.send(:parse_completion_body, response_body, raw: response)

      expect(message.model).to eq('openai.gpt-oss-120b-1:0')
    end

    it 'extracts thinking tokens from top-level reasoningTokens' do
      response_body = {
        'output' => {
          'message' => {
            'content' => [{ 'text' => 'Hi!' }]
          }
        },
        'usage' => {
          'inputTokens' => 10,
          'outputTokens' => 5,
          'reasoningTokens' => 7
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.tokens.thinking).to eq(7)
    end

    it 'extracts thinking tokens from outputTokensDetails reasoningTokens' do
      response_body = {
        'output' => {
          'message' => {
            'content' => [{ 'text' => 'Hi!' }]
          }
        },
        'usage' => {
          'inputTokens' => 10,
          'outputTokens' => 5,
          'outputTokensDetails' => { 'reasoningTokens' => 7 }
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.tokens.thinking).to eq(7)
    end
  end

  describe '.format_tool_result_content' do
    it 'uses a placeholder when the tool returns no content' do
      msg = instance_double(RubyLLM::Message, content: '', attachments: [])
      result = described_class.format_tool_result_content(msg)

      expect(result).to eq([{ text: '(no output)' }])
    end
  end

  describe '.render_payload' do
    let(:model) do
      instance_double(RubyLLM::Model,
                      id: 'anthropic.claude-haiku-4-5-20251001-v1:0',
                      max_output_tokens: nil,
                      metadata: {})
    end

    let(:base_args) do
      {
        tools: {},
        temperature: nil,
        model: model,
        stream: false
      }
    end

    def render_payload(messages = [], **overrides)
      described_class.render_payload(messages, **base_args, **overrides)
    end

    it 'appends cachePoint to a system message marked as a cache boundary' do
      message = RubyLLM::Message.new(role: :system, content: 'Stable instructions').cache_until_here!

      payload = render_payload([message, RubyLLM::Message.new(role: :user, content: 'Hi')])

      expect(payload[:system].last).to eq(cachePoint: { type: 'default' })
    end

    it 'appends cachePoint to a user message marked as a cache boundary' do
      message = RubyLLM::Message.new(role: :user, content: 'Long context').cache_until_here!

      payload = render_payload([message])

      expect(payload.dig(:messages, 0, :content).last).to eq(cachePoint: { type: 'default' })
    end

    it 'uses configured ttl for an explicit cache boundary' do
      message = RubyLLM::Message.new(role: :user, content: 'Long context').cache_until_here!

      payload = render_payload([message], caching: { ttl: '1h' })

      expect(payload.dig(:messages, 0, :content).last).to eq(cachePoint: { type: 'default', ttl: '1h' })
    end

    it 'adds an automatic cachePoint to the last cacheable message when caching is enabled' do
      first = RubyLLM::Message.new(role: :user, content: 'Stable context')
      second = RubyLLM::Message.new(role: :user, content: 'Latest question')

      payload = render_payload([first, second], caching: { ttl: '1h' })

      expect(payload.dig(:messages, 0, :content).last).not_to have_key(:cachePoint)
      expect(payload.dig(:messages, 1, :content).last).to eq(cachePoint: { type: 'default', ttl: '1h' })
    end

    it 'does not add automatic cachePoint when an explicit boundary exists' do
      first = RubyLLM::Message.new(role: :user, content: 'Stable context').cache_until_here!
      second = RubyLLM::Message.new(role: :user, content: 'Latest question')

      payload = render_payload([first, second], caching: { ttl: '1h' })

      expect(payload.dig(:messages, 0, :content).last).to eq(cachePoint: { type: 'default', ttl: '1h' })
      expect(payload.dig(:messages, 1, :content).last).not_to have_key(:cachePoint)
    end

    it 'rejects caching options it cannot render' do
      expect do
        render_payload(caching: { retention: '24h' })
      end.to raise_error(ArgumentError, /Bedrock Converse prompt caching accepts :ttl/)
    end

    context 'when schema is provided' do
      let(:schema) do
        {
          name: 'response',
          schema: {
            type: 'object',
            properties: { name: { type: 'string' } },
            required: ['name'],
            additionalProperties: false
          },
          strict: true
        }
      end

      it 'includes outputConfig with stringified schema' do
        payload = render_payload(schema: schema)

        output_config = payload[:outputConfig]
        expect(output_config).not_to be_nil
        expect(output_config[:textFormat][:type]).to eq('json_schema')

        json_schema = output_config[:textFormat][:structure][:jsonSchema]
        expect(json_schema[:name]).to eq('response')
        expect(json_schema[:schema]).to be_a(String)

        parsed = JSON.parse(json_schema[:schema])
        expect(parsed['type']).to eq('object')
        expect(parsed['properties']).to eq({ 'name' => { 'type' => 'string' } })
      end

      it 'strips :strict from the schema' do
        payload = render_payload(schema: schema)

        json_schema = payload[:outputConfig][:textFormat][:structure][:jsonSchema]
        parsed = JSON.parse(json_schema[:schema])
        expect(parsed).not_to have_key('strict')
        expect(parsed).not_to have_key(:strict)
      end

      it 'uses schema name and inner schema' do
        custom_schema = RubyLLM::Utils.deep_dup(schema)
        custom_schema[:name] = 'PersonSchema'

        payload = render_payload(schema: custom_schema)

        json_schema = payload[:outputConfig][:textFormat][:structure][:jsonSchema]
        expect(json_schema[:name]).to eq('PersonSchema')

        parsed = JSON.parse(json_schema[:schema])
        expect(parsed['type']).to eq('object')
        expect(parsed['properties']).to eq({ 'name' => { 'type' => 'string' } })
        expect(parsed).not_to have_key('name')
        expect(parsed).not_to have_key('schema')
      end

      it 'does not mutate the original schema' do
        original = RubyLLM::Utils.deep_dup(schema)
        render_payload(schema: schema)
        expect(schema).to eq(original)
      end
    end

    context 'when schema is nil' do
      it 'does not include outputConfig' do
        payload = render_payload(schema: nil)
        expect(payload).not_to have_key(:outputConfig)
      end
    end

    context 'when thinking is configured' do
      def bedrock_model(id, budget_schema)
        schema = budget_schema ? { reasoningConfig: { budgetTokens: budget_schema } } : {}
        instance_double(RubyLLM::Model,
                        id: id,
                        max_output_tokens: nil,
                        metadata: { converse: { additionalRequestFieldsSchema: JSON.generate(schema) } })
      end

      let(:enumerated_budget_model) do
        bedrock_model('us.anthropic.claude-sonnet-5',
                      { type: 'enum', enum: { low: 1024, medium: 40_000, high: 63_999 },
                        minimum: 1024, maximum: 63_999 })
      end

      let(:ranged_budget_model) do
        bedrock_model('us.anthropic.claude-haiku-4-5-20251001-v1:0',
                      { type: 'integer', default: 2048, minimum: 1024, maximum: 63_999 })
      end

      def thinking(effort: nil, budget: nil)
        RubyLLM::Thinking::Config.new(effort: effort, budget: budget)
      end

      it 'maps effort onto the budget level the model names for it' do
        payload = render_payload(model: enumerated_budget_model, thinking: thinking(effort: :medium))

        expect(payload[:additionalModelRequestFields]).to eq(
          reasoning_config: { type: 'enabled', budget_tokens: 40_000 }
        )
      end

      it 'refuses an effort the model does not name instead of buying its largest budget' do
        expect { render_payload(model: enumerated_budget_model, thinking: thinking(effort: :xhigh)) }
          .to raise_error(ArgumentError, /no reasoning budget for effort "xhigh".*low, medium, high/m)
      end

      it 'spreads effort across the range when the model does not enumerate budgets' do
        payload = render_payload(model: ranged_budget_model, thinking: thinking(effort: :low))

        expect(payload[:additionalModelRequestFields]).to eq(
          reasoning_config: { type: 'enabled', budget_tokens: 1024 }
        )
      end

      it 'keeps a derived budget under an explicit max_output_tokens' do
        payload = render_payload(model: enumerated_budget_model, thinking: thinking(effort: :high),
                                 max_output_tokens: 8000)

        expect(payload[:additionalModelRequestFields]).to eq(
          reasoning_config: { type: 'enabled', budget_tokens: 7999 }
        )
      end

      it 'refuses a max_output_tokens that leaves no room for the smallest budget' do
        expect do
          render_payload(model: enumerated_budget_model, thinking: thinking(effort: :high), max_output_tokens: 500)
        end.to raise_error(ArgumentError, /at least 1024 tokens.*max_output_tokens: 500.*room for 499/m)
      end

      it 'still clamps under max_output_tokens when the model states no minimum' do
        model = bedrock_model('us.anthropic.claude-sonnet-5', { type: 'enum', enum: { low: 1024, high: 8192 } })

        payload = render_payload(model: model, thinking: thinking(effort: :low), max_output_tokens: 500)

        expect(payload[:additionalModelRequestFields]).to eq(
          reasoning_config: { type: 'enabled', budget_tokens: 499 }
        )
      end

      it 'leaves a budget the caller chose alone' do
        payload = render_payload(model: enumerated_budget_model, thinking: thinking(budget: 40_000),
                                 max_output_tokens: 500)

        expect(payload[:additionalModelRequestFields]).to eq(
          reasoning_config: { type: 'enabled', budget_tokens: 40_000 }
        )
      end

      it 'prefers an explicit budget over effort' do
        payload = render_payload(model: enumerated_budget_model, thinking: thinking(effort: :high, budget: 5000))

        expect(payload[:additionalModelRequestFields]).to eq(
          reasoning_config: { type: 'enabled', budget_tokens: 5000 }
        )
      end

      it 'sends an explicit budget without requiring an effort' do
        payload = render_payload(model: enumerated_budget_model, thinking: thinking(budget: 5000))

        expect(payload[:additionalModelRequestFields]).to eq(
          reasoning_config: { type: 'enabled', budget_tokens: 5000 }
        )
      end

      it 'maps effort for regional entries that carry no converse metadata of their own' do
        model = instance_double(RubyLLM::Model,
                                id: 'eu.anthropic.claude-sonnet-5',
                                max_output_tokens: nil,
                                metadata: {})

        payload = render_payload(model: model, thinking: thinking(effort: :low))

        expect(payload[:additionalModelRequestFields]).to eq(
          reasoning_config: { type: 'enabled', budget_tokens: 1024 }
        )
      end

      it 'sends reasoning_effort for models that do not advertise a budget' do
        payload = render_payload(model: bedrock_model('openai.gpt-oss-120b-1:0', nil),
                                 thinking: thinking(effort: :high))

        expect(payload[:additionalModelRequestFields]).to eq(reasoning_effort: 'high')
      end

      it 'reads the model out of an inference profile ARN' do
        model = instance_double(RubyLLM::Model, max_output_tokens: nil, metadata: {},
                                                id: 'arn:aws:bedrock:us-west-2:123456789012:' \
                                                    'inference-profile/us.amazon.nova-2-lite-v1:0')

        payload = render_payload(model: model, thinking: thinking(effort: :low))

        expect(payload[:additionalModelRequestFields]).to eq(
          reasoningConfig: { type: 'enabled', maxReasoningEffort: 'low' }
        )
      end

      it 'maps effort onto a budget for a Claude model reached through an inference profile ARN' do
        model = instance_double(RubyLLM::Model, max_output_tokens: nil, metadata: {},
                                                id: 'arn:aws:bedrock:us-west-2:123456789012:' \
                                                    'inference-profile/us.anthropic.claude-sonnet-5')

        payload = render_payload(model: model, thinking: thinking(effort: :low))

        expect(payload[:additionalModelRequestFields]).to eq(
          reasoning_config: { type: 'enabled', budget_tokens: 1024 }
        )
      end

      it 'refuses a token budget on a model that takes an effort' do
        model = bedrock_model('us.amazon.nova-2-lite-v1:0', nil)

        expect { render_payload(model: model, thinking: thinking(budget: 20_000)) }
          .to raise_error(ArgumentError, /takes a reasoning effort, not a token budget of 20000/)
      end

      it 'omits reasoning fields when effort is none' do
        payload = render_payload(model: enumerated_budget_model, thinking: thinking(effort: :none))

        expect(payload).not_to have_key(:additionalModelRequestFields)
      end
    end

    it 'does not send finish_reason back to the provider' do
      message = RubyLLM::Message.new(role: :assistant, content: 'Done', finish_reason: 'MAX_TOKENS')

      payload = render_payload([message], schema: nil)

      expect(payload[:messages].first).not_to have_key(:finishReason)
      expect(payload[:messages].first[:content]).to eq([{ text: 'Done' }])
    end
  end

  describe '.format_tool_config' do
    def tool(name: 'lookup', description: 'Looks things up', schema: nil, provider_options: {})
      instance_double(
        RubyLLM::Tool,
        name: name, description: description, parameters_schema: schema,
        declared_parameters: {}, provider_options: provider_options
      )
    end

    it 'is nil without tools' do
      expect(described_class.format_tool_config({}, nil)).to be_nil
    end

    it 'renders a tool spec with a default input schema' do
      config = described_class.format_tool_config({ 'lookup' => tool }, nil)

      expect(config[:tools].first[:toolSpec]).to include(name: 'lookup', description: 'Looks things up')
      expect(config[:tools].first[:toolSpec][:inputSchema][:json]).to include('type' => 'object')
      expect(config).not_to have_key(:toolChoice)
    end

    it 'leaves toolChoice alone when the request states no preference' do
      config = described_class.format_tool_config({ 'lookup' => tool }, { choice: nil })

      expect(config).not_to have_key(:toolChoice)
    end

    it 'maps every tool choice Bedrock understands' do
      expect(described_class.format_tool_config({ 'lookup' => tool }, { choice: :auto })[:toolChoice]).to eq(auto: {})
      expect(described_class.format_tool_config({ 'lookup' => tool },
                                                { choice: :required })[:toolChoice]).to eq(any: {})
      expect(described_class.format_tool_config({ 'lookup' => tool }, { choice: 'lookup' })[:toolChoice]).to eq(
        tool: { name: 'lookup' }
      )
    end

    it 'omits toolChoice when the request asks for no tool' do
      config = described_class.format_tool_config({ 'lookup' => tool }, { choice: :none })

      expect(config).not_to have_key(:toolChoice)
    end

    it 'merges the tool provider options into the spec' do
      config = described_class.format_tool_config(
        { 'lookup' => tool(provider_options: { cachePoint: { type: 'default' } }) }, nil
      )

      expect(config[:tools].first).to include(cachePoint: { type: 'default' })
    end
  end

  describe '.format_reasoning_fields' do
    let(:model_without_budget) do
      instance_double(RubyLLM::Model, id: 'anthropic.claude-haiku-4-5', metadata: {},
                                      capabilities: ['reasoning'])
    end

    def reasoning_fields(thinking, model: model_without_budget)
      protocol = described_class
      target = Object.new
      target.extend(protocol)
      target.instance_variable_set(:@model, model)
      target.send(:format_reasoning_fields, thinking, model)
    end

    it 'is nil when thinking is off' do
      expect(reasoning_fields(nil)).to be_nil
      expect(reasoning_fields(RubyLLM::Thinking::Config.new)).to be_nil
    end

    it 'is nil for an explicit none effort' do
      expect(reasoning_fields(RubyLLM::Thinking::Config.new(effort: :none))).to be_nil
    end

    it 'maps effort to an advertised token budget' do
      model = instance_double(
        RubyLLM::Model,
        id: 'anthropic.claude-test',
        metadata: {
          converse: {
            additionalRequestFieldsSchema: JSON.generate(
              reasoningConfig: { budgetTokens: { enum: { low: 1024, high: 8192 }, minimum: 1024, maximum: 8192 } }
            )
          }
        }
      )

      expect(reasoning_fields(RubyLLM::Thinking::Config.new(effort: :high), model: model)).to eq(
        reasoning_config: { type: 'enabled', budget_tokens: 8192 }
      )
    end

    it 'sends a flat effort otherwise' do
      expect(reasoning_fields(RubyLLM::Thinking::Config.new(effort: :low))).to eq(reasoning_effort: 'low')
    end

    it 'falls back to a token budget' do
      expect(reasoning_fields(RubyLLM::Thinking::Config.new(budget: 2048))).to eq(
        reasoning_config: { type: 'enabled', budget_tokens: 2048 }
      )
    end
  end

  describe '.format_thinking_block' do
    it 'is nil without thinking' do
      expect(described_class.format_thinking_block(nil)).to be_nil
    end

    it 'sends reasoning text with its signature' do
      thinking = RubyLLM::Thinking.new(text: 'because', signature: 'sig')

      expect(described_class.format_thinking_block(thinking)).to eq(
        reasoningContent: { reasoningText: { text: 'because', signature: 'sig' } }
      )
    end

    it 'omits a missing signature' do
      expect(described_class.format_thinking_block(RubyLLM::Thinking.new(text: 'because'))).to eq(
        reasoningContent: { reasoningText: { text: 'because' } }
      )
    end

    it 'sends a signature-only block as redacted content' do
      expect(described_class.format_thinking_block(RubyLLM::Thinking.new(signature: 'sig'))).to eq(
        reasoningContent: { redactedContent: 'sig' }
      )
    end
  end

  describe '.parse_thinking' do
    it 'is empty when no block carries reasoning' do
      expect(described_class.parse_thinking([{ 'text' => 'hi' }])).to eq([nil, nil])
    end

    it 'ignores a reasoningContent block that is not a hash' do
      expect(described_class.parse_thinking([{ 'reasoningContent' => 'nope' }])).to eq([nil, nil])
    end

    it 'reads redacted content as the signature' do
      blocks = [{ 'reasoningContent' => { 'redactedContent' => 'sig' } }]

      expect(described_class.parse_thinking(blocks)).to eq([nil, 'sig'])
    end

    it 'preserves omitted reasoning text as an empty string' do
      blocks = [{ 'reasoningContent' => { 'reasoningText' => { 'text' => '', 'signature' => 'sig' } } }]

      text, signature = described_class.parse_thinking(blocks)
      thinking = RubyLLM::Thinking.build(text:, signature:)

      expect(described_class.format_thinking_block(thinking)).to eq(
        reasoningContent: { reasoningText: { text: '', signature: 'sig' } }
      )
    end

    it 'joins reasoning text across blocks and keeps the first signature' do
      blocks = [
        { 'reasoningContent' => { 'reasoningText' => { 'text' => 'one ' } } },
        { 'reasoningContent' => { 'reasoningText' => { 'text' => 'two', 'signature' => 'sig' } } }
      ]

      expect(described_class.parse_thinking(blocks)).to eq(['one two', 'sig'])
    end
  end

  describe '.format_messages' do
    it 'groups consecutive tool results into one user message' do
      call_a = RubyLLM::ToolCall.new(id: 'call_a', name: 'lookup', arguments: {})
      call_b = RubyLLM::ToolCall.new(id: 'call_b', name: 'lookup', arguments: {})
      messages = [
        RubyLLM::Message.new(role: :assistant, content: '',
                             tool_calls: { 'call_a' => call_a, 'call_b' => call_b }),
        RubyLLM::Message.new(role: :tool, content: 'first', tool_call_id: 'call_a'),
        RubyLLM::Message.new(role: :tool, content: 'second', tool_call_id: 'call_b'),
        RubyLLM::Message.new(role: :user, content: 'thanks')
      ]

      rendered = described_class.format_messages(messages)

      expect(rendered.map { |message| message[:role] }).to eq(%w[assistant user user])
      expect(rendered[1][:content].length).to eq(2)
    end

    it 'drops a message that renders to nothing' do
      messages = [RubyLLM::Message.new(role: :user, content: '')]

      expect(described_class.format_messages(messages)).to eq([])
    end

    it 'closes with the trailing tool results' do
      call = RubyLLM::ToolCall.new(id: 'call_a', name: 'lookup', arguments: {})
      messages = [
        RubyLLM::Message.new(role: :assistant, content: '', tool_calls: { 'call_a' => call }),
        RubyLLM::Message.new(role: :tool, content: 'result', tool_call_id: 'call_a')
      ]

      rendered = described_class.format_messages(messages)

      expect(rendered.last[:role]).to eq('user')
      expect(rendered.last[:content].first[:toolResult][:toolUseId]).to eq('call_a')
    end
  end

  describe '.render_count_tokens_payload' do
    let(:model) do
      instance_double(RubyLLM::Model,
                      id: 'anthropic.claude-haiku-4-5-20251001-v1:0',
                      max_output_tokens: nil,
                      metadata: {})
    end

    it 'wraps the converse request without inferenceConfig' do
      messages = [
        RubyLLM::Message.new(role: :system, content: 'Be terse.'),
        RubyLLM::Message.new(role: :user, content: 'Hello')
      ]

      payload = described_class.render_count_tokens_payload(messages, tools: {}, model: model)

      request = payload.dig(:input, :converse)
      expect(request[:messages]).to eq([{ role: 'user', content: [{ text: 'Hello' }] }])
      expect(request[:system]).to eq([{ text: 'Be terse.' }])
      expect(request).not_to have_key(:inferenceConfig)
    end
  end

  describe '.parse_count_tokens_response' do
    it 'reads inputTokens' do
      response = instance_double(Faraday::Response, body: { 'inputTokens' => 42 })

      expect(described_class.parse_count_tokens_response(response)).to eq(42)
    end
  end

  describe 'citations' do
    it 'parses citationsContent blocks into citations with response spans' do
      response_body = {
        'output' => {
          'message' => {
            'content' => [
              {
                'citationsContent' => {
                  'citations' => [
                    {
                      'location' => { 'documentChar' => { 'documentIndex' => 0, 'start' => 0, 'end' => 73 } },
                      'sourceContent' => [{ 'text' => 'Matz created Ruby in 1993. ' }],
                      'title' => 'facts'
                    }
                  ],
                  'content' => [{ 'text' => 'Ruby was created by Matz.' }]
                }
              },
              { 'text' => ' It was released publicly in 1995.' }
            ]
          }
        },
        'usage' => {}
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.content).to eq('Ruby was created by Matz. It was released publicly in 1995.')
      citation = message.citations.first
      expect(citation.title).to eq('facts')
      expect(citation.cited_text).to eq('Matz created Ruby in 1993. ')
      expect(citation.source_index).to eq(0)
      expect(message.content[citation.start_index...citation.end_index]).to eq(citation.text)
    end

    it 'converts exclusive documentPage ends to inclusive 1-indexed pages' do
      citation = described_class.parse_citation(
        {
          'location' => { 'documentPage' => { 'documentIndex' => 0, 'start' => 1, 'end' => 2 } },
          'sourceContent' => [{ 'text' => 'Sample PDF' }],
          'title' => 'sample'
        }
      )

      expect(citation.start_page).to eq(1)
      expect(citation.end_page).to eq(1)
    end

    it 'reads search result citations with their developer-provided source' do
      citation = described_class.parse_citation(
        {
          'location' => { 'searchResultLocation' => { 'searchResultIndex' => 0, 'start' => 0, 'end' => 1 } },
          'source' => 'https://example.com/ruby-facts',
          'sourceContent' => [{ 'text' => 'Matz created Ruby.' }],
          'title' => 'Ruby Facts'
        }
      )

      expect(citation.url).to eq('https://example.com/ruby-facts')
      expect(citation.title).to eq('Ruby Facts')
      expect(citation.source_index).to eq(0)
    end

    it 'reads web locations from grounded citations' do
      citation = described_class.parse_citation(
        { 'location' => { 'web' => { 'url' => 'https://ruby-lang.org', 'domain' => 'ruby-lang.org' } } }
      )

      expect(citation.url).to eq('https://ruby-lang.org')
      expect(citation.cited_text).to be_nil
    end

    it 'accepts URL schemes regardless of case' do
      citation = described_class.parse_citation(
        { 'location' => { 'web' => { 'url' => 'HTTPS://ruby-lang.org' } } }
      )

      expect(citation.url).to eq('HTTPS://ruby-lang.org')
    end

    it 'parses grounded turns into server tool calls and web citations' do
      response_body = {
        'output' => {
          'message' => {
            'content' => [
              {
                'toolUse' => {
                  'input' => { 'query' => 'latest ruby' },
                  'name' => 'nova_grounding',
                  'toolUseId' => 'tooluse_1',
                  'type' => 'server_tool_use'
                }
              },
              {
                'toolResult' => {
                  'content' => [{ 'text' => '[HIDDEN]' }],
                  'status' => 'success',
                  'toolUseId' => 'tooluse_1',
                  'type' => 'nova_grounding_result'
                }
              },
              { 'text' => 'Ruby 4.0.6 is the latest stable version' },
              {
                'citationsContent' => {
                  'citations' => [
                    { 'location' => { 'web' => { 'url' => 'https://ruby-lang.org', 'domain' => 'ruby-lang.org' } } }
                  ]
                }
              },
              { 'text' => '.' }
            ]
          }
        },
        'usage' => {}
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.tool_calls).to be_nil
      expect(message.server_tool_calls.map(&:type)).to eq(%w[server_tool_use nova_grounding_result])
      expect(message.server_tool_calls.first.name).to eq('nova_grounding')
      expect(message.content).to eq('Ruby 4.0.6 is the latest stable version.')
      expect(message.citations.first.url).to eq('https://ruby-lang.org')
    end

    it 'keeps toolUse blocks with the plain tool_use type as function calls' do
      blocks = [
        { 'toolUse' => { 'toolUseId' => 'tooluse_1', 'name' => 'weather', 'input' => {}, 'type' => 'tool_use' } }
      ]

      expect(described_class.parse_tool_calls(blocks)).to have_key('tooluse_1')
      expect(described_class.extract_server_tool_calls(blocks)).to be_empty
    end

    it 'renders SearchResults tool output as citable searchResult blocks' do
      results = RubyLLM::SearchResults.new(
        title: 'Ruby Facts',
        url: 'https://example.com/ruby-facts',
        text: 'Matz created Ruby in 1993.'
      )
      msg = instance_double(RubyLLM::Message, content: results.to_json, attachments: [])

      expect(described_class.format_tool_result_content(msg)).to eq(
        [
          {
            searchResult: {
              source: 'https://example.com/ruby-facts',
              title: 'Ruby Facts',
              content: [{ text: 'Matz created Ruby in 1993.' }],
              citations: { enabled: true }
            }
          }
        ]
      )
    end
  end

  describe '.provider_file_attachable?' do
    it 'only uploads text formats the S3 document renderer accepts' do
      accepted = RubyLLM::Attachment.new(StringIO.new('notes'), filename: 'notes.txt')
      rejected = RubyLLM::Attachment.new(StringIO.new('{}'), filename: 'notes.json')

      expect(described_class.provider_file_attachable?(accepted)).to be(true)
      expect(described_class.provider_file_attachable?(rejected)).to be(false)
    end
  end
end
