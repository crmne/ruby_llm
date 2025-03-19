# frozen_string_literal: true

module RubyLLM
  module Providers
    class Bedrock
      # Configuration for AWS Bedrock provider
      class Config
        attr_reader :access_key_id, :secret_access_key, :session_token, :region, :connection

        def initialize(access_key_id:, secret_access_key:, region:, session_token: nil)
          @access_key_id = access_key_id
          @secret_access_key = secret_access_key
          @session_token = session_token
          @region = region
          @connection = build_connection
        end

        private

        def build_connection
          Faraday.new(url: "https://bedrock-runtime.#{region}.amazonaws.com") do |f|
            f.request :json
            f.response :json, content_type: /\bjson$/
            f.adapter Faraday.default_adapter
          end
        end
      end
    end
  end
end 