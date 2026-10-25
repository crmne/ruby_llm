# frozen_string_literal: true

require 'json'
require 'securerandom'

module RubyLLM
  class Protocol
    class StreamAccumulator # :nodoc:
      attr_reader :content, :model, :tool_calls

      def initialize
        @content = +''
        @attachments = []
        @citations = []
        @citation_keys = {}
        @thinking_text = nil
        @thinking_signature = nil
        @tool_calls = {}
        @tokens = Tokens.new
        @server_tool_calls = []
        @raw_content = nil
        @raw_reasoning = nil
        @finish_reason = nil
        @content_filters = {}
        @latest_provider_call_id = nil
        @provider_call_ids_by_index = {}
      end

      def add(chunk)
        RubyLLM.logger.debug { chunk.inspect } if RubyLLM.config.log_stream_debug
        @model = chunk.model if @model.to_s.empty?

        handle_chunk_content(chunk)
        @attachments.concat(chunk.attachments)
        accumulate_citations(chunk.citations)
        append_thinking_from_chunk(chunk)
        accumulate_server_tool_calls(chunk.server_tool_calls)
        @raw_content = chunk.raw_content if chunk.raw_content
        @raw_reasoning = chunk.raw_reasoning if chunk.raw_reasoning
        @phase = chunk.phase if chunk.phase
        @finish_reason = chunk.finish_reason if chunk.finish_reason
        accumulate_content_filters(chunk.content_filters)
        count_tokens chunk
        RubyLLM.logger.debug { inspect } if RubyLLM.config.log_stream_debug
      end

      def to_message(response)
        Message.new(
          role: :assistant,
          content: content.empty? ? nil : content,
          attachments: @attachments,
          citations: resolved_citations,
          thinking: Thinking.build(
            text: @thinking_text,
            signature: @thinking_signature
          ),
          tokens: @tokens,
          server_tool_calls: @server_tool_calls,
          raw_content: @raw_content,
          raw_reasoning: @raw_reasoning,
          phase: @phase,
          finish_reason: @finish_reason,
          content_filters: @content_filters.values,
          model: model,
          tool_calls: tool_calls_from_stream(response),
          raw: response
        )
      end

      private

      # A stream can judge the same category again as it goes; a verdict
      # that filtered stays, and otherwise the latest one does.
      def accumulate_content_filters(filters)
        filters.each do |filter|
          key = [filter.source, filter.category]
          @content_filters[key] = filter unless @content_filters[key]&.filtered?
        end
      end

      # Providers like Perplexity repeat the full citation list on every chunk.
      def accumulate_citations(new_citations)
        new_citations.each do |citation|
          key = citation.to_h
          next if @citation_keys.key?(key)

          @citation_keys[key] = true
          @citations << citation
        end
      end

      def accumulate_server_tool_calls(calls)
        calls.each do |call|
          index = @server_tool_calls.index do |existing|
            call.id && existing.id == call.id && existing.type == call.type
          end
          if index
            @server_tool_calls[index] = call
          else
            @server_tool_calls << call
          end
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
                        raise ToolCallTruncatedError.new(response:) if cut_off?(tc)

                        {}
                      else
                        tc.arguments
                      end

          ToolCall.new(
            id: tc.id,
            provider_call_id: tc.provider_call_id,
            name: tc.name,
            arguments: arguments,
            thought_signature: tc.thought_signature,
            remote: tc.remote?
          )
        end
      end

      def parse_tool_call_arguments(arguments, response)
        Hash(JSON.parse(arguments))
      rescue JSON::ParserError, TypeError => e
        raise ToolCallParseError.for(response:, finish_reason: @finish_reason), cause: e
      end

      def cut_off?(tool_call)
        @finish_reason == :max_tokens && tool_calls.values.last.equal?(tool_call)
      end

      def accumulate_tool_calls(new_tool_calls)
        RubyLLM.logger.debug { "Accumulating tool calls: #{new_tool_calls}" } if RubyLLM.config.log_stream_debug
        new_tool_calls.each do |stream_key, tool_call|
          if continues_tool_call?(stream_key, tool_call)
            append_tool_call_fragment(stream_key, tool_call)
          else
            if tool_call.provider_call_id.to_s.empty?
              tool_call = ToolCall.new(**tool_call.to_h, provider_call_id: SecureRandom.uuid)
              new_tool_calls[stream_key] = tool_call
            end
            start_tool_call(stream_key, tool_call)
          end
        end
      end

      def continues_tool_call?(stream_key, tool_call)
        case tool_call.provider_call_id
        when nil then tool_call.name.to_s.empty? || !find_tool_call(stream_key).nil?
        when '' then tool_call.name.to_s.empty?
        else
          !tool_call.arguments.is_a?(Hash) && @provider_call_ids_by_index[stream_key] == tool_call.provider_call_id
        end
      end

      def start_tool_call(stream_key, tool_call)
        provider_call_id = tool_call.provider_call_id
        if @tool_calls.key?(provider_call_id) && @provider_call_ids_by_index[stream_key] != provider_call_id
          raise Error, "Duplicate tool call ID in one response: #{provider_call_id.inspect}"
        end

        @tool_calls[provider_call_id] = ToolCall.new(
          id: tool_call.id,
          provider_call_id:,
          name: tool_call.name,
          arguments: initial_tool_call_arguments(tool_call),
          thought_signature: tool_call.thought_signature,
          remote: tool_call.remote?
        )
        @provider_call_ids_by_index[stream_key] = provider_call_id unless stream_key.nil?
        @latest_provider_call_id = provider_call_id
      end

      def initial_tool_call_arguments(tool_call)
        arguments = tool_call.arguments
        return +'' if arguments.nil? || (arguments.respond_to?(:empty?) && arguments.empty?)

        arguments.dup
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
        return @tool_calls[@latest_provider_call_id] if stream_key.nil?

        @tool_calls[@provider_call_ids_by_index[stream_key]] || @tool_calls[stream_key]
      end

      def count_tokens(chunk)
        @tokens = @tokens.merge(chunk.tokens)
      end

      def handle_chunk_content(chunk)
        accumulate_tool_calls(chunk.tool_calls) if chunk.tool_call?

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
end
