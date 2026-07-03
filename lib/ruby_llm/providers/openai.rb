# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenAI API integration.
    class OpenAI < Provider
      protocol :responses, Protocols::Responses, batches: Protocols::Responses::Batches
      protocol :chat_completions, Protocols::ChatCompletions, batches: Protocols::ChatCompletions::Batches
      files Protocols::OpenAI::Files

      def api_base
        @config.openai_api_base || 'https://api.openai.com/v1'
      end

      # Audio, realtime, and search-preview models only exist on Chat Completions.
      def protocol_for(model, **)
        model.id.match?(/audio|realtime|search-preview/) ? protocols[:chat_completions] : super
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.openai_api_key}",
          'OpenAI-Organization' => @config.openai_organization_id,
          'OpenAI-Project' => @config.openai_project_id
        }.compact
      end

      def find_batch(id)
        batch = super
        protocol = batch_protocol_for_endpoint(batch[:endpoint])

        protocol ? batch.merge(batch_protocol: protocol) : batch
      end

      def batch_results(id, batch_protocol: nil)
        super(id, batch_protocol: batch_protocol || batch_protocol_for_stored_batch(id))
      end

      class << self
        def capabilities
          OpenAI::Capabilities
        end

        def configuration_options
          %i[
            openai_api_key
            openai_api_base
            openai_organization_id
            openai_project_id
            openai_use_system_role
          ]
        end

        def configuration_requirements
          %i[openai_api_key]
        end
      end

      private

      def batch_protocol
        batch_protocol_for_name(:responses)
      end

      def batch_protocol_for(requests)
        names = requests.map { |request| batch_protocol_name_for(request.fetch(:params)) }.uniq
        return batch_protocol_for_name(names.first) if names.one?

        raise Error, 'openai batch requests must target one endpoint per submission'
      end

      def batch_protocol_name_for(params)
        return :responses if params.key?(:input) || params.key?('input')
        return :chat_completions if params.key?(:messages) || params.key?('messages')

        raise Error, 'openai batch requests only support chat or responses payloads'
      end

      def batch_protocol_for_stored_batch(id)
        data = @connection.get("batches/#{id}").body
        batch_protocol_for_endpoint(data['endpoint']) || batch_protocol
      end

      def batch_protocol_for_endpoint(endpoint)
        case endpoint.to_s.delete_prefix('/')
        when 'v1/responses', 'responses'
          batch_protocol_for_name(:responses)
        when 'v1/chat/completions', 'chat/completions'
          batch_protocol_for_name(:chat_completions)
        end
      end
    end
  end
end
