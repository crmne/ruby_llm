# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Mistral::Chat do
  let(:provider) { RubyLLM::Providers::Mistral::ChatCompletions.allocate }

  let(:messages) { [RubyLLM::Message.new(role: :user, content: 'Hello')] }

  def render_payload(model_id:, thinking: nil, caching: nil, messages: self.messages)
    model = instance_double(RubyLLM::Model, id: model_id)

    provider.send(
      :render_payload,
      messages,
      tools: {},
      temperature: nil,
      model: model,
      stream: false,
      thinking: thinking,
      caching: caching
    )
  end

  describe '#render_payload' do
    it 'renders system messages before conversation messages for Mistral' do
      payload = render_payload(
        model_id: 'mistral-small-latest',
        messages: [
          RubyLLM::Message.new(role: :user, content: 'Hello'),
          RubyLLM::Message.new(role: :system, content: 'Be terse.')
        ]
      )

      expect(payload[:messages].map { |message| message[:role] }).to eq(%w[system user])
    end

    it 'renders Mistral prompt cache key' do
      payload = render_payload(model_id: 'mistral-large-latest', caching: { key: 'support-session-42' })

      expect(payload[:prompt_cache_key]).to eq('support-session-42')
    end

    it 'rejects caching options Mistral cannot render' do
      expect do
        render_payload(model_id: 'mistral-large-latest', caching: { retention: '24h' })
      end.to raise_error(ArgumentError, /Mistral prompt caching accepts :key/)
    end

    it 'enables prompt-mode reasoning for native Magistral models' do
      payload = render_payload(
        model_id: 'magistral-small-latest',
        thinking: RubyLLM::Thinking::Config.new(effort: :medium)
      )

      expect(payload[:prompt_mode]).to eq('reasoning')
      expect(payload).not_to have_key(:reasoning_effort)
    end

    it 'uses reasoning_effort for adjustable-reasoning Mistral models' do
      payload = render_payload(
        model_id: 'mistral-small-latest',
        thinking: RubyLLM::Thinking::Config.new(effort: :medium)
      )

      expect(payload[:reasoning_effort]).to eq('high')
      expect(payload).not_to have_key(:prompt_mode)
    end

    it 'keeps explicit none effort for adjustable-reasoning models' do
      payload = render_payload(
        model_id: 'mistral-small-latest',
        thinking: RubyLLM::Thinking::Config.new(effort: :none)
      )

      expect(payload[:reasoning_effort]).to eq('none')
    end

    it 'does not send unsupported thinking settings to other Mistral models' do
      allow(RubyLLM.logger).to receive(:warn)

      payload = render_payload(
        model_id: 'pixtral-12b',
        thinking: RubyLLM::Thinking::Config.new(effort: :medium)
      )

      expect(payload).not_to have_key(:reasoning_effort)
      expect(payload).not_to have_key(:prompt_mode)
    end
  end

  describe '#format_content_with_thinking' do
    it 'formats arbitrary document attachments with Mistral document_url parts' do
      attachment = RubyLLM::Attachment.new(StringIO.new('docx bytes'), filename: 'proposal.docx')
      message = RubyLLM::Message.new(role: :user, content: 'Summarize this file', attachments: [attachment])

      formatted = provider.send(:format_content_with_thinking, message)

      expect(formatted.second).to eq(
        type: 'document_url',
        document_url: "data:application/vnd.openxmlformats-officedocument.wordprocessingml.document;base64,#{Base64.strict_encode64('docx bytes')}" # rubocop:disable Layout/LineLength
      )
    end
  end

  describe '#build_tool_choice' do
    it 'maps required tool choice to the Mistral any mode' do
      expect(provider.send(:build_tool_choice, :required)).to eq('any')
    end

    it 'normalizes required tool choice to a specific function when there is only one tool' do
      payload = {
        tool_choice: 'any',
        tools: [
          {
            type: 'function',
            function: { name: 'weather' }
          }
        ]
      }

      provider.send(:normalize_required_tool_choice, payload)

      expect(payload[:tool_choice]).to eq(
        type: 'function',
        function: { name: 'weather' }
      )
    end
  end
end
