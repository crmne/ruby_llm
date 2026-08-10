# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::Chat do
  describe '.parse_completion_body' do
    it 'captures cached token information when present' do
      response_body = {
        'model' => 'gpt-4.1-nano',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => 'Hello!'
            }
          }
        ],
        'usage' => {
          'prompt_tokens' => 8,
          'completion_tokens' => 4,
          'prompt_tokens_details' => { 'cached_tokens' => 6 }
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      allow(described_class).to receive(:parse_tool_calls).and_return(nil)

      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.tokens.cache_read).to eq(6)
      expect(message.tokens.input).to eq(2)
      expect(message.tokens.output).to eq(4)
      expect(message.tokens.cache_write).to eq(0)
    end

    it 'captures cache write tokens for models that bill cache writes' do
      response_body = {
        'model' => 'gpt-5.6',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => 'Hello!'
            }
          }
        ],
        'usage' => {
          'prompt_tokens' => 2048,
          'completion_tokens' => 4,
          'prompt_tokens_details' => { 'cached_tokens' => 1920, 'cache_write_tokens' => 100 }
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      allow(described_class).to receive(:parse_tool_calls).and_return(nil)

      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.tokens.cache_read).to eq(1920)
      expect(message.tokens.cache_write).to eq(100)
      expect(message.tokens.input).to eq(28)
    end

    it 'preserves raw finish reasons' do
      response_body = {
        'model' => 'gpt-4.1-nano',
        'choices' => [
          {
            'finish_reason' => 'tool_calls',
            'message' => {
              'role' => 'assistant',
              'content' => '',
              'tool_calls' => [
                {
                  'id' => 'call_1',
                  'type' => 'function',
                  'function' => { 'name' => 'weather', 'arguments' => '{}' }
                }
              ]
            }
          }
        ]
      }

      response = instance_double(Faraday::Response, body: response_body)
      allow(described_class).to receive(:parse_tool_calls).and_return(
        'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: {})
      )
      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.finish_reason).to eq('tool_calls')
    end

    it 'normalizes DeepSeek cache hit and miss usage fields' do
      response_body = {
        'model' => 'deepseek-chat',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => 'Hello!'
            }
          }
        ],
        'usage' => {
          'prompt_tokens' => 206,
          'completion_tokens' => 4,
          'prompt_cache_hit_tokens' => 192,
          'prompt_cache_miss_tokens' => 14
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      allow(described_class).to receive(:parse_tool_calls).and_return(nil)

      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.tokens.input).to eq(14)
      expect(message.tokens.cache_read).to eq(192)
      expect(message.tokens.output).to eq(4)
      expect(message.tokens.cache_write).to eq(0)
    end

    it 'keeps OpenAI reasoning tokens inside completion output tokens' do
      response_body = {
        'model' => 'gpt-5.5',
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
          'completion_tokens' => 1306,
          'total_tokens' => 1356,
          'completion_tokens_details' => { 'reasoning_tokens' => 1087 }
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      allow(described_class).to receive(:parse_tool_calls).and_return(nil)

      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.tokens.output).to eq(1306)
      expect(message.tokens.thinking).to eq(1087)
    end

    it 'adds reasoning tokens to output for OpenAI-compatible providers that report them separately' do
      response_body = {
        'model' => 'grok-4-fast-reasoning',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => 'Hello!'
            }
          }
        ],
        'usage' => {
          'prompt_tokens' => 43,
          'completion_tokens' => 101,
          'total_tokens' => 9971,
          'completion_tokens_details' => { 'reasoning_tokens' => 9827 }
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      allow(described_class).to receive(:parse_tool_calls).and_return(nil)

      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.tokens.output).to eq(9928)
      expect(message.tokens.thinking).to eq(9827)
    end

    it 'captures top-level reasoning tokens when providers report them outside completion details' do
      response_body = {
        'model' => 'sonar-deep-research',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => 'Hello!'
            }
          }
        ],
        'usage' => {
          'prompt_tokens' => 33,
          'completion_tokens' => 11_395,
          'total_tokens' => 11_428,
          'reasoning_tokens' => 193_947
        }
      }

      response = instance_double(Faraday::Response, body: response_body)
      allow(described_class).to receive(:parse_tool_calls).and_return(nil)

      message = described_class.parse_completion_body(response_body, raw: response)

      expect(message.tokens.output).to eq(11_395)
      expect(message.tokens.thinking).to eq(193_947)
    end
  end

  describe '.format_messages' do
    it 'renders system messages before conversation messages' do
      messages = [
        RubyLLM::Message.new(role: :user, content: 'Hi'),
        RubyLLM::Message.new(role: :system, content: 'Be brief.')
      ]
      protocol = RubyLLM::Protocols::ChatCompletions.allocate
      protocol.instance_variable_set(:@config, RubyLLM.config)

      formatted = protocol.send(:format_messages, messages)

      expect(formatted.map { |message| message[:role] }).to eq(%w[developer user])
    end

    it 'opts OpenAI into native file parts for PDF attachments' do
      attachment = RubyLLM::Attachment.new(StringIO.new('pdf bytes'), filename: 'proposal.pdf')

      messages = [RubyLLM::Message.new(role: :user, content: 'Summarize this file', attachments: [attachment])]

      formatted = RubyLLM::Protocols::ChatCompletions.allocate.send(:format_messages, messages)

      expect(formatted.dig(0, :content, 1, :type)).to eq('file')
      expect(formatted.dig(0, :content, 1, :file, :filename)).to eq('proposal.pdf')
    end

    it 'does not send finish_reason back to the provider' do
      message = RubyLLM::Message.new(role: :assistant, content: 'Done', finish_reason: 'MAX_TOKENS')

      formatted = RubyLLM::Protocols::ChatCompletions.allocate.send(:format_messages, [message])

      expect(formatted.first).not_to have_key(:finish_reason)
    end

    it 'keeps non-PDF documents disabled for OpenAI chat completions' do
      expect do
        RubyLLM::Protocols::ChatCompletions.allocate.send(:format_messages, [docx_message])
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end

    it 'keeps unsupported files disabled for DeepSeek' do
      provider = RubyLLM::Providers::DeepSeek::ChatCompletions.allocate

      expect do
        provider.send(:format_messages, [docx_message])
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end

    it 'keeps image attachments disabled for DeepSeek' do
      provider = RubyLLM::Providers::DeepSeek::ChatCompletions.allocate
      attachment = RubyLLM::Attachment.new(StringIO.new('png bytes'), filename: 'image.png')
      message = RubyLLM::Message.new(role: :user, content: 'Describe this', attachments: [attachment])

      expect do
        provider.send(:format_messages, [message])
      end.to raise_error(RubyLLM::UnsupportedAttachmentError, %r{Unsupported attachment type: image/png})
    end

    it 'uses Perplexity file_url parts for supported file attachments' do
      provider = RubyLLM::Providers::Perplexity::ChatCompletions.allocate

      formatted = provider.send(:format_messages, [docx_message])

      expect(formatted.dig(0, :content, 1)).to eq(
        type: 'file_url',
        file_url: { url: Base64.strict_encode64('docx bytes') }
      )
    end

    it 'keeps Perplexity text file attachments as text parts' do
      provider = RubyLLM::Providers::Perplexity::ChatCompletions.allocate

      %w[csv txt md html json].each do |extension|
        attachment = RubyLLM::Attachment.new(StringIO.new('notes'), filename: "notes.#{extension}")
        message = RubyLLM::Message.new(role: :user, content: 'Summarize this file', attachments: [attachment])

        formatted = provider.send(:format_messages, [message])

        expect(formatted.dig(0, :content, 1)).to eq(
          type: 'text',
          text: attachment.for_llm
        )
      end
    end

    it 'keeps unsupported files disabled for xAI' do
      provider = RubyLLM::Providers::XAI::ChatCompletions.allocate

      expect do
        provider.send(:format_messages, [docx_message])
      end.to raise_error(
        RubyLLM::UnsupportedAttachmentError,
        %r{Unsupported attachment type: application/vnd.openxmlformats-officedocument.wordprocessingml.document}
      )
    end

    it 'keeps PDF file parts disabled for xAI chat completions' do
      provider = RubyLLM::Providers::XAI::ChatCompletions.allocate
      attachment = RubyLLM::Attachment.new(StringIO.new('pdf bytes'), filename: 'proposal.pdf')
      message = RubyLLM::Message.new(role: :user, content: 'Summarize this file', attachments: [attachment])

      expect do
        provider.send(:format_messages, [message])
      end.to raise_error(RubyLLM::UnsupportedAttachmentError, %r{Unsupported attachment type: application/pdf})
    end

    def docx_message
      attachment = RubyLLM::Attachment.new(StringIO.new('docx bytes'), filename: 'proposal.docx')
      RubyLLM::Message.new(role: :user, content: 'Summarize this file', attachments: [attachment])
    end
  end

  describe '.render_payload' do
    let(:model) { instance_double(RubyLLM::Model, id: 'gpt-4o') }
    let(:messages) { [RubyLLM::Message.new(role: :user, content: 'Hello')] }

    before do
      allow(described_class).to receive(:format_messages).and_return([{ role: 'user', content: 'Hello' }])
    end

    it 'renders prompt cache params for any Chat Completions-compatible provider' do
      payload = described_class.render_payload(
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        caching: { key: 'repo:ruby_llm', ttl: '30m' }
      )

      expect(payload[:prompt_cache_key]).to eq('repo:ruby_llm')
      expect(payload[:prompt_cache_options]).to eq(ttl: '30m')
    end

    context 'with schema' do
      it 'uses canonical wrapped schema payload' do
        schema = {
          name: 'response',
          schema: {
            type: 'object',
            properties: {
              name: { type: 'string' },
              age: { type: 'integer' }
            }
          },
          strict: true
        }

        payload = described_class.render_payload(
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

      it 'uses custom schema name when provided in full format' do
        schema = {
          name: 'PersonSchema',
          schema: {
            type: 'object',
            properties: {
              name: { type: 'string' },
              age: { type: 'integer' }
            }
          },
          strict: true
        }

        payload = described_class.render_payload(
          messages,
          tools: {},
          temperature: nil,
          model: model,
          stream: false,
          schema: schema
        )

        expect(payload[:response_format][:json_schema][:name]).to eq('PersonSchema')
        expect(payload[:response_format][:json_schema][:schema]).to eq(schema[:schema])
        expect(payload[:response_format][:json_schema][:strict]).to be(true)
      end

      it 'respects explicit strict: false' do
        schema = {
          name: 'PersonSchema',
          schema: {
            type: 'object',
            properties: {
              name: { type: 'string' },
              age: { type: 'integer' }
            }
          },
          strict: false
        }

        payload = described_class.render_payload(
          messages,
          tools: {},
          temperature: nil,
          model: model,
          stream: false,
          schema: schema
        )

        expect(payload[:response_format][:json_schema][:strict]).to be(false)
      end
    end
  end

  describe 'citations' do
    it 'reads url_citation annotations and slices the cited span out of the content' do
      citations = described_class.extract_citations(
        {
          'annotations' => [
            { 'url_citation' => { 'url' => 'https://a.example', 'title' => 'A', 'start_index' => 0,
                                  'end_index' => 5 } },
            { 'type' => 'other' }
          ]
        },
        {},
        'Hello world'
      )

      expect(citations.length).to eq(1)
      expect(citations.first.url).to eq('https://a.example')
      expect(citations.first.text).to eq('Hello')
    end

    it 'leaves the cited text nil when the annotation carries no offsets' do
      citations = described_class.extract_citations(
        { 'annotations' => [{ 'url_citation' => { 'url' => 'https://a.example' } }] }, {}, 'Hello'
      )

      expect(citations.first.text).to be_nil
    end

    it 'falls back to root search results' do
      citations = described_class.extract_citations(
        {},
        { 'search_results' => [
          { 'url' => 'https://a.example', 'title' => 'A', 'snippet' => 'excerpt' },
          'not a result'
        ] },
        nil
      )

      expect(citations.length).to eq(1)
      expect(citations.first.cited_text).to eq('excerpt')
      expect(citations.first.source_index).to eq(0)
    end

    it 'falls back to a root citation URL list' do
      citations = described_class.extract_citations({}, { 'citations' => ['https://a.example', 42] }, nil)

      expect(citations.map(&:url)).to eq(['https://a.example'])
    end

    it 'is empty when the response carries none' do
      expect(described_class.extract_citations({}, {}, nil)).to eq([])
    end
  end

  describe '.parse_completion_body error and usage handling' do
    it 'raises the error the provider reported' do
      body = { 'error' => { 'message' => 'model overloaded' } }
      response = instance_double(Faraday::Response, body: body)

      expect { described_class.parse_completion_body(body, raw: response) }.to raise_error(
        RubyLLM::Error, 'model overloaded'
      )
    end

    it 'raises when the response carries no message' do
      expect { described_class.parse_completion_body({ 'choices' => [] }, raw: nil) }.to raise_error(
        RubyLLM::Error, /Provider returned no completion message/
      )
    end

    it 'derives generated tokens from the total when the provider omits them' do
      body = {
        'choices' => [{ 'message' => { 'role' => 'assistant', 'content' => 'Hi' } }],
        'usage' => { 'prompt_tokens' => 10, 'completion_tokens' => 2, 'total_tokens' => 14 }
      }
      allow(described_class).to receive(:parse_tool_calls).and_return(nil)

      message = described_class.parse_completion_body(body, raw: nil)

      expect(message.tokens.output).to eq(4)
    end
  end

  describe 'thinking round-trips' do
    it 'reads reasoning out of the alternate field names' do
      expect(described_class.extract_thinking_text({ 'reasoning' => 'why' })).to eq('why')
      expect(described_class.extract_thinking_text({ 'thinking' => 'why' })).to eq('why')
      expect(described_class.extract_thinking_text({ 'reasoning_content' => 42 })).to be_nil
      expect(described_class.extract_thinking_signature({ 'signature' => 'sig' })).to eq('sig')
      expect(described_class.extract_thinking_signature({ 'reasoning_signature' => 42 })).to be_nil
    end

    it 'splits inline think tags out of the content' do
      expect(described_class.extract_content_and_thinking('<think>why</think>answer')).to eq(%w[answer why])
      expect(described_class.extract_content_and_thinking('<think>why</think>')).to eq([nil, 'why'])
      expect(described_class.extract_content_and_thinking('plain')).to eq(['plain', nil])
    end

    it 'leaves a content shape it does not understand alone' do
      expect(described_class.extract_content_and_thinking(nil)).to eq([nil, nil])
    end

    it 'reads thinking out of structured content blocks' do
      content = [
        { 'type' => 'thinking', 'thinking' => 'first ' },
        { 'type' => 'thinking', 'thinking' => [{ 'type' => 'text', 'text' => 'second' }] },
        { 'type' => 'thinking', 'text' => ' third' },
        { 'type' => 'text', 'text' => 'answer' }
      ]

      expect(described_class.extract_content_and_thinking(content)).to eq(['answer', 'first second third'])
    end

    it 'sends assistant thinking back under every field name providers accept' do
      message = RubyLLM::Message.new(
        role: :assistant, content: 'done', thinking: RubyLLM::Thinking.new(text: 'why', signature: 'sig')
      )

      expect(described_class.format_thinking(message)).to eq(
        reasoning: 'why', reasoning_content: 'why', reasoning_signature: 'sig'
      )
    end

    it 'sends nothing for a user message or one without thinking' do
      expect(described_class.format_thinking(RubyLLM::Message.new(role: :user, content: 'hi'))).to eq({})
      expect(described_class.format_thinking(RubyLLM::Message.new(role: :assistant, content: 'hi'))).to eq({})
    end

    it 'sends only the signature when that is all the model returned' do
      message = RubyLLM::Message.new(
        role: :assistant, content: 'done', thinking: RubyLLM::Thinking.new(signature: 'sig')
      )

      expect(described_class.format_thinking(message)).to eq(reasoning_signature: 'sig')
    end
  end

  describe 'prompt caching' do
    it 'renders the supported cache options' do
      expect(described_class.prompt_cache_params({ key: 'abc', ttl: '30m', mode: 'explicit' })).to eq(
        prompt_cache_key: 'abc', prompt_cache_options: { mode: 'explicit', ttl: '30m' }
      )
    end

    it 'translates deprecated retention into a prompt cache ttl' do
      allow(RubyLLM.logger).to receive(:warn)

      expect(described_class.prompt_cache_params({ retention: '24h' })).to eq(
        prompt_cache_options: { ttl: '24h' }
      )
      expect(RubyLLM.logger).to have_received(:warn).with(/retention: is deprecated/)
    end

    it 'rejects options it cannot render' do
      expect { described_class.prompt_cache_params({ scope: 'user' }) }.to raise_error(
        ArgumentError, /accepts :key, :ttl, and :mode, got :scope/
      )
    end

    it 'marks cache boundaries with explicit breakpoint parts' do
      protocol = RubyLLM::Protocols::ChatCompletions.allocate
      message = RubyLLM::Message.new(role: :user, content: 'Long context').cache_until_here!
      model = instance_double(RubyLLM::Model, id: 'gpt-5.6')

      payload = protocol.send(:render_payload, [message], tools: {}, temperature: nil, model: model, stream: false)

      expect(payload[:messages].first[:content]).to eq(
        [{ type: 'text', text: 'Long context', prompt_cache_breakpoint: { mode: 'explicit' } }]
      )
      expect(payload[:prompt_cache_options]).to eq(mode: 'explicit')
    end
  end

  describe '.warn_unsupported_citations' do
    it 'warns when citations are asked of a model without them' do
      allow(RubyLLM.logger).to receive(:warn)
      allow(described_class).to receive(:format_messages).and_return([])
      model = instance_double(RubyLLM::Model, id: 'gpt-4.1-nano', supports?: false)

      described_class.render_payload(
        [RubyLLM::Message.new(role: :user, content: 'Hi')],
        tools: {}, temperature: nil, model: model, citations: true
      )

      expect(RubyLLM.logger).to have_received(:warn).with(/does not support citations/)
    end
  end

  describe 'tool preferences' do
    it 'renders tool choice and parallel tool calls' do
      protocol = Object.new
      protocol.extend(RubyLLM::Protocols::ChatCompletions::Tools)
      protocol.extend(RubyLLM::Protocols::ChatCompletions::Media)
      protocol.extend(described_class)
      model = instance_double(RubyLLM::Model, id: 'gpt-4.1-nano', supports?: true)
      tool = instance_double(
        RubyLLM::Tool, name: 'lookup', description: 'Looks up', parameters_schema: nil,
                       declared_parameters: {}, provider_options: {}
      )

      payload = protocol.send(
        :render_payload,
        [RubyLLM::Message.new(role: :user, content: 'Hi')],
        tools: { 'lookup' => tool }, temperature: nil, model: model,
        tool_prefs: { choice: :required, calls: :one }
      )

      expect(payload[:tools].first[:function][:name]).to eq('lookup')
      expect(payload[:tool_choice]).to eq(:required)
      expect(payload[:parallel_tool_calls]).to be(false)
    end
  end
end
