# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Converse::RequestShapes do
  include_context 'with configured RubyLLM'

  let(:protocol) { RubyLLM::Protocols::Converse.new(RubyLLM::Providers::Bedrock.new(RubyLLM.config)) }

  it 'describes a refused conversation without its contents' do
    chat = secret_chat(provider: :bedrock, model: model_for(:bedrock))
    shape = refused_request_shape(chat)

    expect(shape.to_s).to eq(<<~SHAPE.chomp)
      bedrock, #{chat.model.id}, model call 1 of the turn
      payload keys: messages, system, inferenceConfig, toolConfig
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

  it 'finds messages that do not alternate and reasoning without its signature' do
    payload = {
      messages: [
        { role: 'assistant', content: [{ reasoningContent: { reasoningText: { text: 'secret' } } }] },
        { role: 'user', content: [{ text: 'secret' }] },
        { role: 'user', content: [{ text: 'secret' }] }
      ],
      additionalModelRequestFields: { reasoning_config: { type: 'enabled', budget_tokens: 1024 } }
    }

    shape = request_shape_for(protocol, payload)

    expect(shape.problems.map(&:to_s)).to eq(
      ['problem at #0: conversation starts with a model turn', 'problem at #0, part 0: thinking part has no signature',
       'problem at #2: follows another user turn']
    )
    expect(shape.thinking_settings).to eq('type' => 'enabled', 'budget_tokens' => 1024)
    expect_no_secrets(shape)
  end

  it 'reads the reasoning settings each model family takes' do
    fields = [{ reasoning_config: 'low' }, { reasoning_effort: 'medium' },
              { reasoningConfig: { type: 'enabled', maxReasoningEffort: 'high' } },
              { thinking: { type: 'adaptive' }, output_config: { effort: 'max' } }]

    settings = fields.map do |additional|
      request_shape_for(protocol, { messages: [], additionalModelRequestFields: additional }).thinking_settings
    end

    expect(settings).to eq([{ 'reasoning_config' => 'low' }, { 'reasoning_effort' => 'medium' },
                            { 'type' => 'enabled', 'maxReasoningEffort' => 'high' },
                            { 'type' => 'adaptive', 'effort' => 'max' }])
  end

  it 'describes the request a token count wraps, with stored documents and media formats' do
    secret = Base64.strict_encode64('secret')
    payload = {
      input: {
        converse: {
          system: [{ text: 'secret' }, { cachePoint: { type: 'default' } }],
          messages: [
            { role: 'user', content: [
              { document: { format: 'pdf', name: 'secret', source: { s3Location: { uri: 's3://secret/a.pdf' } } } },
              { document: { format: 'txt', name: 'secret', source: { text: 'secret' } } },
              { video: { format: 'mp4', source: { bytes: secret } } },
              { audio: { format: 'mp4', source: { bytes: secret } } }
            ] },
            { role: 'assistant', content: [{ reasoningContent: { redactedContent: 'secret' } },
                                           { toolUse: { toolUseId: 'secret-use', name: 'lookup', input: {} } }] },
            { role: 'user', content: [{ toolResult: { toolUseId: 'secret-use', content: [
              { json: { found: 'secret' } }, { image: { format: 'png', source: { bytes: secret } } }
            ] } }] }
          ],
          toolConfig: { tools: [{ toolSpec: { name: 'lookup' } }, { systemTool: { name: 'nova_grounding' } },
                                { cachePoint: { type: 'default' } }] }
        }
      }
    }

    shape = request_shape_for(protocol, payload)

    expect(shape.to_s.lines.map(&:chomp)).to include(
      'instructions: text (6 chars), cachePoint',
      '#0 user: application/pdf (file), text/plain (6 chars), video/mp4 (6 bytes), audio (6 bytes)',
      '#1 assistant: thinking (no text), signed, call lookup (args 2 chars)',
      '#2 user: result lookup (18 chars), image/png (6 bytes)',
      'tools: lookup, nova_grounding'
    )
    expect(shape.payload_keys).to eq(%w[input])
    expect(shape.problems).to be_empty
    expect_no_secrets(shape)
  end
end
