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
      # Reset the authorizer to force re-initialization
      provider.instance_variable_set(:@authorizer, nil)
    end

    it 'passes scope as a positional argument to get_application_default' do
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

      # Trigger the authorizer initialization by calling headers
      provider.headers
    end

    it 'does not pass scope as a keyword argument' do
      # Ensure we're not passing a Hash like {scope: [...]} which would cause
      # TypeError on GCE: "Expected Array or String, got Hash"
      expect(Google::Auth).to receive(:get_application_default) do |arg|
        expect(arg).to be_an(Array)
        expect(arg).not_to be_a(Hash)
        mock_credentials
      end

      provider.headers
    end
  end
end
