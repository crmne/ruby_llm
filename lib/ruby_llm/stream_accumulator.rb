# frozen_string_literal: true

module RubyLLM
  # Assembles streaming responses from LLMs into complete messages.
  class StreamAccumulator
    attr_reader :content, :model_id, :tool_calls

    def initialize
      @content = nil
      @tool_calls = {}
      @input_tokens = 0
      @output_tokens = 0
      @latest_tool_call_id = nil
    end

    def add(chunk)
      RubyLLM.logger.debug chunk.inspect if RubyLLM.config.log_stream_debug
      @model_id ||= chunk.model_id

      if chunk.tool_call?
        accumulate_tool_calls chunk.tool_calls
      else
        accumulate_content(chunk.content)
      end

      count_tokens chunk
      RubyLLM.logger.debug inspect if RubyLLM.config.log_stream_debug
    end

    def to_message(response)
      Message.new(
        role: :assistant,
        content: final_content,
        model_id: model_id,
        tool_calls: tool_calls_from_stream,
        input_tokens: @input_tokens.positive? ? @input_tokens : nil,
        output_tokens: @output_tokens.positive? ? @output_tokens : nil,
        raw: response
      )
    end

    private

    def accumulate_content(new_content)
      return unless new_content

      if @content.nil?
        @content = new_content.is_a?(String) ? +new_content : new_content
      else
        case [@content.class, new_content.class]
        when [String, String]
          @content << new_content
        when [String, Content]
          # Convert accumulated string to Content and merge
          @content = Content.new(@content)
          merge_content(new_content)
        when [Content, String]
          # Append string to existing Content's text
          @content.instance_variable_set(:@text, (@content.text || '') + new_content)
        when [Content, Content]
          merge_content(new_content)
        end
      end
    end

    def merge_content(new_content)
      # Merge text
      current_text = @content.text || ''
      new_text = new_content.text || ''
      @content.instance_variable_set(:@text, current_text + new_text)

      # Merge attachments
      new_content.attachments.each do |attachment|
        @content.attach(attachment)
      end
    end

    def final_content
      case @content
      when nil
        nil
      when String
        @content.empty? ? nil : @content
      when Content
        @content.text.nil? && @content.attachments.empty? ? nil : @content
      else
        @content
      end
    end

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
          arguments: arguments
        )
      end
    end

    def accumulate_tool_calls(new_tool_calls)
      RubyLLM.logger.debug "Accumulating tool calls: #{new_tool_calls}" if RubyLLM.config.log_stream_debug
      new_tool_calls.each_value do |tool_call|
        if tool_call.id
          tool_call_id = tool_call.id.empty? ? SecureRandom.uuid : tool_call.id
          tool_call_arguments = tool_call.arguments.empty? ? +'' : tool_call.arguments
          @tool_calls[tool_call.id] = ToolCall.new(
            id: tool_call_id,
            name: tool_call.name,
            arguments: tool_call_arguments
          )
          @latest_tool_call_id = tool_call.id
        else
          existing = @tool_calls[@latest_tool_call_id]
          existing.arguments << tool_call.arguments if existing
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
    end
  end
end
