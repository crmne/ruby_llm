# frozen_string_literal: true

module RubyLLM
  class MCP
    # The result of calling an MCP tool. Text, files, and structured data
    # each have their own reader.
    #
    #   result = linear.list_issues(query: "bug")
    #   result.text        # => "Found 3 issues..."
    #   result.structured  # => { "issues" => [...] }
    #   result.attachments # => [#<RubyLLM::Attachment ...>]
    #
    class Result
      include Support::Inspectable

      # The text of the result, with text blocks joined by blank lines.
      attr_reader :text

      # Images, audio, and embedded files, as Attachment objects.
      attr_reader :attachments

      # The structured content, parsed from JSON, or +nil+.
      attr_reader :structured

      def initialize(data) # :nodoc:
        @data = data
        @structured = data['structuredContent']
        texts, @attachments = data.fetch('content', []).filter_map { |block| read(block) }
                                  .partition { |part| part.is_a?(String) }
        @text = texts.join("\n\n")
      end

      # Returns whether the tool reported a failure.
      def error?
        @data['isError'] == true
      end

      # Returns what a chat sends to the model: the text, or the structured
      # content as JSON when there is no text, followed by any attachments.
      def content
        body = text.empty? && structured ? JSON.generate(structured) : text
        attachments.empty? ? body : [body, *attachments]
      end

      # Returns the result as the server sent it.
      def to_h
        @data
      end

      private

      def read(block)
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

        attachment(resource['blob'], resource['mimeType'], File.basename(URI(resource['uri'].to_s).path.to_s))
      end

      def attachment(data, mime_type, name)
        extension = Marcel::TYPE_EXTS[mime_type]&.first
        filename = name.to_s.include?('.') || extension.nil? ? name.to_s : "#{name}.#{extension}"
        Attachment.new(StringIO.new(Base64.decode64(data.to_s)), filename:)
      end

      def inspect_attributes
        { text:, structured:, attachments: attachments.size.nonzero?, error: error? || nil }
      end
    end
  end
end
