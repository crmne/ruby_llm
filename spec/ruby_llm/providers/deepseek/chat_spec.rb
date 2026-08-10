# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::DeepSeek::Chat do
  describe '.render_payload' do
    let(:provider) { RubyLLM::Providers::DeepSeek::ChatCompletions.allocate }
    let(:messages) { [RubyLLM::Message.new(role: :user, content: 'Hello')] }

    def render_payload(thinking: nil, schema: nil)
      model = instance_double(RubyLLM::Model, id: 'deepseek-v4-flash')

      provider.send(
        :render_payload,
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        thinking: thinking,
        schema: schema
      )
    end

    it 'disables thinking for effort none' do
      payload = render_payload(thinking: RubyLLM::Thinking::Config.new(effort: :none))

      expect(payload[:thinking]).to eq(type: 'disabled')
      expect(payload).not_to have_key(:reasoning_effort)
    end

    it 'enables thinking and passes the reasoning effort through' do
      payload = render_payload(thinking: RubyLLM::Thinking::Config.new(effort: :max))

      expect(payload[:thinking]).to eq(type: 'enabled')
      expect(payload[:reasoning_effort]).to eq('max')
    end

    it 'coerces medium effort to high with a debug note' do
      allow(RubyLLM.logger).to receive(:debug)

      payload = render_payload(thinking: RubyLLM::Thinking::Config.new(effort: :medium))

      expect(payload[:thinking]).to eq(type: 'enabled')
      expect(payload[:reasoning_effort]).to eq('high')
      expect(RubyLLM.logger).to have_received(:debug)
    end

    it 'ignores thinking budgets with a debug note' do
      allow(RubyLLM.logger).to receive(:debug)

      payload = render_payload(thinking: RubyLLM::Thinking::Config.new(budget: 2048))

      expect(payload[:thinking]).to eq(type: 'enabled')
      expect(payload).not_to have_key(:reasoning_effort)
      expect(RubyLLM.logger).to have_received(:debug)
    end

    it 'omits thinking controls when thinking is not configured' do
      payload = render_payload

      expect(payload).not_to have_key(:thinking)
      expect(payload).not_to have_key(:reasoning_effort)
    end

    it 'degrades json_schema response formats to json_object with a warning' do
      allow(RubyLLM.logger).to receive(:warn)

      payload = render_payload(schema: { name: 'person', schema: { type: 'object' }, strict: true })

      expect(payload[:response_format]).to eq(type: 'json_object')
      expect(RubyLLM.logger).to have_received(:warn).with(/does not support json_schema/)
    end
  end

  describe '.format_thinking' do
    context 'with an assistant message' do
      it 'emits reasoning_content (and reasoning) when thinking text is present' do
        message = RubyLLM::Message.new(
          role: :assistant,
          content: 'Hi',
          thinking: RubyLLM::Thinking.build(text: 'pondering', signature: 'sig')
        )

        payload = described_class.format_thinking(message)

        expect(payload[:reasoning_content]).to eq('pondering')
        expect(payload[:reasoning]).to eq('pondering')
        expect(payload[:reasoning_signature]).to eq('sig')
      end

      it 'still emits reasoning_content when no thinking was captured' do
        message = RubyLLM::Message.new(role: :assistant, content: 'short answer')

        payload = described_class.format_thinking(message)

        expect(payload).to have_key(:reasoning_content)
        expect(payload[:reasoning_content]).to eq('')
        expect(payload).not_to have_key(:reasoning)
      end
    end

    it 'returns an empty hash for non-assistant messages' do
      message = RubyLLM::Message.new(role: :user, content: 'hello')

      expect(described_class.format_thinking(message)).to eq({})
    end
  end
end
