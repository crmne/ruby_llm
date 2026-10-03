# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Mistral::Conversations::RequestShapes do
  include_context 'with configured RubyLLM'

  let(:protocol) do
    RubyLLM::Protocols::Mistral::Conversations.new(RubyLLM::Providers::Mistral.new(RubyLLM.config))
  end

  it 'describes a refused conversation without its contents' do
    chat = secret_chat(provider: :mistral, model: model_for(:mistral), protocol: :conversations)
    shape = refused_request_shape(chat)

    expect(shape.to_s).to eq(<<~SHAPE.chomp)
      mistral, #{model_for(:mistral)}, model call 1 of the turn
      payload keys: model, inputs, instructions, completion_args, tools, store, stream
      instructions: text (19 chars)
      #0 user: text (15 chars), image/png (15941 bytes)
      #1 assistant: text (0 chars)
      #2 function.call: call lookup (args 27 chars)
      #3 function.result: result lookup (13 chars)
      #4 assistant: text (13 chars)
      #5 user: text (16 chars)
      tools: lookup
      tool round at #1: 1 call, 1 result, paired
      no problems found
    SHAPE
    expect_no_secrets(shape)
  end

  it 'describes replayed output entries, and a result that answers no call' do
    payload = {
      inputs: [
        { type: 'message.input', role: 'user', content: 'secret' },
        { type: 'message.output', content: [{ type: 'thinking', thinking: [{ type: 'text', text: 'secret' }] },
                                            { type: 'text', text: 'secret!' }] },
        { type: 'function.result', tool_call_id: 'call_unknown', result: 'secret' },
        { type: 'agent.handoff', from_agent_id: 'ag_1', to_agent_id: 'ag_2' }
      ],
      tools: [{ type: 'function', function: { name: 'lookup' } }, { type: 'web_search' }],
      completion_args: { reasoning_effort: 'high' }
    }

    shape = request_shape_for(protocol, payload)

    expect(shape.turns.map(&:to_s)).to eq(
      ['#0 user: text (6 chars)', '#1 message.output: thinking (6 chars), text (7 chars)',
       '#2 function.result: result (6 chars)', '#3 agent.handoff: agent.handoff']
    )
    expect(shape.problems.map(&:to_s))
      .to eq(['problem at #2, part 0: result answers no call in the request (call id call_unknown)'])
    expect(shape.thinking_settings).to eq('reasoning_effort' => 'high')
  end
end
