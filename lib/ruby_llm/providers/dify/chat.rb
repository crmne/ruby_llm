# frozen_string_literal: true

module RubyLLM
  module Providers
    module Dify
      # Chat methods of the Dify API integration
      module Chat
        def completion_url
          'v1/chat-messages'
        end

        def upload_document(document_path, original_filename = nil)
          pn = Pathname.new(document_path)
          mime_type = RubyLLM::MimeType.for pn
          original_filename ||= document_path.is_a?(String) ? pn.basename : (document_path.is_a?(Tempfile) ? File.basename(document_path) : document_path.original_filename)
          payload = {
            file: Faraday::Multipart::FilePart.new(document_path, mime_type, original_filename),
            user: 'dify-user'
          }
          connection({}).upload('v1/files/upload', payload)
        end

        module_function

        def render_payload(messages, tools:, temperature:, model:, stream: false) # rubocop:disable Lint/UnusedMethodArgument
          # binding.irb
          only_message_content = messages[0].content # only support first message now
          payload = {
            inputs: {},
            query: only_message_content.is_a?(Content) ? only_message_content.text : only_message_content,
            response_mode: (stream ? 'streaming' : 'blocking'),
            conversation_id: '',
            user: 'dify-user',
            files: format_files(only_message_content)
          }
          payload
        end

        def parse_completion_response(response)
          data = response.body

          Message.new(
            role: :assistant,
            content: data['answer'],
            tool_calls: nil,
            input_tokens: data.dig('metadata', 'usage', 'prompt_tokens'),
            output_tokens: data.dig('metadata', 'usage', 'completion_tokens'),
            model_id: 'dify-model'
          )
        end
      end
    end
  end
end
