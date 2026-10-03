# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::ChatCompletions::RequestShapes do
  include_context 'with configured RubyLLM'

  let(:protocol) { RubyLLM::Protocols::ChatCompletions.new(RubyLLM::Providers::OpenAI.new(RubyLLM.config)) }

  it 'describes a refused conversation without its contents' do
    shape = refused_request_shape(secret_chat(provider: :deepseek, model: model_for(:deepseek)))

    expect(shape.to_s).to eq(<<~SHAPE.chomp)
      deepseek, #{model_for(:deepseek)}, model call 1 of the turn
      payload keys: model, messages, stream, tools
      #0 system: text (19 chars)
      #1 user: text (15 chars), image/png (15941 bytes)
      #2 assistant: thinking (14 chars), signed, text (0 chars), call lookup (args 27 chars), signed
      #3 tool: result lookup (13 chars)
      #4 assistant: thinking (11 chars), signed, text (13 chars)
      #5 user: text (16 chars)
      tools: lookup
      tool round at #2: 1 call, 1 result, paired
      no problems found
    SHAPE
    expect_no_secrets(shape)
  end

  it 'describes the same messages Cohere sends' do
    shape = refused_request_shape(secret_chat(provider: :cohere, model: model_for(:cohere)))

    expect(shape.turns.map(&:to_s)).to eq(
      ['#0 system: text (19 chars)', '#1 user: text (15 chars), image/png (15941 bytes)',
       '#2 assistant: text (0 chars), call lookup (args 27 chars)', '#3 tool: result lookup (13 chars)',
       '#4 assistant: text (13 chars)', '#5 user: text (16 chars)']
    )
    expect(shape.problems).to be_empty
    expect_no_secrets(shape)
  end

  it 'describes linked media, uploaded files, audio, reasoning details, and a result that answers no call' do
    pdf = "data:application/pdf;base64,#{Base64.strict_encode64('secret')}"
    payload = {
      messages: [
        { role: 'developer', content: 'secret' },
        { role: 'user', content: [
          { type: 'image_url', image_url: { url: 'https://example.com/secret.png' } },
          { type: 'file', file: { file_id: 'file-secret' } },
          { type: 'file', file: { filename: 'secret.pdf', file_data: pdf } },
          { type: 'input_audio', input_audio: { data: Base64.strict_encode64('secret!!'), format: 'wav' } }
        ] },
        { role: 'assistant', content: nil, reasoning_details: [
          { type: 'reasoning.text', text: 'secret', signature: 'secret' },
          { type: 'reasoning.encrypted', data: 'secret' }
        ], tool_calls: [{ id: 'secret-call', type: 'function', function: { name: 'lookup', arguments: '{}' } }] },
        { role: 'tool', tool_call_id: 'secret-call', content: [{ type: 'text', text: 'secret' }] },
        { role: 'tool', tool_call_id: 'call_unknown', content: 'secret!' }
      ],
      tools: [{ type: 'function', function: { name: 'lookup' } }, { type: 'web_search' }],
      reasoning_effort: 'high'
    }

    shape = request_shape_for(protocol, payload)

    expect(shape.turns.map(&:to_s)).to eq(
      ['#0 developer: text (6 chars)',
       '#1 user: image (url), document (file), application/pdf (6 bytes), audio (8 bytes)',
       '#2 assistant: thinking (6 chars), signed, thinking (no text), signed, call lookup (args 2 chars)',
       '#3 tool: result lookup (6 chars)', '#4 tool: result (7 chars)']
    )
    expect(shape.problems.map(&:to_s)).to eq(
      ['problem at #2: 1 call but 2 results',
       'problem at #4, part 0: result answers no call in the request (call id call_unknown)']
    )
    expect(shape.thinking_settings).to eq('reasoning_effort' => 'high')
  end

  it 'describes the documents Mistral and Perplexity render' do
    pdf = File.expand_path('../../../fixtures/sample.pdf', __dir__)

    { mistral: 'application/pdf (18810 bytes)', perplexity: 'document (18810 bytes)' }.each do |provider, document|
      chat = RubyLLM.chat(model: model_for(provider), provider:, protocol: :chat_completions)
      chat.add_message(role: :user, content: 'secret', attachments: [pdf])

      expect(refused_request_shape(chat).turns.map(&:to_s)).to eq(["#0 user: text (6 chars), #{document}"])
    end
  end

  it 'describes the documents Mistral and Perplexity send by link or as data' do
    pdf = Base64.strict_encode64('secret!')
    payload = {
      messages: [
        { role: 'user', content: [
          { type: 'document_url', document_url: "data:application/pdf;base64,#{pdf}" },
          { type: 'document_url', document_url: 'https://example.com/secret.pdf' },
          { type: 'file_url', file_url: { url: pdf } },
          { type: 'file_url', file_url: { url: 'https://example.com/secret.pdf' } }
        ] }
      ]
    }

    expect(request_shape_for(protocol, payload).turns.map(&:to_s))
      .to eq(['#0 user: application/pdf (7 bytes), document (url), document (7 bytes), document (url)'])
  end
end
