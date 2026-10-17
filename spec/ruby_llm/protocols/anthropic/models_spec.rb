# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Anthropic::Models do
  describe '#parse_list_models_response' do
    let(:parser) { Object.new.extend(described_class) }
    let(:response_class) { Struct.new(:body) }

    let(:response) do
      instance_double(
        response_class,
        body: {
          'data' => [
            {
              'id' => 'claude-sonnet-4-5',
              'display_name' => 'Claude Sonnet 4.5',
              'created_at' => '2026-01-02T03:04:05Z'
            }
          ]
        }
      )
    end

    it 'returns minimal provider metadata for models covered by models.dev' do
      model = parser.send(:parse_list_models_response, response, 'anthropic').first

      expect(model.id).to eq('claude-sonnet-4-5')
      expect(model.name).to eq('Claude Sonnet 4.5')
      expect(model.provider).to eq('anthropic')
      expect(model.created_at).to eq(Time.parse('2026-01-02T03:04:05Z'))
      expect(model.family).to be_nil
      expect(model.context_window).to be_nil
      expect(model.max_output_tokens).to be_nil
      expect(model.capabilities).to eq([])
      expect(model.pricing.to_h).to eq({})
    end

    it 'reads limits and capabilities the API reports' do
      response = instance_double(
        response_class,
        body: {
          'data' => [
            {
              'id' => 'claude-opus-5',
              'display_name' => 'Claude Opus 5',
              'created_at' => '2026-07-24T00:00:00Z',
              'max_input_tokens' => 1_000_000,
              'max_tokens' => 128_000,
              'capabilities' => {
                'batch' => { 'supported' => true },
                'citations' => { 'supported' => true },
                'code_execution' => { 'supported' => true },
                'image_input' => { 'supported' => true },
                'pdf_input' => { 'supported' => true },
                'structured_outputs' => { 'supported' => true },
                'thinking' => { 'supported' => true },
                'effort' => { 'supported' => false }
              }
            }
          ]
        }
      )

      model = parser.send(:parse_list_models_response, response, 'anthropic').first

      expect(model.context_window).to eq(1_000_000)
      expect(model.max_output_tokens).to eq(128_000)
      expect(model.capabilities).to contain_exactly(
        'citations', 'batch', 'vision', 'structured_output', 'reasoning'
      )
      expect(model.capabilities - RubyLLM::Models::Schema::CAPABILITIES).to be_empty
    end

    it 'leaves out capabilities the API reports as unsupported' do
      response = response_class.new(
        { 'data' => [{ 'id' => 'claude-haiku-4-5', 'created_at' => '2026-01-02T03:04:05Z',
                       'capabilities' => { 'citations' => { 'supported' => false }, 'batch' => true,
                                           'thinking' => { 'supported' => true } } }] }
      )

      expect(parser.send(:parse_list_models_response, response, 'anthropic').first.capabilities).to eq(['reasoning'])
    end
  end

  describe '#list_models' do
    it 'follows the pages the API reports' do
      pages = [
        { 'data' => [{ 'id' => 'claude-opus-5', 'created_at' => '2026-07-24T00:00:00Z' }], 'has_more' => true,
          'last_id' => 'claude-opus-5' },
        { 'data' => [{ 'id' => 'claude-haiku-4-5', 'created_at' => '2026-01-02T03:04:05Z' }], 'has_more' => false }
      ]
      params = []
      connection = Object.new
      connection.define_singleton_method(:get) do |url, &block|
        request = Struct.new(:params).new
        block.call(request)
        params << [url, request.params]
        Struct.new(:body).new(pages.shift)
      end
      lister = Object.new.extend(described_class)
      lister.instance_variable_set(:@connection, connection)
      lister.instance_variable_set(:@provider, instance_double(RubyLLM::Providers::Anthropic, slug: 'anthropic'))

      expect(lister.list_models.map(&:id)).to eq(%w[claude-opus-5 claude-haiku-4-5])
      expect(params).to eq([['v1/models', { limit: 1000 }],
                            ['v1/models', { limit: 1000, after_id: 'claude-opus-5' }]])
    end
  end

  describe '#parse_cache_write_tokens' do
    it 'sums the lifetimes of a message_delta that reports only a breakdown' do
      parser = Object.new.extend(described_class)
      data = { 'type' => 'message_delta',
               'usage' => { 'cache_creation' => { 'ephemeral_5m_input_tokens' => 3,
                                                  'ephemeral_1h_input_tokens' => 4 } } }

      expect(parser.send(:parse_cache_write_tokens, data)).to eq(7)
    end
  end
end
