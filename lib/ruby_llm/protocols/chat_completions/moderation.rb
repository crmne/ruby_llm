# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # Moderation methods of the OpenAI API integration
      module Moderation
        module_function

        def moderation_url
          'moderations'
        end

        def render_moderation_payload(input, model:, with: [], provider_options: {})
          attachments = Attachment.wrap(with)

          {
            model: model,
            input: moderation_input(input, attachments)
          }.merge(provider_options)
        end

        def parse_moderation_response(response, model:)
          data = response.body
          raise Error.new(data.dig('error', 'message'), response:) if data.dig('error', 'message')

          RubyLLM::Moderation.new(
            id: data['id'],
            model: model,
            results: Array(data['results']).map { |result| RubyLLM::Moderation::Result.from_h(result) },
            raw: data
          )
        end

        def moderation_input(input, attachments)
          return input if attachments.empty?

          parts = []
          parts << Media.format_text(input) if input
          parts.concat(attachments.map { |attachment| format_moderation_attachment(attachment) })
          parts
        end

        def format_moderation_attachment(attachment)
          raise UnsupportedAttachmentError, attachment.mime_type unless attachment.image?

          Media.format_image(attachment)
        end
      end
    end
  end
end
