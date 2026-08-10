# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenRouter::Chat do
  let(:provider) { RubyLLM::Providers::OpenRouter::ChatCompletions.allocate }

  describe '#parse_completion_response' do
    it 'raises RubyLLM::Error for a nil response body' do
      response = instance_double(Faraday::Response, body: nil)

      expect do
        provider.send(:parse_completion_response, response)
      end.to raise_error(RubyLLM::Error, 'Provider returned an empty response body')
    end

    it 'normalizes cached prompt tokens out of input tokens' do
      response_body = {
        'model' => 'openai/gpt-4.1-nano',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => 'Hello!'
            }
          }
        ],
        'usage' => {
          'prompt_tokens' => 12,
          'completion_tokens' => 4,
          'prompt_tokens_details' => { 'cached_tokens' => 6, 'cache_write_tokens' => 4 }
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = provider.send(:parse_completion_response, response)

      expect(message.tokens.input).to eq(2)
      expect(message.tokens.cache_read).to eq(6)
      expect(message.tokens.cache_write).to eq(4)
      expect(message.tokens.output).to eq(4)
    end

    it 'normalizes OpenAI-compatible reasoning tokens that are reported outside completion tokens' do
      response_body = {
        'model' => 'x-ai/grok-4-fast-reasoning',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => 'Hello!'
            }
          }
        ],
        'usage' => {
          'prompt_tokens' => 50,
          'completion_tokens' => 208,
          'total_tokens' => 2443,
          'completion_tokens_details' => { 'reasoning_tokens' => 2185 }
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = provider.send(:parse_completion_response, response)

      expect(message.tokens.output).to eq(2393)
      expect(message.tokens.thinking).to eq(2185)
    end

    it 'captures the reported cost from usage' do
      response_body = {
        'model' => 'meta-llama/llama-3.2-1b-instruct',
        'choices' => [
          { 'message' => { 'role' => 'assistant', 'content' => 'Hi!' } }
        ],
        'usage' => {
          'prompt_tokens' => 13,
          'completion_tokens' => 3,
          'total_tokens' => 16,
          'cost' => 9.54e-07,
          'is_byok' => false,
          'cost_details' => { 'upstream_inference_cost' => 9.54e-07 }
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      message = provider.send(:parse_completion_response, response)

      expect(message.tokens.reported_cost).to eq(9.54e-07)
      expect(message.cost.total).to eq(9.54e-07)
    end

    it 'adds the upstream inference cost to the OpenRouter fee on BYOK requests' do
      usage = {
        'cost' => 0.0001,
        'is_byok' => true,
        'cost_details' => { 'upstream_inference_cost' => 0.002 }
      }

      expect(provider.send(:reported_cost, usage)).to be_within(1e-12).of(0.0021)
    end

    it 'reports no cost when usage carries none' do
      expect(provider.send(:reported_cost, {})).to be_nil
    end
  end

  describe '#build_chunk' do
    it 'preserves raw finish reasons on streaming chunks' do
      chunk = provider.send(
        :build_chunk,
        {
          'model' => 'openai/gpt-4.1-nano',
          'choices' => [
            { 'delta' => { 'content' => '' }, 'finish_reason' => 'tool_calls' }
          ]
        }
      )

      expect(chunk.finish_reason).to eq('tool_calls')
    end

    it 'captures the reported cost from the final usage chunk' do
      chunk = provider.send(
        :build_chunk,
        {
          'model' => 'openai/gpt-4.1-nano',
          'choices' => [],
          'usage' => {
            'prompt_tokens' => 13,
            'completion_tokens' => 3,
            'cost' => 9.54e-07,
            'is_byok' => false
          }
        }
      )

      expect(chunk.tokens.reported_cost).to eq(9.54e-07)
    end
  end

  describe '#format_messages' do
    it 'opts OpenRouter into native file parts for PDF attachments' do
      attachment = RubyLLM::Attachment.new(StringIO.new('pdf bytes'), filename: 'proposal.pdf')

      messages = [RubyLLM::Message.new(role: :user, content: 'Summarize this file', attachments: [attachment])]

      formatted = provider.send(:format_messages, messages)

      expect(formatted.dig(0, :content, 1, :type)).to eq('file')
      expect(formatted.dig(0, :content, 1, :file, :filename)).to eq('proposal.pdf')
    end

    it 'keeps non-PDF documents disabled for OpenRouter chat completions' do
      attachment = RubyLLM::Attachment.new(StringIO.new('docx bytes'), filename: 'proposal.docx')
      message = RubyLLM::Message.new(role: :user, content: 'Summarize this file', attachments: [attachment])

      expect do
        provider.send(:format_messages, [message])
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end

    it 'adds cache_control to a message marked as a cache boundary' do
      message = RubyLLM::Message.new(role: :user, content: 'Long context').cache_until_here!

      formatted = provider.send(:format_messages, [message])

      expect(formatted.dig(0, :content, -1)).to include(cache_control: { type: 'ephemeral' })
    end

    it 'uses configured cache_control for a cache boundary' do
      message = RubyLLM::Message.new(role: :user, content: 'Long context').cache_until_here!

      formatted = provider.send(:format_messages, [message], caching: { ttl: '1h' })

      expect(formatted.dig(0, :content, -1, :cache_control)).to eq(type: 'ephemeral', ttl: '1h')
    end
  end

  describe '#render_payload' do
    let(:model) { instance_double(RubyLLM::Model, id: 'anthropic/claude-haiku-4.5') }
    let(:messages) { [RubyLLM::Message.new(role: :user, content: 'Hello')] }

    before do
      allow(provider).to receive(:format_messages).and_return([{ role: 'user', content: 'Hello' }])
    end

    it 'uses canonical wrapped schema payload' do
      schema = {
        name: 'response',
        schema: {
          type: 'object',
          properties: {
            answer: { type: 'string' }
          }
        },
        strict: true
      }

      payload = provider.send(
        :render_payload,
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: schema
      )

      expect(payload[:response_format][:json_schema][:name]).to eq('response')
      expect(payload[:response_format][:json_schema][:schema]).to eq(schema[:schema])
      expect(payload[:response_format][:json_schema][:strict]).to be(true)
    end

    it 'uses wrapper schema name and inner schema' do
      schema = {
        name: 'PersonSchema',
        schema: {
          type: 'object',
          properties: {
            name: { type: 'string' }
          }
        },
        strict: false
      }

      payload = provider.send(
        :render_payload,
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: schema
      )

      expect(payload[:response_format][:json_schema][:name]).to eq('PersonSchema')
      expect(payload[:response_format][:json_schema][:schema]).to eq(schema[:schema])
      expect(payload[:response_format][:json_schema][:strict]).to be(false)
    end

    it 'adds top-level automatic cache_control when caching is enabled without explicit boundaries' do
      payload = provider.send(
        :render_payload,
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        caching: { ttl: '1h' }
      )

      expect(payload[:cache_control]).to eq(type: 'ephemeral', ttl: '1h')
    end

    it 'does not add top-level cache_control when an explicit boundary is present' do
      messages = [RubyLLM::Message.new(role: :user, content: 'Long context').cache_until_here!]

      payload = provider.send(
        :render_payload,
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        caching: { ttl: '1h' }
      )

      expect(payload).not_to have_key(:cache_control)
    end

    it 'rejects caching options it cannot render' do
      expect do
        provider.send(
          :render_payload,
          messages,
          tools: {},
          temperature: nil,
          model: model,
          stream: false,
          caching: { retention: '24h' }
        )
      end.to raise_error(ArgumentError, /OpenRouter prompt caching accepts :ttl/)
    end
  end

  describe '#build_reasoning' do
    it 'is nil when thinking is off' do
      expect(provider.send(:build_reasoning, nil)).to be_nil
      expect(provider.send(:build_reasoning, RubyLLM::Thinking::Config.new)).to be_nil
    end

    it 'sends the effort' do
      expect(provider.send(:build_reasoning, RubyLLM::Thinking::Config.new(effort: :high))).to eq(effort: 'high')
    end

    it 'sends the budget as max_tokens' do
      expect(provider.send(:build_reasoning, RubyLLM::Thinking::Config.new(budget: 2048))).to eq(max_tokens: 2048)
    end

    it 'falls back to just enabling reasoning' do
      config = Struct.new(:enabled?).new(true)

      expect(provider.send(:build_reasoning, config)).to eq(enabled: true)
    end
  end

  describe '#format_thinking' do
    it 'is empty for a user message or one without thinking' do
      expect(provider.send(:format_thinking, RubyLLM::Message.new(role: :user, content: 'hi'))).to eq({})
      expect(provider.send(:format_thinking, RubyLLM::Message.new(role: :assistant, content: 'hi'))).to eq({})
    end

    it 'sends reasoning text with its signature' do
      message = RubyLLM::Message.new(
        role: :assistant, content: 'done', thinking: RubyLLM::Thinking.new(text: 'why', signature: 'sig')
      )

      expect(provider.send(:format_thinking, message)).to eq(
        reasoning_details: [{ type: 'reasoning.text', text: 'why', signature: 'sig' }]
      )
    end

    it 'sends a signature-only block as encrypted reasoning' do
      message = RubyLLM::Message.new(
        role: :assistant, content: 'done', thinking: RubyLLM::Thinking.new(signature: 'sig')
      )

      expect(provider.send(:format_thinking, message)).to eq(
        reasoning_details: [{ type: 'reasoning.encrypted', data: 'sig' }]
      )
    end
  end

  describe 'reasoning details on the way back' do
    it 'joins reasoning text and summary details' do
      message_data = {
        'reasoning_details' => [
          { 'type' => 'reasoning.text', 'text' => 'first ' },
          { 'type' => 'reasoning.summary', 'summary' => 'second' },
          { 'type' => 'reasoning.encrypted', 'data' => 'blob' }
        ]
      }

      expect(provider.send(:extract_thinking_text, message_data)).to eq('first second')
    end

    it 'is nil when the response carries no reasoning details' do
      expect(provider.send(:extract_thinking_text, {})).to be_nil
      expect(provider.send(:extract_thinking_signature, {})).to be_nil
    end

    it 'is nil when the details carry no text' do
      expect(provider.send(:extract_thinking_text, { 'reasoning_details' => [] })).to be_nil
    end

    it 'prefers an explicit signature over encrypted data' do
      message_data = {
        'reasoning_details' => [
          { 'type' => 'reasoning.encrypted', 'data' => 'blob' },
          { 'type' => 'reasoning.text', 'signature' => 'sig' }
        ]
      }

      expect(provider.send(:extract_thinking_signature, message_data)).to eq('sig')
    end

    it 'falls back to encrypted data' do
      message_data = { 'reasoning_details' => [{ 'type' => 'reasoning.encrypted', 'data' => 'blob' }] }

      expect(provider.send(:extract_thinking_signature, message_data)).to eq('blob')
    end
  end

  describe '#inject_cache_control' do
    it 'wraps plain text content in a cacheable block' do
      expect(provider.send(:inject_cache_control, 'hello')).to eq(
        [{ type: 'text', text: 'hello', cache_control: { type: 'ephemeral' } }]
      )
    end

    it 'leaves empty content alone' do
      expect(provider.send(:inject_cache_control, [])).to eq([])
    end

    it 'leaves a block that already carries cache_control alone' do
      blocks = [{ type: 'text', text: 'hello', cache_control: { type: 'ephemeral' } }]

      expect(provider.send(:inject_cache_control, blocks)).to eq(blocks)
    end

    it 'leaves a trailing block it cannot annotate alone' do
      expect(provider.send(:inject_cache_control, ['plain'])).to eq(['plain'])
    end
  end
end
