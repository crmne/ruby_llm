# frozen_string_literal: true

module RubyLLM
  # Normalizes and resolves the server tools a chat enabled with
  # Chat#with_server_tools. Protocols declare an alias table mapping portable
  # names such as +:web_search+ to their wire format; raw Hashes pass through
  # verbatim so new provider tools work without a gem update. :nodoc:
  module ServerTools
    # The result of resolving a chat's server tools against a protocol's
    # alias table: tool entries for the payload's tools slot, extra payload
    # fields to merge, and request headers to add.
    class Resolution
      attr_reader :tools, :payload, :headers

      def initialize
        @tools = []
        @payload = {}
        @headers = {}
      end

      def add(spec, options)
        entry = spec.is_a?(Proc) ? spec.call(options || {}) : merge_tool_options(spec, options)
        @tools << entry[:tool] if entry[:tool]
        merge_payload(entry[:payload]) if entry[:payload]
        merge_headers(entry[:headers]) if entry[:headers]
        self
      end

      def add_raw(hash)
        @tools << hash
        self
      end

      private

      def merge_tool_options(spec, options)
        return spec if options.nil? || options.empty?

        { tool: Utils.deep_merge(spec.fetch(:tool, spec), Utils.deep_symbolize_keys(options)) }
          .merge(spec.slice(:payload, :headers))
      end

      # Payload arrays accumulate: every entry contributes its own MCP server.
      def merge_payload(payload)
        @payload = @payload.merge(payload) do |_key, current, addition|
          next current | addition if current.is_a?(Array) && addition.is_a?(Array)
          next Utils.deep_merge(current, addition) if current.is_a?(Hash) && addition.is_a?(Hash)

          addition
        end
      end

      # Anthropic-style beta headers combine as comma-separated values.
      def merge_headers(headers)
        headers.each do |key, value|
          @headers[key] = [@headers[key], value].compact.uniq.join(',')
        end
      end
    end

    module_function

    # Normalizes with_server_tools arguments into entry hashes:
    # {name:, options:} for aliases and {raw:} for verbatim tool specs.
    def normalize(tools, tools_with_options)
      entries = tools.compact.map { |tool| normalize_positional(tool) }
      entries + tools_with_options.map { |name, options| { name: name.to_sym, options: options.to_h } }
    end

    def normalize_positional(tool)
      case tool
      when Symbol, String then { name: tool.to_sym, options: {} }
      when Hash then normalized_entry?(tool) ? tool : { raw: tool }
      else
        raise ArgumentError,
              "Server tools must be Symbols or Hashes, got #{tool.class}. " \
              'Pass :web_search for a portable alias or the provider\'s tool definition as a Hash.'
      end
    end

    # Entries that already went through normalize (an Agent's declared
    # server_tools, for example) pass through unchanged.
    def normalized_entry?(hash)
      hash.key?(:raw) ? hash.size == 1 : hash.size == 2 && hash.key?(:name) && hash.key?(:options)
    end

    # Resolves normalized entries against a protocol's alias table.
    def resolve(entries, aliases:, owner:)
      entries.each_with_object(Resolution.new) do |entry, resolution|
        if entry[:raw]
          resolution.add_raw(entry[:raw])
        else
          spec = aliases[entry[:name]]
          raise_unknown_alias(entry[:name], aliases, owner) unless spec
          resolution.add(spec, entry[:options])
        end
      end
    end

    def raise_unknown_alias(name, aliases, owner)
      known = aliases.keys.map { |key| ":#{key}" }.join(', ')
      raise UnsupportedServerToolError,
            "#{owner} has no server tool alias :#{name}. Known aliases: #{known}. " \
            'New or unlisted tools work by passing the provider\'s tool definition as a Hash.'
    end
  end
end
