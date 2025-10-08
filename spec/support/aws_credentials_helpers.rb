# frozen_string_literal: true

# Mock AWS SDK credential classes for testing Bedrock credential provider support
# without coupling tests to the actual aws-sdk-core gem

module AWSCredentialsHelpers
  # Mock credentials object that mimics Aws::Credentials structure
  class MockCredentials
    attr_reader :access_key_id, :secret_access_key, :session_token

    def initialize(access_key_id:, secret_access_key:, session_token: nil)
      @access_key_id = access_key_id
      @secret_access_key = secret_access_key
      @session_token = session_token
    end
  end

  # Mock credentials provider that mimics AWS SDK credential provider interface
  class MockCredentialProvider
    attr_reader :credentials

    def initialize(credentials)
      @credentials = credentials
    end
  end

  # Invalid provider for testing validation (does not respond to :credentials)
  class InvalidProvider # rubocop:disable Lint/EmptyClass
    # Intentionally empty - used to test validation of provider interface
  end
end
