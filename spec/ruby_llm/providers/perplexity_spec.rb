# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Perplexity do
  let(:provider) do
    config = RubyLLM::Configuration.new
    config.perplexity_api_key = 'test'
    described_class.new(config)
  end

  describe '#parse_error' do
    it 'returns nil when the response body is nil' do
      response = instance_double(Faraday::Response, body: nil)

      expect(provider.parse_error(response)).to be_nil
    end
  end
end
