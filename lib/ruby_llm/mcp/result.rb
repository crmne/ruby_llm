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
        @text, @attachments = Content.read(data['content'])
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

      def inspect_attributes
        { text:, structured:, attachments: attachments.size.nonzero?, error: error? || nil }
      end
    end
  end
end
