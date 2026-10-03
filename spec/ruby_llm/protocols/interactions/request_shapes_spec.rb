# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Interactions::RequestShapes do
  include_context 'with configured RubyLLM'

  let(:protocol) { RubyLLM::Protocols::Interactions.new(RubyLLM::Providers::Gemini.new(RubyLLM.config)) }

  it 'describes a refused conversation without its contents' do
    chat = secret_chat(provider: :gemini, model: model_for(:gemini, :mcp), protocol: :interactions)
    shape = refused_request_shape(chat)

    expect(shape.to_s).to eq(<<~SHAPE.chomp)
      gemini, #{model_for(:gemini, :mcp)}, model call 1 of the turn
      payload keys: model, input, stream, store, system_instruction, generation_config, tools
      instructions: text (19 chars)
      #0 user_input: text (15 chars), image/png (15941 bytes)
      #1 function_call: call lookup (args 27 chars), signed
      #2 function_result: result lookup (13 chars)
      #3 model_output: text (13 chars)
      #4 user_input: text (16 chars)
      tools: lookup
      tool round at #1: 1 call, 1 result, paired
      no problems found
    SHAPE
    expect_no_secrets(shape)
  end

  it 'describes replayed steps and linked media, and finds an unsigned step' do
    payload = {
      system_instruction: '',
      input: [
        { type: 'user_input', content: [
          { type: 'video', mime_type: 'video/mp4', uri: 'https://example.com/secret.mp4' },
          { type: 'document', mime_type: 'application/pdf', data: Base64.strict_encode64('secret') }
        ] },
        { type: 'thought', summary: [{ type: 'text', text: 'secret' }], signature: 'secret' },
        { type: 'google_search_call', id: 'search_1', arguments: { queries: ['secret'] }, signature: 'secret' },
        { type: 'google_search_result', call_id: 'search_1', result: [] },
        { type: 'function_call', id: 'secret-call', name: 'lookup', arguments: {} },
        { type: 'function_result', call_id: 'secret-call', result: [{ type: 'text', text: 'secret' }] }
      ],
      tools: [{ type: 'function', name: 'lookup' }, { type: 'google_search' }],
      generation_config: { thinking_level: 'high', thinking_summaries: 'auto' }
    }

    shape = request_shape_for(protocol, payload)

    expect(shape.to_s.lines.map(&:chomp)).to include(
      'instructions: text (0 chars)', '#0 user_input: video/mp4 (url), application/pdf (6 bytes)',
      '#1 thought: thinking (6 chars), signed', '#2 google_search_call: google_search_call, signed',
      '#5 function_result: result lookup (6 chars)', 'thinking: thinking_level high, thinking_summaries auto'
    )
    expect(shape.problems.map(&:to_s))
      .to eq(['problem at #4, part 0: first call of a step in the current turn has no signature'])
    expect_no_secrets(shape)
  end
end
