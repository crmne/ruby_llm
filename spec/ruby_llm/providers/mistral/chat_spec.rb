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

  describe '#format_messages' do
    it 'keeps parallel tool results consecutive and moves attachment carriers after the run' do
      attachment = RubyLLM::Attachment.new(StringIO.new('png bytes'), filename: 'chart.png')
      payload = render_payload(
        model_id: 'mistral-small-latest',
        messages: [
          RubyLLM::Message.new(role: :user, content: 'Chart it'),
          RubyLLM::Message.new(
            role: :assistant,
            content: nil,
            tool_calls: {
              'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'chart', arguments: {}),
              'call_2' => RubyLLM::ToolCall.new(id: 'call_2', name: 'chart', arguments: {})
            }
          ),
          RubyLLM::Message.new(role: :tool, content: 'first', attachments: [attachment], tool_call_id: 'call_1'),
          RubyLLM::Message.new(role: :tool, content: 'second', tool_call_id: 'call_2')
        ]
      )

      expect(payload[:messages].map { |message| message[:role] }).to eq(%w[user assistant tool tool user])
      expect(payload[:messages].last[:content].last[:type]).to eq('image_url')
    end

    it 'renders thinking as content blocks without top-level reasoning fields' do
      payload = render_payload(
        model_id: 'magistral-small-latest',
        messages: [
          RubyLLM::Message.new(
            role: :assistant,
            content: 'Done',
            thinking: RubyLLM::Thinking.new(text: 'why', signature: 'sig')
          )
        ]
      )

      expect(payload[:messages].first[:content].first[:type]).to eq('thinking')
      expect(payload[:messages].first).not_to have_key(:reasoning_content)
    end
  end

  describe '#format_message_content' do
    it 'formats arbitrary document attachments with Mistral document_url parts' do
      attachment = RubyLLM::Attachment.new(StringIO.new('docx bytes'), filename: 'proposal.docx')
      message = RubyLLM::Message.new(role: :user, content: 'Summarize this file', attachments: [attachment])

      formatted = provider.send(:format_message_content, message)

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

  describe '#build_thinking_blocks' do
    it 'is empty without thinking' do
      expect(provider.send(:build_thinking_blocks, nil)).to eq([])
      expect(provider.send(:build_thinking_blocks, RubyLLM::Thinking.new)).to eq([])
    end

    it 'wraps thinking text in a text block' do
      thinking = RubyLLM::Thinking.new(text: 'why', signature: 'sig')

      expect(provider.send(:build_thinking_blocks, thinking)).to eq(
        [{ type: 'thinking', thinking: [{ type: 'text', text: 'why' }], signature: 'sig' }]
      )
    end

    it 'sends a signature-only block' do
      expect(provider.send(:build_thinking_blocks, RubyLLM::Thinking.new(signature: 'sig'))).to eq(
        [{ type: 'thinking', signature: 'sig' }]
      )
    end
  end

  describe '#append_formatted_content' do
    it 'concatenates a list of parts' do
      blocks = []
      provider.send(:append_formatted_content, blocks, [{ type: 'text', text: 'hi' }])

      expect(blocks).to eq([{ type: 'text', text: 'hi' }])
    end

    it 'wraps plain text' do
      blocks = []
      provider.send(:append_formatted_content, blocks, 'hi')

      expect(blocks).to eq([{ type: 'text', text: 'hi' }])
    end

    it 'leaves the blocks alone for empty content' do
      blocks = []
      provider.send(:append_formatted_content, blocks, nil)
      provider.send(:append_formatted_content, blocks, '')

      expect(blocks).to eq([])
    end
  end

  describe '#reasoning_effort_for' do
    it 'passes high and none through and defaults everything else to high' do
      expect(provider.send(:reasoning_effort_for, RubyLLM::Thinking::Config.new(effort: :high))).to eq('high')
      expect(provider.send(:reasoning_effort_for, RubyLLM::Thinking::Config.new(effort: :none))).to eq('none')
      expect(provider.send(:reasoning_effort_for, RubyLLM::Thinking::Config.new(effort: :low))).to eq('high')
      expect(provider.send(:reasoning_effort_for, Object.new)).to eq('high')
    end

    it 'logs a debug note when coercing an unsupported effort' do
      allow(RubyLLM.logger).to receive(:debug)

      provider.send(:reasoning_effort_for, RubyLLM::Thinking::Config.new(effort: :medium))

      expect(RubyLLM.logger).to have_received(:debug)
    end
  end

  describe '#prompt_cache_params' do
    it 'renders only the cache key' do
      expect(provider.send(:prompt_cache_params, { key: 'abc' })).to eq(prompt_cache_key: 'abc')
    end

    it 'rejects options Mistral cannot render' do
      expect { provider.send(:prompt_cache_params, { ttl: '1h' }) }.to raise_error(
        ArgumentError, 'Mistral prompt caching accepts :key, got :ttl'
      )
    end
  end

  describe '#normalize_required_tool_choice' do
    it 'leaves a multi-tool request on the any mode' do
      payload = {
        tool_choice: 'any',
        tools: [
          { type: 'function', function: { name: 'weather' } },
          { type: 'function', function: { name: 'time' } }
        ]
      }

      provider.send(:normalize_required_tool_choice, payload)

      expect(payload[:tool_choice]).to eq('any')
    end

    it 'leaves the payload alone when the single tool has no name' do
      payload = { tool_choice: 'any', tools: [{ type: 'function', function: {} }] }

      provider.send(:normalize_required_tool_choice, payload)

      expect(payload[:tool_choice]).to eq('any')
    end
  end
end
