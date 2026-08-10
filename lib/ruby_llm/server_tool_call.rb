# frozen_string_literal: true

module RubyLLM
  # A ServerToolCall records one provider-executed tool step in an assistant
  # response: a web search the model ran, a code execution, or the results
  # block a provider returned for one. They appear on
  # Message#server_tool_calls when a chat enables tools with
  # Chat#with_server_tools.
  #
  #   response = chat.with_server_tools(:web_search).ask "What changed in Ruby 3.5?"
  #   response.server_tool_calls.map(&:type) # => ["server_tool_use", "web_search_tool_result"]
  #
  # RubyLLM does not model each tool's result schema. #raw always holds the
  # provider's block exactly as received, and is what RubyLLM replays to the
  # provider in subsequent turns when the wire format requires it.
  class ServerToolCall
    include Inspectable

    # The provider's block or item type, such as <tt>"server_tool_use"</tt>,
    # <tt>"web_search_tool_result"</tt>, or <tt>"web_search_call"</tt>.
    attr_reader :type

    # The tool name when the provider reports one, such as
    # <tt>"web_search"</tt>, or +nil+.
    attr_reader :name

    # The provider's identifier for the call, or +nil+.
    attr_reader :id

    # The input the model gave the tool (a query, code to run), in the
    # provider's shape, or +nil+.
    attr_reader :input

    # The tool's output in the provider's shape, or +nil+ for blocks that
    # only record the invocation.
    attr_reader :result

    # The complete provider block as received, used verbatim when the
    # conversation is sent back to the provider.
    attr_reader :raw

    def self.from_h(data) # :nodoc:
      data = Utils.deep_symbolize_keys(data)
      new(type: data[:type], name: data[:name], id: data[:id], input: data[:input],
          result: data[:result], raw: data[:raw])
    end

    def initialize(type:, raw:, name: nil, id: nil, input: nil, result: nil) # :nodoc:
      @type = type
      @name = name
      @id = id
      @input = input
      @result = result
      @raw = raw
    end

    # Returns the call's attributes as a Hash, omitting +nil+ values.
    def to_h
      {
        type: type,
        name: name,
        id: id,
        input: input,
        result: result,
        raw: raw
      }.compact
    end

    def inspect_attributes # :nodoc:
      { type: type, name: name, id: id, input: input }
    end
  end
end
