# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ElevenLabs
      class Flows
        module Media # :nodoc: all
          def render_media_reference(attachment)
            unless attachment.image? || attachment.audio? || attachment.video?
              raise UnsupportedAttachmentError, attachment.mime_type
            end

            if attachment.provider_file?
              unless attachment.source.provider.to_s == @provider.slug
                raise ArgumentError, 'ElevenLabs media references require an asset from the same provider'
              end

              { type: 'asset', asset_id: attachment.provider_file_id }
            else
              { type: 'inline_base64', content_base64: attachment.encoded, mime_type: attachment.mime_type }
            end
          end

          def parse_generation_status(body)
            case body['status']
            when 'pending', 'generating'
              { status: :pending, raw: body }
            when 'completed'
              raise Error, 'ElevenLabs completed a generation without an output URL' unless body['content_url']

              { status: :completed, raw: body }
            when 'failed'
              { status: :failed, raw: body, error: body['error_message'] || body['failure_reason'] }
            else
              raise Error, "ElevenLabs returned an unknown generation status: #{body['status'].inspect}"
            end
          end
        end
      end
    end
  end
end
