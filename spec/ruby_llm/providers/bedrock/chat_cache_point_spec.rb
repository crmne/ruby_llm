# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Chat do
  let(:model) do
    instance_double(RubyLLM::Model::Info,
                    id: 'anthropic.claude-haiku-4-5-20251001-v1:0',
                    max_tokens: nil,
                    metadata: {})
  end

  let(:base_args) do
    { tools: {}, temperature: nil, model: model, stream: false }
  end

  def render(messages)
    described_class.render_payload(messages, **base_args)
  end

  def msg(role, content, cache_point: false)
    RubyLLM::Message.new(role: role, content: content, cache_point: cache_point)
  end

  describe 'cache_point injection' do
    context 'with a system message where cache_point is true' do
      it 'appends a cachePoint block to the system content' do
        payload = render([msg(:system, 'You are helpful.', cache_point: true),
                          msg(:user, 'Hi')])

        last_block = payload[:system].last
        expect(last_block).to eq(cachePoint: { type: 'default' })
      end

      it 'does not append cachePoint when cache_point is false' do
        payload = render([msg(:system, 'You are helpful.'), msg(:user, 'Hi')])

        expect(payload[:system]).not_to include(cachePoint: { type: 'default' })
      end
    end

    context 'with a user message where cache_point is true' do
      it 'appends a cachePoint block to the message content' do
        payload = render([msg(:user, 'Tell me a story.', cache_point: true)])

        last_block = payload[:messages].first[:content].last
        expect(last_block).to eq(cachePoint: { type: 'default' })
      end

      it 'does not append cachePoint when cache_point is false' do
        payload = render([msg(:user, 'Tell me a story.')])

        content = payload[:messages].first[:content]
        expect(content).not_to include(cachePoint: { type: 'default' })
      end
    end

    context 'when multiple messages have cache_point: true' do
      it 'appends cachePoint to each cache-pointed message' do
        payload = render([
                           msg(:system, 'System prompt', cache_point: true),
                           msg(:user, 'User context', cache_point: true),
                           msg(:user, 'Dynamic question')
                         ])

        system_has_cache = payload[:system].last == { cachePoint: { type: 'default' } }
        user_messages = payload[:messages]
        first_user_has_cache = user_messages.first[:content].last == { cachePoint: { type: 'default' } }
        last_user_no_cache = user_messages.last[:content].last != { cachePoint: { type: 'default' } }

        expect(system_has_cache).to be true
        expect(first_user_has_cache).to be true
        expect(last_user_no_cache).to be true
      end
    end
  end
end
