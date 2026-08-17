# frozen_string_literal: true

require 'json'
require 'securerandom'

module RubyLLM
  class StreamAccumulator # :nodoc:
    attr_reader :content, :model, :tool_calls

    def initialize
      @content = +''
      @citations = []
      @thinking_text = nil
      @thinking_signature = nil
      @tool_calls = {}
      @input_tokens = nil
      @output_tokens = nil
      @cache_read_tokens = nil
      @cache_write_tokens = nil
      @thinking_tokens = nil
      @server_tool_use = nil
      @reported_cost = nil
      @server_tool_calls = []
      @raw_content = nil
      @raw_reasoning = nil
      @finish_reason = nil
      @latest_tool_call_id = nil
      @tool_call_ids_by_index = {}
    end

    def add(chunk)
      RubyLLM.logger.debug { chunk.inspect } if RubyLLM.config.log_stream_debug
      @model = chunk.model if @model.to_s.empty?

      handle_chunk_content(chunk)
      accumulate_citations(chunk.citations)
      append_thinking_from_chunk(chunk)
      @server_tool_calls.concat(chunk.server_tool_calls)
      @raw_content = chunk.raw_content if chunk.raw_content
      @raw_reasoning = chunk.raw_reasoning if chunk.raw_reasoning
      @finish_reason = chunk.finish_reason if chunk.finish_reason
      count_tokens chunk
      RubyLLM.logger.debug { inspect } if RubyLLM.config.log_stream_debug
    end

    def to_message(response)
      Message.new(
        role: :assistant,
        content: content.empty? ? nil : content,
        citations: resolved_citations,
        thinking: Thinking.build(
          text: @thinking_text,
          signature: @thinking_signature
        ),
        tokens: Tokens.new(
          input: @input_tokens,
          output: @output_tokens,
          cache_read: @cache_read_tokens,
          cache_write: @cache_write_tokens,
          thinking: @thinking_tokens,
          server_tool_use: @server_tool_use,
          reported_cost: @reported_cost
        ),
        server_tool_calls: @server_tool_calls,
        raw_content: @raw_content,
        raw_reasoning: @raw_reasoning,
        finish_reason: @finish_reason,
        model: model,
        tool_calls: tool_calls_from_stream(response),
        raw: response
      )
    end

    private

    # Providers like Perplexity repeat the full citation list on every chunk.
    def accumulate_citations(new_citations)
      new_citations.each do |citation|
        @citations << citation unless @citations.include?(citation)
      end
    end

    def resolved_citations
      @citations.map { |citation| resolve_citation_text(citation) }
    end

    def resolve_citation_text(citation)
      return citation if citation.text || citation.start_index.nil? || citation.end_index.nil?

      span = content[citation.start_index...citation.end_index]
      span ? Citation.new(citation.to_h.merge(text: span)) : citation
    end

    def tool_calls_from_stream(response)
      tool_calls.transform_values do |tc|
        arguments = if tc.arguments.is_a?(String) && !tc.arguments.empty?
                      parse_tool_call_arguments(tc.arguments, response)
                    elsif tc.arguments.is_a?(String)
                      {}
                    else
                      tc.arguments
                    end

        ToolCall.new(
          id: tc.id,
          name: tc.name,
          arguments: arguments,
          thought_signature: tc.thought_signature
        )
      end
    end

    def parse_tool_call_arguments(arguments, response)
      JSON.parse(arguments)
    rescue JSON::ParserError => e
      raise ToolCallParseError.new(response: response, finish_reason: @finish_reason), cause: e
    end

    def accumulate_tool_calls(new_tool_calls)
      RubyLLM.logger.debug { "Accumulating tool calls: #{new_tool_calls}" } if RubyLLM.config.log_stream_debug
      new_tool_calls.each do |stream_key, tool_call|
        if tool_call.id
          start_tool_call(stream_key, tool_call)
        else
          append_tool_call_fragment(stream_key, tool_call)
        end
      end
    end

    def start_tool_call(stream_key, tool_call)
      tool_call_id = tool_call.id.empty? ? SecureRandom.uuid : tool_call.id
      tool_call_key = tool_call.id

      @tool_calls[tool_call_key] = ToolCall.new(
        id: tool_call_id,
        name: tool_call.name,
        arguments: initial_tool_call_arguments(tool_call),
        thought_signature: tool_call.thought_signature
      )
      @tool_call_ids_by_index[stream_key] = tool_call_key unless stream_key.nil?
      @latest_tool_call_id = tool_call_key
    end

    def initial_tool_call_arguments(tool_call)
      arguments = tool_call.arguments
      return +'' if arguments.nil? || (arguments.respond_to?(:empty?) && arguments.empty?)

      arguments
    end

    def append_tool_call_fragment(stream_key, tool_call)
      existing = find_tool_call(stream_key)
      return unless existing

      fragment = tool_call.arguments
      fragment = '' if fragment.nil?
      existing.arguments << fragment
      return unless tool_call.thought_signature && existing.thought_signature.nil?

      existing.thought_signature = tool_call.thought_signature
    end

    def find_tool_call(stream_key)
      return @tool_calls[@latest_tool_call_id] if stream_key.nil?

      @tool_calls[@tool_call_ids_by_index[stream_key]] || @tool_calls[stream_key]
    end

    def count_tokens(chunk)
      tokens = chunk.tokens
      @input_tokens = tokens.input if tokens.input
      @output_tokens = tokens.output if tokens.output
      @cache_read_tokens = tokens.cache_read if tokens.cache_read
      @cache_write_tokens = tokens.cache_write if tokens.cache_write
      @thinking_tokens = tokens.thinking if tokens.thinking
      @server_tool_use = tokens.server_tool_use if tokens.server_tool_use
      @reported_cost = tokens.reported_cost if tokens.reported_cost
    end

    def handle_chunk_content(chunk)
      return accumulate_tool_calls(chunk.tool_calls) if chunk.tool_call?

      content_text = chunk.content || ''
      @content << (content_text.is_a?(String) ? content_text : content_text.to_s)
    end

    def append_thinking_from_chunk(chunk)
      thinking = chunk.thinking
      return unless thinking

      unless thinking.text.nil?
        @thinking_text ||= +''
        @thinking_text << thinking.text.to_s
      end
      @thinking_signature ||= thinking.signature # rubocop:disable Naming/MemoizedInstanceVariableName
    end
  end
end
