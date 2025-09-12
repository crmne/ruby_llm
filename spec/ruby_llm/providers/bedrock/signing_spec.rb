# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Bedrock::Signing do
  include_context 'with configured RubyLLM'

  let(:signer_class) { RubyLLM::Providers::Bedrock::Signing::Signer }

  describe RubyLLM::Providers::Bedrock::Signing::Signer do
    it 'signs a basic request with configured creds' do
      signer = signer_class.new(
        access_key_id: 'AKID',
        secret_access_key: 'SECRET',
        region: 'us-east-1',
        service: 'bedrock'
      )

      signature = signer.sign_request(
        http_method: :post,
        url: 'https://bedrock-runtime.us-east-1.amazonaws.com/model/anthropic.claude/converse',
        headers: { 'host' => 'bedrock-runtime.us-east-1.amazonaws.com' },
        body: '{}'
      )

      expect(signature.headers['authorization']).to include('AWS4-HMAC-SHA256')
      expect(signature.headers['x-amz-date']).to match(/\A\d{8}T\d{6}Z\z/)
      expect(signature.content_sha256).to eq(OpenSSL::Digest::SHA256.hexdigest('{}'))
    end

    it 'raises when region missing' do
      expect do
        signer_class.new(access_key_id: 'AKID', secret_access_key: 'SECRET', service: 'bedrock')
      end.to raise_error(RubyLLM::Providers::Bedrock::Signing::Errors::MissingRegionError)
    end

    it 'raises when credentials missing' do
      expect do
        signer_class.new(region: 'us-east-1', service: 'bedrock')
      end.to raise_error(RubyLLM::Providers::Bedrock::Signing::Errors::MissingCredentialsError)
    end
  end
end
