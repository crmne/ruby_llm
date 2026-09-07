# frozen_string_literal: true

require 'stringio'

module RubyLLM
  module Protocols
    class Interactions
      module Content # :nodoc:
        CITATION_TYPES = %w[url_citation file_citation place_citation].freeze

        module_function

        def render_interaction_content(text, attachments)
          parts = text.nil? ? [] : [{ type: 'text', text: text.to_s }]
          parts + attachments.map { |attachment| render_interaction_attachment(attachment) }
        end

        def render_interaction_attachment(attachment)
          return { type: 'text', text: attachment.content } if attachment.text?

          type = interaction_attachment_type(attachment)
          raise ArgumentError, "Gemini Interactions does not support #{attachment.mime_type} input" unless type

          part = { type: type, mime_type: attachment.mime_type }
          if attachment.provider_file?
            part.merge(uri: attachment.provider_file_uri)
          elsif attachment.url?
            part.merge(uri: attachment.source.to_s)
          else
            part.merge(data: attachment.encoded)
          end
        end

        def interaction_attachment_type(attachment)
          return 'image' if attachment.image?
          return 'audio' if attachment.audio?
          return 'video' if attachment.video?

          'document' if attachment.pdf?
        end

        def parse_interaction_content(steps)
          result = { text: +'', attachments: [], citations: [] }
          steps.select { |step| step['type'] == 'model_output' }.each do |step|
            Array(step['content']).each { |part| parse_interaction_part(part, result) }
          end
          result
        end

        def parse_interaction_part(part, result)
          if part['type'] == 'text'
            text = part['text'].to_s
            result[:citations].concat(parse_interaction_citations(part, result[:text].length))
            result[:text] << text
          elsif part['data'] || part['uri']
            source = part['uri'] || StringIO.new(Base64.decode64(part['data']))
            result[:attachments] << Attachment.new(source, config: @config)
          end
        end

        def parse_interaction_citations(part, offset)
          Array(part['annotations']).filter_map do |annotation|
            next unless CITATION_TYPES.include?(annotation['type'])

            Citation.new(**interaction_citation_source(annotation),
                         **interaction_citation_span(part['text'].to_s, annotation, offset))
          end
        end

        def interaction_citation_source(annotation)
          { url: annotation['url'] || annotation['document_uri'],
            title: annotation['title'] || annotation['file_name'] || annotation['name'],
            source_id: annotation['media_id'] || annotation['place_id'], cited_text: annotation['source'],
            start_page: annotation['page_number'], end_page: annotation['page_number'] }
        end

        def interaction_citation_span(text, annotation, offset)
          start_index = interaction_citation_index(text, annotation['start_index'])
          end_index = interaction_citation_index(text, annotation['end_index'])
          { start_index: start_index && (offset + start_index), end_index: end_index && (offset + end_index),
            text: start_index && end_index && text[start_index...end_index] }
        end

        def interaction_citation_index(text, bytes)
          text.byteslice(0, bytes)&.length unless bytes.nil?
        end
      end
    end
  end
end
