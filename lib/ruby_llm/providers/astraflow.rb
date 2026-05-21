# frozen_string_literal: true

module RubyLLM
  module Providers
    # Astraflow API integration.
    # Astraflow (by UCloud) is an OpenAI-compatible platform supporting 200+ models.
    # Global endpoint: https://api-us-ca.umodelverse.ai/v1  (env var: ASTRAFLOW_API_KEY)
    # China endpoint:  https://api.modelverse.cn/v1         (env var: ASTRAFLOW_CN_API_KEY)
    class Astraflow < OpenAI
      include Astraflow::Chat
      include Astraflow::Models

      def api_base
        if @config.astraflow_cn_api_key && !@config.astraflow_cn_api_key.to_s.empty?
          @config.astraflow_api_base || 'https://api.modelverse.cn/v1'
        else
          @config.astraflow_api_base || 'https://api-us-ca.umodelverse.ai/v1'
        end
      end

      def headers
        api_key = if @config.astraflow_cn_api_key && !@config.astraflow_cn_api_key.to_s.empty?
                    @config.astraflow_cn_api_key
                  else
                    @config.astraflow_api_key
                  end
        {
          'Authorization' => "Bearer #{api_key}",
          'Content-Type' => 'application/json'
        }
      end

      class << self
        def configuration_options
          %i[astraflow_api_key astraflow_cn_api_key astraflow_api_base]
        end

        def configuration_requirements
          # At least one key must be set; validated at connection time via headers.
          []
        end
      end
    end
  end
end
