# frozen_string_literal: true

module RubyLLM
  class MCP
    # A family of resources on an MCP server, named by a URI template.
    #
    #   template = files.resource_templates.first
    #   template.uri                        # => "file:///{path}"
    #   template.suggest(path: "app/mo")    # => ["app/models/"]
    #   files.resource(template.uri, path: "Gemfile")
    #
    class ResourceTemplate
      include Support::Inspectable

      OPERATORS = {
        '' => [',', false], '+' => [',', true], '#' => [',', true], '/' => ['/', false],
        '.' => ['.', false], ';' => [';', false], '?' => ['&', false], '&' => ['&', false]
      }.freeze
      NAMED_OPERATORS = %w[? & ;].freeze
      private_constant :OPERATORS, :NAMED_OPERATORS

      # The URI template, such as <tt>"file:///{path}"</tt>.
      attr_reader :uri

      # The template's name.
      attr_reader :name

      # A human-readable title, or +nil+.
      attr_reader :title

      # What the resources are, or +nil+.
      attr_reader :description

      # The MIME type of the resources, or +nil+.
      attr_reader :mime_type

      def self.expand(template, variables) # :nodoc:
        variables = variables.transform_keys(&:to_s)
        template.gsub(/\{([+#.\/;?&]?)([^}]+)\}/) do
          operator = Regexp.last_match(1)
          names = Regexp.last_match(2).split(',').select { |name| variables.key?(name) }
          expand_expression(operator, names, variables)
        end
      end

      def self.expand_expression(operator, names, variables) # :nodoc:
        return '' if names.empty?

        separator, reserved = OPERATORS.fetch(operator)
        values = names.map do |name|
          value = encode(variables[name].to_s, reserved)
          NAMED_OPERATORS.include?(operator) ? "#{name}=#{value}" : value
        end
        prefix = ['', '+'].include?(operator) ? '' : operator
        "#{prefix}#{values.join(separator)}"
      end

      def self.encode(value, reserved) # :nodoc:
        pattern = reserved ? %r{[^A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]} : /[^A-Za-z0-9\-._~]/
        value.gsub(pattern) { |char| char.bytes.map { |byte| format('%%%02X', byte) }.join }
      end

      def initialize(mcp, data) # :nodoc:
        @mcp = mcp
        @uri = data['uriTemplate']
        @name = data['name']
        @title = data['title']
        @description = data['description']
        @mime_type = data['mimeType']
      end

      # Asks the server to complete a variable's partial value. Pass one
      # variable to complete and any others that are already filled in.
      # Returns an Array of suggested values.
      #
      #   template.suggest(path: "app/mo")  # => ["app/models/"]
      #
      def suggest(**variables)
        @mcp.suggest({ type: 'ref/resource', uri: }, variables)
      end

      private

      def inspect_attributes
        { uri:, name: }
      end
    end
  end
end
