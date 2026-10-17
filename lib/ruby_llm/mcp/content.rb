# frozen_string_literal: true

module RubyLLM
  class MCP
    # Reads MCP content blocks into text and attachments. Tool results and
    # prompt messages share the format.
    module Content # :nodoc:
      module_function

      def read(blocks)
        texts, attachments = Array(blocks).filter_map { |block| part(block) }.partition { |part| part.is_a?(String) }
        [texts.join("\n\n"), attachments]
      end

      def part(block)
        case block['type']
        when 'text' then block['text']
        when 'image', 'audio' then attachment(block['data'], block['mimeType'], block['type'])
        when 'resource' then embedded(block['resource'] || {})
        when 'resource_link' then [block['title'] || block['name'], block['uri']].compact.join(': ')
        end
      end

      def embedded(resource)
        return resource['text'] if resource['text']
        return unless resource['blob']

        attachment(resource['blob'], resource['mimeType'], filename(resource['uri']))
      end

      def attachment(data, mime_type, name)
        file(Base64.decode64(data.to_s), mime_type, name)
      end

      def file(bytes, mime_type, name)
        name = name.to_s.empty? ? 'resource' : name.to_s
        extension = Marcel::TYPE_EXTS[mime_type]&.first
        name = "#{name}.#{extension}" unless name.include?('.') || extension.nil?
        Attachment.new(StringIO.new(bytes), filename: name)
      end

      def filename(uri)
        File.basename(URI(uri.to_s).path.to_s)
      rescue URI::InvalidURIError
        'resource'
      end
    end
  end
end
