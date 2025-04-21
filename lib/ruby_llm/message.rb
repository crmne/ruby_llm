# frozen_string_literal: true

module RubyLLM
  # A single message in a chat conversation. Can represent user input,
  # AI responses, or tool interactions. Tracks token usage and handles
  # the complexities of tool calls and responses.
  class Message
    ROLES = %i[system user assistant tool].freeze

    attr_reader :role, :tool_calls, :tool_call_id, :input_tokens, :output_tokens, :model_id, :content_schema

    delegate :to_i, :to_a, :to_s, to: :content

    def initialize(options = {})
      @role = options.fetch(:role).to_sym
      @content = normalize_content(options.fetch(:content))
      @tool_calls = options[:tool_calls]
      @input_tokens = options[:input_tokens]
      @output_tokens = options[:output_tokens]
      @model_id = options[:model_id]
      @tool_call_id = options[:tool_call_id]
      @content_schema = options[:content_schema]

      ensure_valid_role
    end

    def content
      if @content_schema.present? && @content_schema[:type].to_s == :object.to_s
        @content_schema[:properties].to_h.keys.none? ? json_response : structured_content
      elsif @content.is_a?(Content) && @content.text && @content.attachments.empty?
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

    def to_h
      {
        role: role,
        content: content,
        tool_calls: tool_calls,
        tool_call_id: tool_call_id,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        model_id: model_id
      }.compact
    end

    private

    def json_response
      return nil if @content.nil?

      JSON.parse(@content.text)
    end

    def structured_content
      return nil if @content.nil?

      json_response['result']
    end

    def normalize_content(content)
      case content
      when String then Content.new(content)
      when Hash then Content.new(content[:text], content)
      else content # Pass through nil, Content, or other types
      end
    end

    def ensure_valid_role
      raise InvalidRoleError, "Expected role to be one of: #{ROLES.join(', ')}" unless ROLES.include?(role)
    end
  end
end
