# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::RequestShapes do
  include_context 'with configured RubyLLM'

  let(:protocol) do
    provider = RubyLLM::Providers::Gemini.new(RubyLLM.config)
    RubyLLM::Protocols::Gemini.new(provider, RubyLLM.models.find(model_for(:gemini), provider: :gemini))
  end

  it 'describes a refused conversation without its contents' do
    shape = refused_request_shape(secret_chat(provider: :gemini, model: model_for(:gemini)))

    expect(shape.to_s).to eq(<<~SHAPE.chomp)
      gemini, #{model_for(:gemini)}, model call 1 of the turn
      payload keys: contents, generationConfig, systemInstruction, tools
      instructions: text (19 chars)
      #0 user: text (15 chars), image/png (15941 bytes)
      #1 model: call lookup (args 27 chars), signed
      #2 user: result lookup (13 chars)
      #3 model: thinking (11 chars), text (13 chars), signed
      #4 user: text (16 chars)
      tools: lookup
      tool round at #1: 1 call, 1 result, paired
      no problems found
    SHAPE
    expect_no_secrets(shape)
  end

  it 'finds a thought part that carries only a signature, which Gemini refuses' do
    payload = {
      contents: [
        { role: 'user', parts: [{ text: 'secret' }] },
        { role: 'model', parts: [{ thought: true, thoughtSignature: 'secret' }, { text: 'secret' }] },
        { role: 'user', parts: [{ text: 'secret' }] }
      ],
      generationConfig: { thinkingConfig: { includeThoughts: true, thinkingBudget: -1 } }
    }

    shape = request_shape_for(protocol, payload)

    expect(shape.turns[1].to_s).to eq('#1 model: thinking (no text), signed, text (6 chars)')
    expect(shape.problems.map(&:to_s)).to eq(['problem at #1, part 0: thinking part carries no data'])
    expect(shape.thinking_settings).to eq('includeThoughts' => true, 'thinkingBudget' => -1)
    expect_no_secrets(shape)
  end

  it 'finds unsigned steps and function responses that do not answer their calls' do
    payload = {
      contents: [
        { role: 'user', parts: [{ text: 'secret' }] },
        { role: 'model', parts: [{ functionCall: { name: 'lookup', args: {} } },
                                 { functionCall: { name: 'fetch', args: {} } }] },
        { role: 'user', parts: [{ functionResponse: { name: 'lookup', response: { content: 'secret' } } }] }
      ]
    }

    shape = request_shape_for(protocol, payload)

    expect(shape.step).to eq(2)
    expect(shape.problems.map(&:to_s)).to eq(
      ['problem at #1: 2 calls but 1 result',
       'problem at #1, part 0: first call of a step in the current turn has no signature']
    )
  end

  it 'follows a tool result with the media Gemini 3 sends beside it' do
    chat = RubyLLM.chat(model: model_for(:gemini, :thinking_signatures), provider: :gemini)
    call = RubyLLM::ToolCall.new(id: 'secret-call', name: 'lookup', arguments: {})
    chat.add_message(role: :user, content: 'secret')
    chat.add_message(role: :assistant, content: nil, tool_calls: { 'secret-call' => call })
    chat.add_message(role: :tool, content: 'secret result', tool_call_id: 'secret-call',
                     attachments: [RequestShapeHelpers::SECRET_IMAGE])

    shape = refused_request_shape(chat)

    expect(shape.turns.last.to_s).to eq('#2 user: result lookup (13 chars), image/png (15941 bytes)')
    expect(shape.step).to eq(2)
    expect(shape.problems).to be_empty
    expect_no_secrets(shape)
  end

  it 'describes parts a model returned in camel case, and the request a token count wraps' do
    audio = { inlineData: { mimeType: 'audio/wav', data: Base64.strict_encode64('secret') } }
    pdf = { fileData: { mimeType: 'application/pdf', fileUri: 'https://example.com/secret' } }
    payload = {
      generateContentRequest: {
        contents: [
          { role: 'user', parts: [audio, pdf] },
          { role: 'model', parts: [{ executableCode: { code: 'print("secret")' } }, { thoughtSignature: 'secret' }] }
        ],
        tools: [{ functionDeclarations: [{ name: 'lookup' }] }, { google_search: {} }]
      }
    }

    shape = request_shape_for(protocol, payload)

    expect(shape.turns.map(&:to_s)).to eq(['#0 user: audio/wav (6 bytes), application/pdf (file)',
                                           '#1 model: executableCode, part of no known kind, signed'])
    expect(shape.payload_keys).to eq(%w[generateContentRequest])
    expect(shape.tool_names).to eq(%w[lookup google_search])
    expect(shape.problems.map(&:to_s)).to eq(['problem at #1, part 1: part carries no data'])
    expect_no_secrets(shape)
  end

  it 'describes nothing in a request that holds no conversation' do
    expect(request_shape_for(protocol, requests: [{ content: { parts: [{ text: 'secret' }] } }])).to be_nil
    expect(request_shape_for(protocol, contents: 'secret')).to be_nil
  end
end
