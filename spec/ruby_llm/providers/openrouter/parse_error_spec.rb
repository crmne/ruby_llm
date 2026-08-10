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
  end
end
