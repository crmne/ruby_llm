# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocol::RequestShapes do
  include_context 'with configured RubyLLM'

  let(:provider) { RubyLLM::Providers::OpenAI.new(RubyLLM.config) }
  let(:protocol) do
    Class.new(RubyLLM::Protocol) do
      def parse_request_shape(payload)
        turns = shape_list(payload['media']).each_with_index.map do |media, index|
          media = shape_hash(media)
          shape_turn(index, 'user', :user, [shape_inline(media['data'], mime_type: media['mime_type'])])
        end
        shape_request(turns, payload:, tool_names: payload['tools'],
                             thinking_settings: shape_settings(payload['thinking'], 'effort', 'budget', 'note'))
      end
    end.new(provider)
  end

  it 'measures base64 data in decoded bytes' do
    payload = { media: [{ data: Base64.strict_encode64('secret'), mime_type: 'image/png' },
                        { data: Base64.strict_encode64('secret!'), mime_type: 'audio/wav' },
                        { data: Base64.encode64('secret' * 20), mime_type: 'application/pdf' },
                        { data: nil }],
                tools: ['lookup', nil, ''] }

    expect(request_shape_for(protocol, payload).turns.map(&:to_s)).to eq(
      ['#0 user: image/png (6 bytes)', '#1 user: audio/wav (7 bytes)', '#2 user: application/pdf (120 bytes)',
       '#3 user: document (no data)']
    )
    expect(request_shape_for(protocol, payload).tool_names).to eq(%w[lookup])
  end

  it 'keeps only thinking settings that are words and numbers' do
    payload = { media: [], thinking: { effort: 'high', budget: 2048, note: 'think about the secret plan' } }

    expect(request_shape_for(protocol, payload).thinking_settings).to eq('effort' => 'high', 'budget' => 2048)
  end

  describe 'Protocol#request_shape' do
    it 'describes nothing for a protocol that renders no conversation' do
      expect(request_shape_for(Class.new(RubyLLM::Protocol).new(provider), messages: [])).to be_nil
    end

    it 'describes nothing for a payload that is not an object' do
      expect(request_shape_for(protocol, %w[secret])).to be_nil
      expect(request_shape_for(protocol, 'secret')).to be_nil
      expect(request_shape_for(protocol, nil)).to be_nil
    end

    it 'reads a payload that repeats a key, as string-keyed provider options can make it' do
      payload = { :media => [], 'media' => [{ data: Base64.strict_encode64('secret'), mime_type: 'image/png' }] }

      expect(request_shape_for(protocol, payload).turns.map(&:to_s)).to eq(['#0 user: image/png (6 bytes)'])
    end

    it 'describes nothing rather than raise when reading the payload fails' do
      broken = Class.new(RubyLLM::Protocol) { define_method(:parse_request_shape) { |_payload| raise 'secret' } }

      expect(request_shape_for(broken.new(provider), messages: [])).to be_nil
    end
  end

  describe 'payloads a request hook reshaped' do
    let(:malformed) do
      [
        { contents: [nil, 'secret', 1, { role: 7, parts: 'secret' },
                     { parts: [nil, 'secret', { functionCall: 'secret', inlineData: { data: 5 } },
                               { functionResponse: { response: { content: 'secret' }, parts: 'secret' } }] }],
          systemInstruction: 'secret', tools: 'secret', generationConfig: { thinkingConfig: 'secret' } },
        { generateContentRequest: 'secret', contents: [{ role: 'user', parts: [{ text: 5 }] }] },
        { messages: [nil, 'secret', { role: [], content: 5, tool_calls: 'secret', reasoning_details: 'secret' },
                     { role: 'tool', content: [nil, 'secret', { type: 'image_url', image_url: 5 }] },
                     { role: 'user', content: [nil, 'secret', { type: 5, source: 'secret', image_url: 5 },
                                               { type: 'tool_result', content: [nil, 5] },
                                               { type: 'file_url', file_url: 5 }] }],
          system: 5, tools: [nil, 'secret', { function: 'secret' }], thinking: 'secret', reasoning: 5 },
        { input: [nil, 'secret', { type: 5 }, { type: 'reasoning', summary: 'secret' },
                  { type: 'function_call_output', output: [nil, { type: 5 }] },
                  { role: 'user', content: [nil, { type: 'input_image', image_url: 5 }, { type: 'input_file' }] }],
          instructions: 5, system_instruction: [], tools: [nil, 'secret'], generation_config: 'secret' },
        { input: { converse: { messages: [{ content: [nil, { image: 'secret' }, {}, { text: 5 },
                                                      { toolResult: { content: 'secret' } },
                                                      { document: { format: 5, source: 'secret' } }] }],
                               system: 'secret', toolConfig: 'secret', additionalModelRequestFields: 5 } } },
        { inputs: [nil, { type: 'message.input', content: 5 }, { type: 'function.call', arguments: [] },
                   { type: 'function.result', result: { 'secret' => 5 } }], completion_args: 'secret' }
      ]
    end
    let(:protocols) do
      [RubyLLM::Protocols::Gemini.new(RubyLLM::Providers::Gemini.new(RubyLLM.config))]
    end

    it 'describe what they can and never raise' do
      protocols.product(malformed).each do |protocol, payload|
        shape = protocol.parse_request_shape(JSON.parse(JSON.generate(payload)))

        expect(shape).to be_nil.or be_a(RubyLLM::RequestShape)
        expect(everything_shown(shape)).not_to include('secret') if shape
      end
    end
  end
end
