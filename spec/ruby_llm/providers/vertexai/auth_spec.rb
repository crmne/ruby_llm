# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::VertexAI do
  include_context 'with configured RubyLLM'

  describe '#initialize_authorizer' do
    let(:provider) do
      described_class.new(RubyLLM.config)
    end

    let(:mock_credentials) do
      instance_double(Google::Auth::GCECredentials, apply: { 'Authorization' => 'Bearer test-token' })
    end

    before do
      provider.instance_variable_set(:@authorizer, nil)
    end

    it 'passes scope as a positional Array argument to get_application_default' do
      # This test verifies the fix for the TypeError that occurs when running on GCE.
      # Google::Auth.get_application_default expects scope as a positional argument,
      # not a keyword argument. Passing `scope: [...]` causes Ruby to interpret it
      # as a Hash, which triggers: TypeError: Expected Array or String, got Hash
      expected_scopes = [
        'https://www.googleapis.com/auth/cloud-platform',
        'https://www.googleapis.com/auth/generative-language.retriever'
      ]

      expect(Google::Auth).to receive(:get_application_default)
        .with(expected_scopes)
        .and_return(mock_credentials)

      provider.headers
    end
  end
end
