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
        template.gsub(%r{\{([+#./;?&]?)([^{}]+)\}}) do
          expand_expression(Regexp.last_match(1), Regexp.last_match(2).split(','), variables)
        end
      end

      def self.expand_expression(operator, specs, variables) # :nodoc:
        separator, reserved = OPERATORS.fetch(operator)
        values = specs.filter_map { |spec| expand_variable(spec, operator, separator, reserved, variables) }
        return '' if values.empty?

        prefix = ['', '+'].include?(operator) ? '' : operator
        "#{prefix}#{values.join(separator)}"
      end

      # Expands one variable with its prefix (+:3+) and explode (+*+)
      # modifiers. Array values join with the operator's separator when
      # exploded and with commas otherwise.
      def self.expand_variable(spec, operator, separator, reserved, variables) # :nodoc:
        explode = spec.end_with?('*')
        name, length = spec.delete_suffix('*').split(':')
        return unless variables.key?(name)

        parts = Array(variables[name]).map { |part| encode(length ? part.to_s[0, length.to_i] : part.to_s, reserved) }
        named = NAMED_OPERATORS.include?(operator)
        return parts.map { |part| named ? "#{name}=#{part}" : part }.join(separator) if explode

        named ? "#{name}=#{parts.join(',')}" : parts.join(',')
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
