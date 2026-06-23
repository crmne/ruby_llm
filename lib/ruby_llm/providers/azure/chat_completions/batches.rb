# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      class ChatCompletions
        # Azure OpenAI exposes the OpenAI file-backed Batch API under /openai/v1,
        # but batch endpoint names omit the /v1 prefix inside the create body.
        module Batches
          include Protocols::ChatCompletions::Batches

          private

          def batch_endpoint
            super.delete_prefix('/v1')
          end

          def batch_create_url
            "#{@provider.azure_openai_v1_base}/batches"
          end

          def batch_url(id)
            "#{@provider.azure_openai_v1_base}/batches/#{id}"
          end
        end
      end
    end
  end
end
