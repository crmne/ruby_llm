# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Responses::RequestShapes do
  include_context 'with configured RubyLLM'

  let(:protocol) { RubyLLM::Protocols::Responses.new(RubyLLM::Providers::OpenAI.new(RubyLLM.config)) }

  it 'describes a refused conversation without its contents' do
    shape = refused_request_shape(secret_chat(provider: :openai, model: model_for(:openai)))

    expect(shape.to_s).to eq(<<~SHAPE.chomp)
      openai, #{model_for(:openai)}, model call 1 of the turn
      payload keys: model, input, instructions, stream, store, include, tools
      instructions: text (19 chars)
      #0 user: text (15 chars), image/png (15941 bytes)
      #1 reasoning: thinking (14 chars), signed
      #2 function_call: call lookup (args 27 chars)
      #3 function_call_output: result lookup (13 chars)
      #4 reasoning: thinking (11 chars), signed
      #5 assistant: text (13 chars)
      #6 user: text (16 chars)
      tools: lookup
      tool round at #1: 1 call, 1 result, paired
      no problems found
    SHAPE
    expect_no_secrets(shape)
  end

  it 'describes replayed output items, every file input, and outputs that answer no call' do
    image = "data:image/png;base64,#{Base64.strict_encode64('secret')}"
    payload = {
      input: [
        { role: 'user', content: [
          { type: 'input_image', file_id: 'file-secret' },
          { type: 'input_file', file_url: 'https://example.com/secret.pdf' },
          { type: 'input_file', filename: 'secret.pdf',
            file_data: "data:application/pdf;base64,#{Base64.strict_encode64('secret')}" }
        ] },
        { type: 'reasoning', summary: [], encrypted_content: 'secret' },
        { type: 'web_search_call', id: 'ws_1', status: 'completed', action: { query: 'secret' } },
        { type: 'function_call', call_id: 'secret-call', name: 'lookup', arguments: '{}' },
        { type: 'function_call_output', call_id: 'secret-call',
          output: [{ type: 'input_text', text: 'secret' }, { type: 'input_image', image_url: image }] },
        { type: 'function_call_output', call_id: 'call_unknown', output: 'secret' },
        { type: 'message', role: 'assistant', content: [{ type: 'output_text', text: 'secret', annotations: [] }] }
      ],
      tools: [{ type: 'function', name: 'lookup' }, { type: 'web_search' }],
      reasoning: { effort: 'medium', summary: 'auto' }
    }

    shape = request_shape_for(protocol, payload)

    expect(shape.turns.map(&:to_s)).to eq(
      ['#0 user: image (file), document (url), application/pdf (6 bytes)', '#1 reasoning: thinking (no text), signed',
       '#2 web_search_call: web_search_call', '#3 function_call: call lookup (args 2 chars)',
       '#4 function_call_output: result lookup (6 chars), image/png (6 bytes)',
       '#5 function_call_output: result (6 chars)', '#6 assistant: text (6 chars)']
    )
    expect(shape.problems.map(&:to_s)).to eq(
      ['problem at #1: 1 call but 2 results',
       'problem at #5, part 0: result answers no call in the request (call id call_unknown)']
    )
    expect(shape.thinking_settings).to eq('effort' => 'medium', 'summary' => 'auto')
  end

  it 'describes nothing in a request that holds no conversation' do
    expect(request_shape_for(protocol, model: model_for(:openai), input: 'secret')).to be_nil
  end
end
