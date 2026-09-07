# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Mistral
      class Conversations
        module Images # :nodoc:
          def images_url(**)
            'conversations'
          end

          def render_image_payload(prompt, model:, size:, count: nil, with: nil, mask: nil, provider_options: {})
            if size || (count && count != 1)
              raise ArgumentError,
                    'Mistral image generation does not accept size or count options'
            end
            raise UnsupportedAttachmentError, 'image editing' if with || mask

            payload = { model: model, store: false, inputs: prompt, tools: [{ type: 'image_generation' }] }
            Support::Utils.deep_merge(payload, provider_options)
          end

          def parse_image_response(response, model:)
            parse_image_responses(response, model:).first
          end

          def parse_image_responses(response, model:)
            data = response.body
            attachments = parse_conversation_content(data.fetch('outputs'))[:attachments]
            raise Error.new('Mistral returned no generated image', response:) if attachments.empty?

            usage = parse_conversation_usage(data['usage'] || {}).transform_keys(&:to_s)
            attachments.each_with_index.map do |attachment, index|
              bytes = @provider.download_file(attachment.provider_file_id)
              Image.new(data: Base64.strict_encode64(bytes), mime_type: RubyLLM::Files::MimeType.for(StringIO.new(bytes)),
                        model: model, usage: index.zero? ? usage : {})
            end
          end
        end
      end
    end
  end
end
