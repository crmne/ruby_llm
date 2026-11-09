# frozen_string_literal: true

require 'spec_helper'

class MistralCountingWeather < RubyLLM::Tool
  description 'Gets current weather for a city'
  parameter :city, description: 'City name'

  def execute(city:)
    "It's sunny in #{city}."
  end
end

RSpec.describe RubyLLM::Providers::Mistral do
  let(:config) do
    RubyLLM.config.dup.tap { |config| config.mistral_api_key ||= 'test' }
  end
  let(:provider) { described_class.new(config) }
  let(:model) { RubyLLM.models.find('mistral-small-latest', provider: 'mistral') }

  describe 'token counting' do
    it 'posts the Responses input to the input-token endpoint' do
      stub = stub_request(:post, 'https://api.mistral.ai/v1/responses/input_tokens')
             .with { |request| JSON.parse(request.body)['input'].first['role'] == 'user' }
             .to_return(status: 200, body: { input_tokens: 12 }.to_json,
                        headers: { 'Content-Type' => 'application/json' })

      count = provider.count_tokens([RubyLLM::Message.new(role: :user, content: 'Hello')], model: model)

      expect(count).to eq(12)
      expect(stub).to have_been_requested
    end

    it 'turns other protocols replies into plain input and keeps thinking in the count' do
      raw = [{ 'type' => 'message.output', 'content' => 'Hi' }]
      reply = RubyLLM::Message.new(role: :assistant, content: 'Hi', raw_content: raw,
                                   thinking: RubyLLM::Thinking.build(text: 'Greet them.'))

      input = described_class::InputTokens.new(provider, model).render_count_tokens_payload(
        [reply], model: model, tools: {}
      )[:input]

      expect(input.to_json).not_to include('message.output')
      expect(input.to_json).to include('Greet them.', 'Hi')
    end

    it 'counts a Conversations chat with history', :live do
      chat = RubyLLM.chat(model: 'mistral-small-latest', provider: :mistral, protocol: :conversations)
      chat.ask('Say hi in one word.')

      expect(chat.count_tokens('And again.')).to be_positive
    end

    it 'counts a chat with tool calls in its history', :live do
      chat = RubyLLM.chat(model: 'mistral-small-latest', provider: :mistral).with_tools(MistralCountingWeather)
      chat.ask('What is the weather in Berlin? Use the tool.')

      expect(chat.messages.map(&:role)).to include(:tool)
      expect(chat.count_tokens('And in Paris?')).to be_positive
    end

    it 'counts instructions, tools, structured output and images before generation', :live do
      chat = RubyLLM.chat(model: 'mistral-small-latest', provider: :mistral)
      base = chat.count_tokens('What is the weather in Berlin?')
      schema = { type: 'object', properties: { weather: { type: 'string' } },
                 required: ['weather'], additionalProperties: false }

      chat.ask_later('What is the weather in Berlin?')
      configured = chat.with_instructions('Be terse.').with_tools(MistralCountingWeather)
                       .with_schema(schema).count_tokens

      vision = RubyLLM.chat(model: 'mistral-small-latest', provider: :mistral)
      vision.ask_later('What is the weather in Berlin?', with: File.expand_path('../../fixtures/ruby.png', __dir__))

      expect(base).to be_positive
      expect(configured).to be > base
      expect(vision.count_tokens).to be > base
    end
  end
end
