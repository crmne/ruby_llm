# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::Caches do
  let(:protocol) { RubyLLM::Protocols::Gemini.allocate }

  describe '#render_cache_payload' do
    it 'renders the model, contents, system instruction, and ttl' do
      payload = protocol.send(
        :render_cache_payload,
        'A long stable prefix.',
        model: 'gemini-2.5-flash',
        ttl: 300,
        instructions: 'You are a careful analyst.',
        attachments: []
      )

      expect(payload).to eq(
        model: 'models/gemini-2.5-flash',
        contents: [{ role: 'user', parts: [{ text: 'A long stable prefix.' }] }],
        systemInstruction: { parts: [{ text: 'You are a careful analyst.' }] },
        ttl: '300s'
      )
    end

    it 'omits system instruction and ttl when not given' do
      payload = protocol.send(
        :render_cache_payload, 'Prefix.', model: 'gemini-2.5-flash', attachments: []
      )

      expect(payload.keys).to eq(%i[model contents])
    end

    it 'formats attachments through the Gemini media handling' do
      attachment = RubyLLM::Attachment.new(StringIO.new('fake-png'), filename: 'diagram.png')

      payload = protocol.send(
        :render_cache_payload, 'See the diagram.', model: 'gemini-2.5-flash', attachments: [attachment]
      )

      parts = payload[:contents].first[:parts]
      expect(parts.first).to eq(text: 'See the diagram.')
      expect(parts.last[:inline_data][:mime_type]).to eq('image/png')
    end

    it 'passes duration strings through as ttl' do
      payload = protocol.send(
        :render_cache_payload, 'Prefix.', model: 'gemini-2.5-flash', ttl: '450s', attachments: []
      )

      expect(payload[:ttl]).to eq('450s')
    end
  end

  describe '#render_cache_update_payload' do
    it 'converts numeric ttls into duration strings' do
      expect(protocol.send(:render_cache_update_payload, ttl: 600)).to eq(ttl: '600s')
    end
  end

  describe '#parse_cache_response' do
    let(:provider) { instance_double(RubyLLM::Providers::Gemini, slug: 'gemini') }
    let(:data) do
      {
        'name' => 'cachedContents/abc123',
        'model' => 'models/gemini-2.5-flash',
        'createTime' => '2026-08-11T10:00:00Z',
        'expireTime' => '2026-08-11T11:00:00Z',
        'usageMetadata' => { 'totalTokenCount' => 7809 }
      }
    end

    before { protocol.instance_variable_set(:@provider, provider) }

    it 'builds a CachedContent from the resource' do
      cache = protocol.send(:parse_cache_response, data)

      expect(cache).to be_a(RubyLLM::CachedContent)
      expect(cache.name).to eq('cachedContents/abc123')
      expect(cache.model).to eq('gemini-2.5-flash')
      expect(cache.provider).to eq('gemini')
      expect(cache.created_at).to eq(Time.iso8601('2026-08-11T10:00:00Z'))
      expect(cache.expires_at).to eq(Time.iso8601('2026-08-11T11:00:00Z'))
      expect(cache.tokens).to eq(7809)
      expect(cache.metadata).to eq(data)
    end
  end

  describe '#cache_name' do
    it 'prefixes bare ids with the collection name' do
      expect(protocol.send(:cache_name, 'abc123')).to eq('cachedContents/abc123')
    end

    it 'keeps full resource names unchanged' do
      expect(protocol.send(:cache_name, 'cachedContents/abc123')).to eq('cachedContents/abc123')
    end

    it 'unwraps CachedContent instances' do
      cache = RubyLLM::CachedContent.new(name: 'cachedContents/abc123')

      expect(protocol.send(:cache_name, cache)).to eq('cachedContents/abc123')
    end
  end

  describe 'Vertex AI overrides' do
    include_context 'with configured RubyLLM'

    let(:provider) { RubyLLM::Providers::VertexAI.new(RubyLLM.config) }
    let(:protocol) { provider.protocols[:gemini].new(provider) }
    let(:location_path) { provider.location_path }

    it 'scopes the collection to the configured project and location' do
      expect(protocol.caches_url).to eq("#{location_path}/cachedContents")
    end

    it 'renders the model as a full Vertex resource path' do
      payload = protocol.send(
        :render_cache_payload, 'Prefix.', model: 'gemini-2.5-flash', attachments: []
      )

      expect(payload[:model]).to eq("#{location_path}/publishers/google/models/gemini-2.5-flash")
    end

    it 'prefixes bare cache ids with the project path' do
      expect(protocol.cache_name('12345')).to eq("#{location_path}/cachedContents/12345")
    end

    it 'keeps full resource names unchanged' do
      name = 'projects/p/locations/global/cachedContents/12345'

      expect(protocol.cache_name(name)).to eq(name)
    end
  end
end
