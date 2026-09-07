# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Mistral
      module Content # :nodoc:
        module_function

        def parse_conversation_content(output)
          result = { text: +'', thinking: +'', attachments: [], citations: [] }
          output.select { |entry| entry['type'] == 'message.output' }.each do |entry|
            parse_conversation_parts(entry['content'], result)
          end
          result[:thinking] = nil if result[:thinking].empty?
          result
        end

        def parse_conversation_parts(content, result)
          return result[:text] << content if content.is_a?(String)

          Array(content).compact.each do |part|
            case part['type']
            when 'text' then result[:text] << part['text'].to_s
            when 'thinking' then result[:thinking] << Array(part['thinking']).filter_map { |item| item['text'] }.join
            when 'tool_reference' then result[:citations] << parse_conversation_citation(part, result[:text].length)
            when 'tool_file' then result[:attachments] << parse_conversation_file(part)
            when 'image_url'
              url = part['image_url'].is_a?(Hash) ? part['image_url']['url'] : part['image_url']
              result[:attachments] << Attachment.new(url, config: @config)
            end
          end
        end

        def parse_conversation_citation(part, offset)
          Citation.new(url: part['url'], title: part['title'], cited_text: part['description'],
                       start_index: offset, end_index: offset)
        end

        def parse_conversation_file(part)
          format = part['file_type'].to_s
          mime_type = format.include?('/') ? format : RubyLLM::Files::MimeType.for(name: "file.#{format}")
          file = UploadedFile.new(id: part.fetch('file_id'), provider: @provider.slug,
                                  filename: part['file_name'], mime_type: mime_type, downloadable: true, metadata: part)
          Attachment.new(file, config: @config)
        end
      end
    end
  end
end
