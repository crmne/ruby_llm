# frozen_string_literal: true

module RubyLLM
  module AgentSDK
    # Base message class - mirrors TypeScript SDK SDKMessage union type
    class Message
      attr_reader :type, :subtype, :data, :uuid, :session_id, :parent_tool_use_id

      # Message types - mirrors TypeScript SDK
      TYPES = %i[assistant user result system stream_event].freeze

      # Result subtypes
      RESULT_SUBTYPES = %i[
        success
        error_max_turns
        error_during_execution
        error_max_budget_usd
        error_max_structured_output_retries
      ].freeze

      # System subtypes
      SYSTEM_SUBTYPES = %i[
        init
        compact_boundary
      ].freeze

      def initialize(json)
        @data = json.freeze
        @type = json[:type]&.to_sym || infer_type(json)
        @subtype = json[:subtype]&.to_sym
        @uuid = json[:uuid]
        @session_id = json[:session_id] || json[:sessionId]
        @parent_tool_use_id = json[:parent_tool_use_id]
      end

      # Type predicates
      def assistant? = type == :assistant
      def user? = type == :user
      def result? = type == :result
      def system? = type == :system
      def stream_event? = type == :stream_event
      def partial? = stream_event? # Alias

      # Result subtype predicates
      def success? = result? && subtype == :success
      def error? = result? && subtype&.to_s&.start_with?('error')
      def error_max_turns? = subtype == :error_max_turns
      def error_during_execution? = subtype == :error_during_execution
      def error_max_budget? = subtype == :error_max_budget_usd

      # System subtype predicates
      def init? = system? && subtype == :init
      def compact_boundary? = system? && subtype == :compact_boundary

      # Dynamic attribute access
      def method_missing(name, *args)
        return @data[name] if @data.key?(name)
        return @data[name.to_s] if @data.key?(name.to_s)

        super
      end

      def respond_to_missing?(name, include_private = false)
        @data.key?(name) || @data.key?(name.to_s) || super
      end

      # Common accessors
      def content
        @data[:content] || @data[:text] || extract_text_content
      end

      def role
        @data[:role]&.to_sym
      end

      def message
        @data[:message]
      end

      def tool_calls
        @data[:tool_use] || @data[:tool_calls] || []
      end

      # Result message fields
      def duration_ms
        @data[:duration_ms]
      end

      def duration_api_ms
        @data[:duration_api_ms]
      end

      def num_turns
        @data[:num_turns]
      end

      def total_cost_usd
        @data[:total_cost_usd]
      end

      def usage
        @data[:usage]
      end

      def model_usage
        @data[:modelUsage] || @data[:model_usage]
      end

      def permission_denials
        @data[:permission_denials] || []
      end

      def structured_output
        @data[:structured_output]
      end

      def errors
        @data[:errors] || []
      end

      # System init message fields
      def api_key_source
        @data[:apiKeySource] || @data[:api_key_source]
      end

      def cwd
        @data[:cwd]
      end

      def tools
        @data[:tools] || []
      end

      def mcp_servers
        @data[:mcp_servers] || []
      end

      def model
        @data[:model]
      end

      def permission_mode
        @data[:permissionMode] || @data[:permission_mode]
      end

      def slash_commands
        @data[:slash_commands] || []
      end

      def output_style
        @data[:output_style]
      end

      # Compact boundary fields
      def compact_metadata
        @data[:compact_metadata]
      end

      # Stream event fields
      def event
        @data[:event]
      end

      def to_h
        @data
      end

      private

      def infer_type(json)
        return :assistant if json[:role] == 'assistant'
        return :user if json[:role] == 'user'
        return :system if json[:role] == 'system' || json[:subtype] == 'init'
        return :result if json[:subtype]&.to_s&.match?(/^(success|error)/)
        return :stream_event if json[:event]

        :unknown
      end

      def extract_text_content
        return nil unless @data[:message]

        content = @data.dig(:message, :content)
        return content if content.is_a?(String)

        # Handle array of content blocks
        if content.is_a?(Array)
          text_blocks = content.select { |c| c[:type] == 'text' }
          return text_blocks.map { |c| c[:text] }.join("\n") unless text_blocks.empty?
        end

        nil
      end
    end

    # Specialized message types for type safety
    class AssistantMessage < Message
      def initialize(json)
        super(json.merge(type: :assistant))
      end
    end

    class UserMessage < Message
      def initialize(json)
        super(json.merge(type: :user))
      end

      def replay? = !uuid.nil?
    end

    class ResultMessage < Message
      def initialize(json)
        super(json.merge(type: :result))
      end
    end

    class SystemMessage < Message
      def initialize(json)
        super(json.merge(type: :system))
      end
    end

    class PartialMessage < Message
      def initialize(json)
        super(json.merge(type: :stream_event))
      end
    end

    # Permission denial info - mirrors TypeScript SDK SDKPermissionDenial
    PermissionDenial = Struct.new(:tool_name, :tool_use_id, :tool_input, keyword_init: true)

    # Model usage info - mirrors TypeScript SDK ModelUsage
    ModelUsage = Struct.new(
      :input_tokens, :output_tokens,
      :cache_read_input_tokens, :cache_creation_input_tokens,
      :web_search_requests, :cost_usd, :context_window,
      keyword_init: true
    )

    # Usage stats - mirrors TypeScript SDK Usage
    Usage = Struct.new(
      :input_tokens, :output_tokens,
      :cache_creation_input_tokens, :cache_read_input_tokens,
      keyword_init: true
    )
  end
end
