# frozen_string_literal: true

module RubyLLM
  class MCP
    # A resource on an MCP server: a file, a record, or any data the server
    # names with a URI. Pass one to a chat like any attachment, or save it.
    #
    #   readme = files.resource("file:///project/README.md")
    #   readme.content                 # => "# My Project..."
    #   readme.save("README.md")
    #   chat.ask "Summarize this", with: readme
    #
    # Resources from MCP#resources are read from the server the first time
    # their content is needed.
    class Resource
      include Support::Inspectable

      # The URI that identifies the resource on its server.
      attr_reader :uri

      # The resource's name.
      attr_reader :name

      # A human-readable title, or +nil+.
      attr_reader :title

      # What the resource is, or +nil+.
      attr_reader :description

      # The MIME type the server reports, or +nil+.
      attr_reader :mime_type

      def initialize(mcp, data) # :nodoc:
        @mcp = mcp
        @uri = data['uri']
        @name = data['name'] || Content.filename(uri)
        @title = data['title']
        @description = data['description']
        @mime_type = data['mimeType']
        @data = data
      end

      # Returns the resource's content: text for text resources, bytes for
      # binary ones.
      def content
        @content ||= if @data.key?('text') then @data['text']
                     elsif @data.key?('blob') then Base64.decode64(@data['blob'])
                     else @mcp.resource(uri).content
                     end
      end

      # Returns the content as a String of bytes.
      def to_blob
        content.b
      end

      # Writes the content to +path+, expanding it first. Returns +path+.
      def save(path)
        File.binwrite(File.expand_path(path), to_blob)
        path
      end

      # Returns the resource as an Attachment, which is how chats take it
      # through +with:+.
      def to_attachment
        filename = Content.filename(uri)
        Attachment.new(StringIO.new(to_blob), filename: filename.empty? ? name : filename)
      end

      private

      def inspect_attributes
        { uri:, name:, mime_type: }
      end
    end
  end
end
