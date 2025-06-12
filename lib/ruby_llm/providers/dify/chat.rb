# frozen_string_literal: true

module RubyLLM
  module Providers
    module Dify
      # Chat methods of the Dify API integration
      module Chat
        def completion_url
          'v1/chat-messages'
        end

        def upload_document(document_path, original_filename = nil, dify_user = nil)
          pn = Pathname.new(document_path)
          mime_type = RubyLLM::MimeType.for pn
          original_filename ||= document_path.is_a?(String) ? pn.basename : (document_path.is_a?(Tempfile) ? File.basename(document_path) : document_path.original_filename)
          payload = {
            file: Faraday::Multipart::FilePart.new(document_path, mime_type, original_filename),
            user: dify_user || 'dify-user'
          }
          connection({}).upload('v1/files/upload', payload)
        end

        module_function

        def render_payload(messages, tools:, temperature:, model:, config:, stream: false) # rubocop:disable Lint/UnusedMethodArgument
          current_message = messages[-1]
          current_message_content = current_message.content # dify using conversation_id to trace message history

          # Find the latest non-nil conversation_id from all messages
          latest_conversation_id = messages.reverse.find { |msg| msg.conversation_id }&.conversation_id

          {
            inputs: {},
            query: current_message_content.is_a?(Content) ? current_message_content.text : current_message_content,
            response_mode: (stream ? 'streaming' : 'blocking'),
            conversation_id: latest_conversation_id,
            user: config.dify_user || 'dify-user',
            files: format_files(current_message_content)
          }
        end

        def parse_completion_response(response)
          data = response.body

          Message.new(
            role: :assistant,
            content: data['answer'],
            tool_calls: nil,
            input_tokens: data.dig('metadata', 'usage', 'prompt_tokens'),
            output_tokens: data.dig('metadata', 'usage', 'completion_tokens'),
            conversation_id: data['conversation_id'],
            model_id: 'dify-model'
          )
        end
      end
    end
  end
end
