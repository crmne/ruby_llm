# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chat do
  include_context 'with configured RubyLLM'

  describe '#before_request' do
    let(:chat) { RubyLLM.chat(model: model_for(:anthropic), provider: 'anthropic') }

    it 'lets hooks mutate the rendered payload in place' do
      chat.before_request { |payload| payload[:metadata] = { user_id: 'u-1' } }
      chat.ask_later('Hello')

      expect(chat.render[:metadata]).to eq({ user_id: 'u-1' })
    end

    it 'lets hooks add provider-native content blocks' do
      chat.before_request do |payload|
        payload[:messages].last[:content] << { type: 'custom_context', data: 'x' }
      end
      chat.ask_later('Hello')

      expect(chat.render[:messages].last[:content].last).to eq({ type: 'custom_context', data: 'x' })
    end

    it 'supports wholesale replacement via payload.replace' do
      chat.before_request { |payload| payload.replace(payload.merge(stream: true)) }
      chat.ask_later('Hello')

      expect(chat.render[:stream]).to be true
    end

    it 'ignores hook return values' do
      chat.before_request { |payload| { replacement: true } if payload }
      chat.ask_later('Hello')

      expect(chat.render).not_to have_key(:replacement)
      expect(chat.render[:messages]).to be_an(Array)
    end

    it 'runs hooks in registration order after params merging' do
      chat.with_provider_options(metadata: { user_id: 'from-params' })
      chat.before_request { |payload| payload[:metadata][:user_id] = 'from-hook' }
      chat.ask_later('Hello')

      expect(chat.render[:metadata]).to eq({ user_id: 'from-hook' })
    end

    it 'keeps in-place tool edits out of later requests and other chats' do
      tool = Class.new(RubyLLM::Tool) do
        description 'Looks up a product'
        parameters { string :sku }
        provider_options cache_control: { type: 'ephemeral' }

        def name = 'lookup'
      end
      chat.with_tools(tool).ask_later('Hello')
      chat.before_request do |payload|
        payload[:tools].first[:input_schema]['required'] << 'tenant'
        payload[:tools].first[:cache_control][:ttl] = '1h'
      end
      other = RubyLLM.chat(model: model_for(:anthropic), provider: 'anthropic').with_tools(tool)
      other.ask_later('Hello')

      expect(Array.new(2) { chat.render[:tools].first[:input_schema]['required'] }).to eq([%w[sku tenant]] * 2)
      expect(other.render[:tools].first).to include(input_schema: include('required' => ['sku']),
                                                    cache_control: { type: 'ephemeral' })
    end

    it 'keeps in-place schema edits out of later requests' do
      chat = RubyLLM.chat(model: model_for(:openai), provider: 'openai')
      chat.with_schema(type: 'object', properties: { answer: { type: 'string' } }, required: ['answer'])
      chat.before_request { |payload| payload.dig(:text, :format, :schema, :required) << 'tenant' }
      chat.ask_later('Hello')

      expect(Array.new(2) { chat.render.dig(:text, :format, :schema, :required) }).to eq([%w[answer tenant]] * 2)
    end
  end
end
