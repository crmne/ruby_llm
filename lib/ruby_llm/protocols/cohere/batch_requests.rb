# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Cohere
      module BatchRequests # :nodoc: all
        CHAT_FIELDS = %w[
          messages tools temperature p frequency_penalty presence_penalty reasoning thinking_budget
          return_prompt logprobs max_tokens max_input_tokens k seed
        ].freeze
        EMBEDDING_FIELDS = %w[texts images input_type inputs max_tokens output_dimension embedding_types
                              truncate].freeze
        private_constant :CHAT_FIELDS, :EMBEDDING_FIELDS

        def batch_dataset_type(requests)
          types = requests.map do |request|
            body = request.fetch(:payload)
            body.key?(:messages) || body.key?('messages') ? 'batch-chat-v2-input' : 'batch-embed-v2-input'
          end.uniq
          raise ArgumentError, 'Cohere batches cannot mix chat and embeddings' unless types.one?

          types.first
        end

        def render_batch_request(request, type:)
          body = JSON.parse(JSON.generate(batch_payload(request, except: :model)))
          if type == 'batch-embed-v2-input' && body['output_dimension']
            raise ArgumentError,
                  'Cohere batch datasets currently reject dimensions; omit dimensions to use the model default'
          end

          render_batch_chat(body) if type == 'batch-chat-v2-input'
          allowed = type == 'batch-chat-v2-input' ? CHAT_FIELDS : EMBEDDING_FIELDS
          unsupported = body.keys - allowed
          unless unsupported.empty?
            raise ArgumentError, "Cohere batches do not support these request options: #{unsupported.join(', ')}"
          end

          custom_id = request.fetch(:custom_id)
          custom_id = "#{custom_id}:array" if request[:text].is_a?(Array)
          { custom_id:, body: }
        end

        def render_batch_chat(body)
          if (thinking = body.delete('thinking'))
            body['reasoning'] = thinking['type'] != 'disabled'
            body['thinking_budget'] = thinking['token_budget'] if thinking['token_budget']
          end
          Array(body['messages']).each { |message| render_batch_message(message) }
          Array(body['tools']).each do |tool|
            function = tool.fetch('function')
            parameters = function['parameters']
            function['parameters'] = JSON.generate(parameters) unless parameters.is_a?(String)
          end
        end

        def render_batch_message(message)
          content = message['content']
          content = [{ 'type' => 'text', 'text' => content }] if content.is_a?(String)
          message['content'] = content&.map { |part| render_batch_content(part) }
        end

        def render_batch_content(part)
          unless %w[text thinking image_url].include?(part['type'])
            raise ArgumentError, "Cohere batches do not support #{part['type']} content"
          end

          part = part.dup
          part['image_url'] = part['image_url'].fetch('url') if part['image_url'].is_a?(Hash)
          part
        end
      end
    end
  end
end
