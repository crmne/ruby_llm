# frozen_string_literal: true

module RubyLLM
  # Assembles streaming responses from LLMs into complete messages.
  class StreamAccumulator
    attr_reader :content, :model_id, :tool_calls

    def initialize
      @content = +''
      @thinking_text = +''
      @thinking_signature = nil
      @tool_calls = {}
      @input_tokens = nil
      @output_tokens = nil
      @cached_tokens = nil
      @cache_creation_tokens = nil
      @thinking_tokens = nil
      @inside_think_tag = false
      @pending_think_tag = +''
      @latest_tool_call_id = nil
    end

    def add(chunk)
      RubyLLM.logger.debug chunk.inspect if RubyLLM.config.log_stream_debug
      @model_id ||= chunk.model_id

      handle_chunk_content(chunk)
      append_thinking_from_chunk(chunk)
      count_tokens chunk
      RubyLLM.logger.debug inspect if RubyLLM.config.log_stream_debug
    end

    def to_message(response)
      Message.new(
        role: :assistant,
        content: content.empty? ? nil : content,
        thinking: Thinking.build(
          text: @thinking_text.empty? ? nil : @thinking_text,
          signature: @thinking_signature
        ),
        tokens: Tokens.build(
          input: @input_tokens,
          output: @output_tokens,
          cached: @cached_tokens,
          cache_creation: @cache_creation_tokens,
          thinking: @thinking_tokens
        ),
        model_id: model_id,
        tool_calls: tool_calls_from_stream,
        raw: response
      )
    end

    private

    def tool_calls_from_stream
      tool_calls.transform_values do |tc|
        arguments = if tc.arguments.is_a?(String) && !tc.arguments.empty?
                      JSON.parse(tc.arguments)
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

    def accumulate_tool_calls(new_tool_calls) # rubocop:disable Metrics/PerceivedComplexity
      RubyLLM.logger.debug "Accumulating tool calls: #{new_tool_calls}" if RubyLLM.config.log_stream_debug
      new_tool_calls.each_value do |tool_call|
        if tool_call.id
          tool_call_id = tool_call.id.empty? ? SecureRandom.uuid : tool_call.id
          tool_call_arguments = tool_call.arguments
          if tool_call_arguments.nil? || (tool_call_arguments.respond_to?(:empty?) && tool_call_arguments.empty?)
            tool_call_arguments = +''
          end
          @tool_calls[tool_call.id] = ToolCall.new(
            id: tool_call_id,
            name: tool_call.name,
            arguments: tool_call_arguments,
            thought_signature: tool_call.thought_signature
          )
          @latest_tool_call_id = tool_call.id
        else
          existing = @tool_calls[@latest_tool_call_id]
          if existing
            fragment = tool_call.arguments
            fragment = '' if fragment.nil?
            existing.arguments << fragment
            if tool_call.thought_signature && existing.thought_signature.nil?
              existing.thought_signature = tool_call.thought_signature
            end
          end
        end
      end
    end

    def find_tool_call(tool_call_id)
      if tool_call_id.nil?
        @tool_calls[@latest_tool_call]
      else
        @latest_tool_call_id = tool_call_id
        @tool_calls[tool_call_id]
      end
    end

    def count_tokens(chunk)
      @input_tokens = chunk.input_tokens if chunk.input_tokens
      @output_tokens = chunk.output_tokens if chunk.output_tokens
      @cached_tokens = chunk.cached_tokens if chunk.cached_tokens
      @cache_creation_tokens = chunk.cache_creation_tokens if chunk.cache_creation_tokens
      @thinking_tokens = chunk.thinking_tokens if chunk.thinking_tokens
    end

    def handle_chunk_content(chunk)
      return accumulate_tool_calls(chunk.tool_calls) if chunk.tool_call?

      content_text = chunk.content || ''
      if content_text.is_a?(String)
        append_text_with_thinking(content_text)
      else
        @content << content_text.to_s
      end
    end

    def append_text_with_thinking(text)
      content_chunk, thinking_chunk = extract_think_tags(text)
      @content << content_chunk
      @thinking_text << thinking_chunk if thinking_chunk
    end

    def append_thinking_from_chunk(chunk)
      thinking = chunk.thinking
      return unless thinking

      @thinking_text << thinking.text.to_s if thinking.text
      @thinking_signature ||= thinking.signature # rubocop:disable Naming/MemoizedInstanceVariableName
    end

    def extract_think_tags(text)
      start_tag = '<think>'
      end_tag = '</think>'
      remaining = @pending_think_tag + text
      @pending_think_tag = +''

      output = +''
      thinking = +''

      until remaining.empty?
        remaining = if @inside_think_tag
                      consume_think_content(remaining, end_tag, thinking)
                    else
                      consume_non_think_content(remaining, start_tag, output)
                    end
      end

      [output, thinking.empty? ? nil : thinking]
    end

    def consume_think_content(remaining, end_tag, thinking)
      end_index = remaining.index(end_tag)
      if end_index
        thinking << remaining.slice(0, end_index)
        @inside_think_tag = false
        remaining.slice((end_index + end_tag.length)..) || +''
      else
        suffix_len = longest_suffix_prefix(remaining, end_tag)
        thinking << remaining.slice(0, remaining.length - suffix_len)
        @pending_think_tag = remaining.slice(-suffix_len, suffix_len)
        +''
      end
    end

    def consume_non_think_content(remaining, start_tag, output)
      start_index = remaining.index(start_tag)
      if start_index
        output << remaining.slice(0, start_index)
        @inside_think_tag = true
        remaining.slice((start_index + start_tag.length)..) || +''
      else
        suffix_len = longest_suffix_prefix(remaining, start_tag)
        output << remaining.slice(0, remaining.length - suffix_len)
        @pending_think_tag = remaining.slice(-suffix_len, suffix_len)
        +''
      end
    end

    def longest_suffix_prefix(text, tag)
      max = [text.length, tag.length - 1].min
      max.downto(1) do |len|
        return len if text.end_with?(tag[0, len])
      end
      0
    end
  end
end
