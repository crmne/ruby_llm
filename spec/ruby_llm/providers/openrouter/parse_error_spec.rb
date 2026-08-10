# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::OpenRouter do # rubocop:disable RSpec/SpecFilePathFormat
  let(:provider) do
    config = RubyLLM::Configuration.new
    config.openrouter_api_key = 'test'
    described_class.new(config)
  end

  describe '#parse_error' do
    it 'appends nested provider message from metadata.raw when present' do
      response = instance_double(
        Faraday::Response,
        body: {
          error: {
            message: 'Provider returned error',
            code: 403,
            metadata: {
              raw: {
                error: {
                  code: 'unsupported_country_region_territory',
                  message: 'Country, region, or territory not supported',
                  type: 'request_forbidden'
                }
              }.to_json,
              provider_name: 'OpenAI'
            }
          },
          user_id: 'user_2'
        }.to_json
      )

      expect(provider.parse_error(response))
        .to eq('Provider returned error - Country, region, or territory not supported')
    end

    it 'returns the top-level message when metadata.raw is missing' do
      response = instance_double(
        Faraday::Response,
        body: {
          error: {
            message: 'Provider returned error',
            code: 403
          }
        }.to_json
      )

      expect(provider.parse_error(response)).to eq('Provider returned error')
    end

    it 'joins a list of errors' do
      response = instance_double(
        Faraday::Response,
        body: [
          { 'error' => { 'message' => 'first' } },
          { 'error' => { 'message' => 'second' } }
        ]
      )

      expect(provider.parse_error(response)).to eq('first. second')
    end

    it 'passes a body it cannot interpret through' do
      expect(provider.parse_error(instance_double(Faraday::Response, body: 42))).to eq(42)
    end

    it 'is nil for an empty body' do
      expect(provider.parse_error(instance_double(Faraday::Response, body: nil))).to be_nil
      expect(provider.parse_error(instance_double(Faraday::Response, body: ''))).to be_nil
    end

    it 'ignores a raw payload that is not a JSON object' do
      response = instance_double(
        Faraday::Response,
        body: { 'error' => { 'message' => 'Provider returned error', 'metadata' => { 'raw' => 'not json' } } }
      )

      expect(provider.parse_error(response)).to eq('Provider returned error')
    end

    it 'handles a string error value' do
      response = instance_double(Faraday::Response, body: { error: 'upstream 502' }.to_json)

      expect(provider.parse_error(response)).to eq('upstream 502')
    end

    it 'joins messages from an array error value' do
      response = instance_double(
        Faraday::Response,
        body: { error: [{ message: 'first failure' }, 'second failure'] }.to_json
      )

      expect(provider.parse_error(response)).to eq('first failure. second failure')
    end

    it 'ignores non-object metadata' do
      response = instance_double(
        Faraday::Response,
        body: { error: { message: 'Provider returned error', metadata: 'raw text' } }.to_json
      )

      expect(provider.parse_error(response)).to eq('Provider returned error')
    end

    it 'handles a string error nested in metadata.raw' do
      response = instance_double(
        Faraday::Response,
        body: {
          error: {
            message: 'Provider returned error',
            metadata: { raw: { error: 'upstream detail' }.to_json }
          }
        }.to_json
      )

      expect(provider.parse_error(response)).to eq('Provider returned error - upstream detail')
    end
  end
end
