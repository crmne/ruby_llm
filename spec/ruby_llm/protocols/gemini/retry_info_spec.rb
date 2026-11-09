# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Protocols::Gemini::RetryInfo do
  def response_with(body)
    Faraday::Env.from(status: 429, body:, response_headers: Faraday::Utils::Headers.new)
  end

  def rate_limited(*details)
    { 'error' => { 'code' => 429, 'status' => 'RESOURCE_EXHAUSTED', 'details' => details } }
  end

  def retry_info(delay)
    { '@type' => 'type.googleapis.com/google.rpc.RetryInfo', 'retryDelay' => delay }
  end

  [RubyLLM::Providers::Gemini, RubyLLM::Providers::VertexAI].each do |provider_class|
    describe "#{provider_class}#retry_delay" do
      subject(:provider) { provider_class.allocate }

      it 'reads whole seconds' do
        expect(provider.retry_delay(response_with(rate_limited(retry_info('30s'))))).to eq(30.0)
      end

      it 'reads fractional seconds' do
        expect(provider.retry_delay(response_with(rate_limited(retry_info('1.5s'))))).to eq(1.5)
      end

      it 'reads a body that has not been parsed' do
        expect(provider.retry_delay(response_with(rate_limited(retry_info('12s')).to_json))).to eq(12.0)
      end

      it 'reads the array a streaming error can arrive in' do
        expect(provider.retry_delay(response_with([rate_limited(retry_info('12s'))]))).to eq(12.0)
      end

      it 'finds RetryInfo among other details' do
        quota_failure = { '@type' => 'type.googleapis.com/google.rpc.QuotaFailure', 'violations' => [] }

        expect(provider.retry_delay(response_with(rate_limited(quota_failure, retry_info('7s'))))).to eq(7.0)
      end

      ['30', 's', '-5s', '1.s', '.5s', '1e3s', "30s\n", '1m', 30, nil, { 'seconds' => 30 }].each do |value|
        it "ignores a retryDelay of #{value.inspect}" do
          expect(provider.retry_delay(response_with(rate_limited(retry_info(value))))).to be_nil
        end
      end

      [
        nil,
        '',
        'Too many requests',
        { 'error' => 'quota' },
        { 'error' => { 'details' => 'quota' } },
        { 'error' => { 'details' => ['quota'] } },
        { 'error' => { 'code' => 429 } }
      ].each do |body|
        it "finds nothing in #{body.inspect}" do
          expect(provider.retry_delay(response_with(body))).to be_nil
        end
      end
    end
  end
end
