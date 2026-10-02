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
    #   result.meta        # => { "com.linear/request_id" => "..." }
    #
    # In a chat, the result of a tool with a UI stays on its tool result
    # message as Message#mcp_result, so your app can render the UI again.
    class Result
      include Support::Inspectable

      # The text of the result, with text blocks joined by blank lines.
      attr_reader :text

      # Images, audio, and embedded files, as Attachment objects.
      attr_reader :attachments

      # The structured content, parsed from JSON, or +nil+.
      attr_reader :structured

      # The result's +_meta+ as the server sent it: a Hash with String
      # keys, empty when there is none.
      attr_reader :meta

      # The URI of the UI that renders the result, from its tool's
      # MCP::Tool#ui_uri, or +nil+ for a tool without one.
      attr_reader :ui_uri

      def self.load(data) # :nodoc:
        new(data['result'], data['ui_uri'])
      end

      def initialize(data, ui_uri = nil) # :nodoc:
        @data = data
        @ui_uri = ui_uri
        @structured = data['structuredContent']
        @meta = data['_meta'] || {}
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

      def dump # :nodoc:
        { 'ui_uri' => ui_uri, 'result' => to_h }
      end

      private

      def inspect_attributes
        { text:, structured:, attachments: attachments.size.nonzero?, error: error? || nil, ui_uri: }
      end
    end
  end
end
