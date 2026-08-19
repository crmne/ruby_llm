# frozen_string_literal: true

require 'spec_helper'

class BedrockMantleWeather < RubyLLM::Tool
  description 'Get the current weather for a city'
  parameter :city, description: 'City name'

  def execute(city:)
    "The weather in #{city} is 15 degrees Celsius."
  end
end

RSpec.describe RubyLLM::Providers::Bedrock::Mantle do
  include_context 'with configured RubyLLM'

  let(:provider) { RubyLLM::Providers::Bedrock.new(RubyLLM.config) }

  describe 'protocol routing' do
    it 'routes un-versioned anthropic ids to the Anthropic Messages protocol' do
      %w[anthropic.claude-sonnet-5 anthropic.claude-opus-4-7 anthropic.claude-fable-5].each do |id|
        model = RubyLLM::Model.default(id, 'bedrock')
        expect(provider.protocol_for(model)).to eq(described_class::Anthropic)
      end
    end

    it 'routes the models mantle serves on v1/responses to the Responses protocol' do
      %w[openai.gpt-oss-20b openai.gpt-oss-120b google.gemma-4-31b].each do |id|
        model = RubyLLM::Model.default(id, 'bedrock')
        expect(provider.protocol_for(model)).to eq(described_class::Responses)
      end
    end

    it 'routes the rest of the non-Claude catalog to the Chat Completions protocol' do
      %w[
        nvidia.nemotron-nano-9b-v2
        qwen.qwen3-coder-next
        deepseek.v3.2
        zai.glm-4.6
        mistral.voxtral-mini-3b-2507
      ].each do |id|
        model = RubyLLM::Model.default(id, 'bedrock')
        expect(provider.protocol_for(model)).to eq(described_class::ChatCompletions)
      end
    end

    it 'keeps bare ids the mantle catalog does not list on Converse' do
      %w[
        moonshot.kimi-k2-thinking
        qwen.qwen3-next-80b-a3b
        qwen.qwen3-vl-235b-a22b
        openai.gpt-5.5
      ].each do |id|
        model = RubyLLM::Model.default(id, 'bedrock')
        expect(provider.protocol_for(model)).to eq(RubyLLM::Protocols::Converse)
      end
    end

    it 'reads the id shape for models the registry does not list at all' do
      model = RubyLLM::Model.default('vendor.unlisted-model', 'bedrock')

      expect(provider.protocol_for(model)).to eq(described_class::ChatCompletions)
    end

    it 'keeps dated, versioned, and region-prefixed ids on Converse' do
      %w[
        anthropic.claude-sonnet-4-5-20250929-v1:0
        us.anthropic.claude-sonnet-5
        eu.anthropic.claude-opus-4-8
        au.anthropic.claude-sonnet-5
        jp.anthropic.claude-opus-4-7
        global.anthropic.claude-fable-5
        amazon.nova-2-lite-v1:0
        meta.llama3-70b-instruct-v1:0
      ].each do |id|
        model = RubyLLM::Model.default(id, 'bedrock')
        expect(provider.protocol_for(model)).to eq(RubyLLM::Protocols::Converse)
      end
    end

    it 'leaves embedding routing alone' do
      model = RubyLLM::Model.default('cohere.embed-english-v3', 'bedrock')

      expect(provider.protocol_for(model, operation: :embed))
        .to eq(RubyLLM::Protocols::InvokeModel::CohereEmbeddings)
    end
  end

  describe 'the model catalog' do
    let(:catalog) do
      instance_double(
        Faraday::Response,
        body: { 'data' => [{ 'id' => 'openai.gpt-oss-20b', 'created' => 1_764_460_800 }] }
      )
    end

    it 'tags every model the mantle catalog lists' do
      models = RubyLLM::Providers::Bedrock::Models.parse_mantle_models_response(catalog, 'bedrock')

      expect(models.map(&:id)).to eq(['openai.gpt-oss-20b'])
      expect(models.first.metadata[:endpoint]).to eq('mantle')
      expect(models.first.created_at).to eq(Time.at(1_764_460_800).utc)
    end

    it 'tags models both catalogs list without dropping their Converse metadata' do
      converse = RubyLLM::Model.new(id: 'openai.gpt-oss-20b', name: 'gpt-oss-20b', provider: 'bedrock',
                                    metadata: { inference_types: ['ON_DEMAND'] })
      mantle = RubyLLM::Providers::Bedrock::Models.parse_mantle_models_response(catalog, 'bedrock')

      merged = RubyLLM::Providers::Bedrock::Models.merge_mantle_models([converse], mantle)

      expect(merged.map(&:id)).to eq(['openai.gpt-oss-20b'])
      expect(merged.first.metadata).to include(endpoint: 'mantle', inference_types: ['ON_DEMAND'])
      expect(merged.first.name).to eq('gpt-oss-20b')
    end

    it 'keeps Converse-only models untagged' do
      converse = RubyLLM::Model.new(id: 'moonshot.kimi-k2-thinking', name: 'Kimi K2 Thinking', provider: 'bedrock')

      merged = RubyLLM::Providers::Bedrock::Models.merge_mantle_models([converse], [])

      expect(merged.first.metadata).not_to have_key(:endpoint)
    end

    it 'tags the bundled registry entry for every model mantle serves' do
      tagged = RubyLLM.models.all.select do |model|
        model.provider == 'bedrock' && model.metadata[:endpoint] == 'mantle'
      end

      expect(tagged.size).to eq(48)
      expect(tagged.map(&:id)).to include('openai.gpt-oss-20b', 'anthropic.claude-haiku-4-5', 'zai.glm-5')
    end
  end

  describe 'request shape' do
    it 'renders an Anthropic Messages payload against the mantle endpoint' do
      chat = RubyLLM.chat(model: 'anthropic.claude-fable-5', provider: :bedrock, assume_model_exists: true)
      chat.ask_later('Say OK.')
      payload = chat.render

      expect(payload[:model]).to eq('anthropic.claude-fable-5')
      expect(payload[:messages].first[:role]).to eq('user')
    end

    it 'renders a Responses payload against the mantle endpoint' do
      chat = RubyLLM.chat(model: 'openai.gpt-oss-20b', provider: :bedrock, assume_model_exists: true)
      chat.ask_later('Say OK.')
      payload = chat.render

      expect(payload[:model]).to eq('openai.gpt-oss-20b')
      expect(payload[:input].first[:role]).to eq('user')
    end

    it 'points each protocol at its own mantle path' do
      expect(described_class::Anthropic.allocate.completion_url).to eq('anthropic/v1/messages')
      expect(described_class::Responses.allocate.completion_url).to eq('v1/responses')
      expect(described_class::ChatCompletions.allocate.completion_url).to eq('v1/chat/completions')
    end

    it 'sends anthropic-version only on the Anthropic protocol' do
      anthropic = described_class::Anthropic.new(provider)
      responses = described_class::Responses.new(provider)

      expect(anthropic.send(:mantle_headers, 'anthropic/v1/messages', '{}')).to include('anthropic-version')
      expect(responses.send(:mantle_headers, 'v1/responses', '{}')).not_to include('anthropic-version')
    end

    it 'signs for the bedrock-mantle service' do
      headers = provider.sign_headers(
        'POST', 'anthropic/v1/messages', '{}',
        base_url: provider.mantle_api_base, service: described_class::SIGNING_SERVICE
      )

      expect(headers['Authorization']).to include('/bedrock-mantle/aws4_request')
      expect(headers['host'] || URI.parse(provider.mantle_api_base).host).to include('bedrock-mantle.')
    end

    it 'derives the mantle base from the region with a config override' do
      expect(provider.mantle_api_base).to include("bedrock-mantle.#{RubyLLM.config.bedrock_region}")
    end
  end

  describe 'signed requests', :live do
    it 'reaches the mantle endpoint with bedrock-mantle credentials' do
      url = 'v1/models'
      headers = provider.sign_headers('GET', url, '', base_url: provider.mantle_api_base,
                                                      service: described_class::SIGNING_SERVICE)

      response = provider.mantle_connection.get(url) { |req| req.headers.merge!(headers) }

      expect(response.body['data']).to be_an(Array)
      expect(response.body['data'].map { |model| model['id'] }).to include(a_string_including('anthropic.claude'))
    end
  end

  describe 'chat', skip: 'Claude on the mantle endpoint requires an AWS Sales agreement for this account' do
    it 'chats with the newest Claude generation' do
      chat = RubyLLM.chat(model: 'anthropic.claude-sonnet-5', provider: :bedrock, assume_model_exists: true)
      response = chat.ask('Say OK and nothing else.')

      expect(response.content).to be_present
    end
  end

  describe 'responses chat', :live do
    let(:chat) { RubyLLM.chat(model: 'openai.gpt-oss-20b', provider: :bedrock) }

    it 'chats through the Responses surface' do
      response = chat.ask('Say OK and nothing else.')

      expect(response.content).to include('OK')
      expect(response.tokens.input).to be_positive
      expect(response.tokens.output).to be_positive
    end

    it 'streams through the Responses surface' do
      chunks = []
      response = chat.ask('Count from 1 to 5.') { |chunk| chunks << chunk }

      expect(chunks).not_to be_empty
      expect(chunks.filter_map(&:content).join).not_to be_empty
      expect(response.content).to include('5')
    end

    it 'calls tools through the Responses surface' do
      response = chat.with_tools(BedrockMantleWeather).ask("What's the weather in Berlin? Use the weather tool.")

      expect(response.content).to include('15')
    end
  end
end
