# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::RequestShapes do
  include_context 'with configured RubyLLM'

  let(:protocol) { RubyLLM::Protocols::Anthropic.new(RubyLLM::Providers::Anthropic.new(RubyLLM.config)) }

  it 'describes a refused conversation without its contents' do
    chat = secret_chat(provider: :anthropic, model: model_for(:anthropic))
    shape = refused_request_shape(chat)

    expect(shape.to_s).to eq(<<~SHAPE.chomp)
      anthropic, #{chat.model.id}, model call 1 of the turn
      payload keys: model, messages, stream, max_tokens, tools, system
      instructions: text (19 chars)
      #0 user: text (15 chars), image/png (15941 bytes)
      #1 assistant: thinking (14 chars), signed, call lookup (args 27 chars)
      #2 user: result lookup (13 chars)
      #3 assistant: thinking (11 chars), signed, text (13 chars)
      #4 user: text (16 chars)
      tools: lookup
      tool round at #1: 1 call, 1 result, paired
      no problems found
    SHAPE
    expect_no_secrets(shape)
  end

  it 'finds thinking without its signature, and a result that answers no call' do
    data = Base64.strict_encode64('secret')
    image = { type: 'image', source: { type: 'base64', media_type: 'image/png', data: } }
    payload = {
      messages: [
        { role: 'user', content: 'secret' },
        { role: 'assistant', content: [{ type: 'thinking', thinking: 'secret' },
                                       { type: 'tool_use', id: 'toolu_secret', name: 'lookup', input: {} }] },
        { role: 'user', content: [
          { type: 'tool_result', tool_use_id: 'toolu_secret', content: [{ type: 'text', text: 'secret' }, image] },
          { type: 'tool_result', tool_use_id: 'toolu_unknown', content: 'secret!' }
        ] }
      ],
      thinking: { type: 'enabled', budget_tokens: 2048 }, output_config: { effort: 'high' }
    }

    shape = request_shape_for(protocol, payload)

    expect(shape.turns[2].to_s).to eq('#2 user: result lookup (6 chars), image/png (6 bytes), result (7 chars)')
    expect(shape.problems.map(&:to_s)).to eq(
      ['problem at #1: 1 call but 2 results', 'problem at #1, part 0: thinking part has no signature',
       'problem at #2, part 2: result answers no call in the request (call id toolu_unknown)']
    )
    expect(shape.thinking_settings).to eq('type' => 'enabled', 'budget_tokens' => 2048, 'effort' => 'high')
  end

  it 'describes redacted thinking, every document source, and provider tool blocks' do
    pdf = Base64.strict_encode64('secret!')
    payload = {
      system: 'secret',
      messages: [
        { role: 'user', content: [
          { type: 'image', source: { type: 'url', url: 'https://example.com/secret.png' } },
          { type: 'document', source: { type: 'file', file_id: 'file_secret' } },
          { type: 'document', source: { type: 'text', media_type: 'text/plain', data: 'secret' } },
          { type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: pdf } }
        ] },
        { role: 'assistant', content: [
          { type: 'redacted_thinking', data: 'secret' },
          { type: 'server_tool_use', id: 'srvtoolu_1', name: 'web_search', input: { query: 'secret' } },
          { type: 'web_search_tool_result', tool_use_id: 'srvtoolu_1', content: [] }
        ] },
        { role: 'user', content: 'secret' }
      ],
      tools: [{ name: 'lookup', input_schema: {} }, { type: 'web_search_20260318', name: 'web_search' },
              { type: 'mcp_toolset', mcp_server_name: 'docs' }]
    }

    shape = request_shape_for(protocol, payload)

    expect(shape.turns.map(&:to_s)).to eq(
      ['#0 user: image (url), document (file), text/plain (6 chars), application/pdf (7 bytes)',
       '#1 assistant: thinking (no text), signed, server_tool_use, web_search_tool_result',
       '#2 user: text (6 chars)']
    )
    expect(shape.tool_names).to eq(%w[lookup web_search mcp_toolset])
    expect(shape.problems).to be_empty
    expect_no_secrets(shape)
  end
end
