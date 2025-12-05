# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Anthropic do
  include_context 'with configured RubyLLM'

  describe '#complete with structured outputs' do
    let(:provider) { described_class.new(RubyLLM.config) }

    describe '#add_structured_output_beta_header' do
      it 'adds beta header when schema is provided' do
        headers = provider.send(:add_structured_output_beta_header, {})
        expect(headers['anthropic-beta']).to eq('structured-outputs-2025-11-13')
      end

      it 'appends to existing beta header' do
        existing_headers = { 'anthropic-beta' => 'existing-beta' }
        headers = provider.send(:add_structured_output_beta_header, existing_headers)
        expect(headers['anthropic-beta']).to eq('existing-beta,structured-outputs-2025-11-13')
      end
    end
  end
end

RSpec.describe RubyLLM::Providers::Anthropic::Chat do
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

    it 'includes output_format when schema is provided' do
      user_message = RubyLLM::Message.new(role: :user, content: 'Hello')
      schema = {
        type: 'object',
        properties: {
          name: { type: 'string' }
        },
        required: ['name'],
        additionalProperties: false
      }

      payload = described_class.render_payload(
        [user_message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: schema
      )

      expect(payload[:output_format]).to eq({
                                              type: 'json_schema',
                                              schema: schema
                                            })
    end

    it 'does not include output_format when schema is nil' do
      user_message = RubyLLM::Message.new(role: :user, content: 'Hello')

      payload = described_class.render_payload(
        [user_message],
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: nil
      )

      expect(payload).not_to have_key(:output_format)
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
