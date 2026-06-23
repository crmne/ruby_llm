# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenRouter::Chat do
  let(:provider) { RubyLLM::Providers::OpenRouter::ChatCompletions.allocate }

  describe '#parse_completion_response' do
    it 'returns nil for a nil response body' do
      response = instance_double(Faraday::Response, body: nil)

      expect(provider.send(:parse_completion_response, response)).to be_nil
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

      expect(message.input_tokens).to eq(2)
      expect(message.cached_tokens).to eq(6)
      expect(message.cache_creation_tokens).to eq(4)
      expect(message.output_tokens).to eq(4)
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

      expect(message.output_tokens).to eq(2393)
      expect(message.thinking_tokens).to eq(2185)
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
  end

  describe '#format_messages' do
    it 'opts OpenRouter into native file parts for PDF attachments' do
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('pdf bytes'), filename: 'proposal.pdf')

      messages = [RubyLLM::Message.new(role: :user, content:)]

      formatted = provider.send(:format_messages, messages)

      expect(formatted.dig(0, :content, 1, :type)).to eq('file')
      expect(formatted.dig(0, :content, 1, :file, :filename)).to eq('proposal.pdf')
    end

    it 'keeps non-PDF documents disabled for OpenRouter chat completions' do
      content = RubyLLM::Content.new('Summarize this file')
      content.add_attachment(StringIO.new('docx bytes'), filename: 'proposal.docx')

      expect do
        provider.send(:format_messages, [RubyLLM::Message.new(role: :user, content:)])
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end
  end

  describe '#render_payload' do
    let(:model) { instance_double(RubyLLM::Model::Info, id: 'anthropic/claude-haiku-4.5') }
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
  end
end
