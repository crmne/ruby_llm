# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic::Chat do
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
      cached_raw = RubyLLM::Providers::Anthropic::Content.new(
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

  describe '.render_payload' do
    let(:model) { instance_double(RubyLLM::Model::Info, id: 'claude-sonnet-4-5', max_tokens: nil) }

    it 'embeds raw system content blocks unchanged' do
      system_raw = RubyLLM::Providers::Anthropic::Content.new(
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

  describe '.parse_completion_response' do
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

      message = described_class.parse_completion_response(response)

      expect(message.input_tokens).to eq(42)
      expect(message.output_tokens).to eq(5)
      expect(message.cached_tokens).to eq(21)
      expect(message.cache_creation_tokens).to eq(7)
    end
  end
end
