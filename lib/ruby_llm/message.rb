# frozen_string_literal: true

module RubyLLM
  # A single message in a chat conversation.
  class Message
    ROLES = %i[system user assistant tool].freeze

    attr_reader :role, :model_id, :tool_calls, :tool_call_id, :raw, :thinking, :tokens
    attr_writer :content

    def initialize(options = {})
      @role = options.fetch(:role).to_sym
      @content = normalize_content(options.fetch(:content))
      @model_id = options[:model_id]
      @tool_calls = normalize_tool_calls(options[:tool_calls])
      @tool_call_id = options[:tool_call_id]
      @tokens = options[:tokens] || Tokens.build(
        input: options[:input_tokens],
        output: options[:output_tokens],
        cached: options[:cached_tokens],
        cache_creation: options[:cache_creation_tokens],
        thinking: options[:thinking_tokens],
        reasoning: options[:reasoning_tokens]
      )
      @raw = options[:raw]
      @thinking = options[:thinking]

      ensure_valid_role
        def normalize_tool_calls(tool_calls)
          return nil if tool_calls.nil?
          allowed_keys = %i[id name arguments thought_signature]
          tool_calls.map do |tc|
            if tc.is_a?(RubyLLM::ToolCall)
              tc
            elsif tc.is_a?(Hash)
              h = tc.transform_keys(&:to_sym)
              h = h.select { |k, _| allowed_keys.include?(k) }
              h[:arguments] = h[:arguments].transform_keys(&:to_sym) if h[:arguments].is_a?(Hash)
              RubyLLM::ToolCall.new(**h)
            else
              raise ArgumentError, "tool_calls must be ToolCall or Hash"
            end
          end
        end
    end

    def content
      if @content.is_a?(Content) && @content.text && @content.attachments.empty?
        @content.text
      else
        @content
      end
    end

    def tool_call?
      !tool_calls.nil? && !tool_calls.empty?
    end

    def tool_result?
      !tool_call_id.nil? && !tool_call_id.empty?
    end

    def tool_results
      content if tool_result?
    end

    def input_tokens
      tokens&.input
    end

    def output_tokens
      tokens&.output
    end

    def cached_tokens
      tokens&.cached
    end

    def cache_creation_tokens
      tokens&.cache_creation
    end

    def thinking_tokens
      tokens&.thinking
    end

    def reasoning_tokens
      tokens&.thinking
    end

    def to_h
      {
        role: role,
        content: content,
        model_id: model_id,
        tool_calls: tool_calls&.map { |tc| tc.respond_to?(:to_h) ? tc.to_h : tc },
        tool_call_id: tool_call_id,
        thinking: thinking&.text,
        thinking_signature: thinking&.signature
      }.merge(tokens ? tokens.to_h : {}).compact
    end

    def instance_variables
      super - [:@raw]
    end

    private

    def normalize_tool_calls(tool_calls)
      return nil if tool_calls.nil?
      allowed_keys = %i[id name arguments thought_signature]
      tool_calls.map do |tc|
        if tc.is_a?(RubyLLM::ToolCall)
          tc
        elsif tc.is_a?(Hash)
          # Deep symbolize keys for arguments if present
          h = tc.transform_keys(&:to_sym)
          if h[:arguments].is_a?(Hash)
            h[:arguments] = h[:arguments].transform_keys(&:to_sym)
          end
          filtered = h.select { |k, _| allowed_keys.include?(k) }
          puts "ToolCall.new args: #{filtered.inspect}"
          RubyLLM::ToolCall.new(**filtered)
        else
          tc
        end
      end
    end

    def normalize_content(content)
      case content
      when String then Content.new(content)
      when Hash then Content.new(content[:text], content)
      else content
      end
    end

    def ensure_valid_role
      raise InvalidRoleError, "Expected role to be one of: #{ROLES.join(', ')}" unless ROLES.include?(role)
    end
  end
end
