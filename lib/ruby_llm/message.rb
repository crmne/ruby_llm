# frozen_string_literal: true

module RubyLLM
  # A Message is a single entry in a chat conversation: a user prompt, an
  # assistant reply, a system instruction, or a tool result. Chat#ask
  # returns the model's reply as a Message, and Chat#messages holds the
  # transcript as an array of them.
  #
  #   response = chat.ask "What is the capital of France?"
  #   response.role          # => :assistant
  #   response.content       # => "The capital of France is Paris."
  #   response.finish_reason # => "stop"
  #
  # A Message also carries everything else the provider returned: token
  # usage (#tokens), reasoning output (#thinking), source citations
  # (#citations), and requested tool calls (#tool_calls).
  class Message
    include Inspectable
    include Usage::Result

    # The valid message roles: +:system+, +:user+, +:assistant+, and +:tool+.
    ROLES = %i[system user assistant tool].freeze

    # The role of the message: +:system+, +:user+, +:assistant+, or +:tool+.
    attr_reader :role

    # The message text as a String. Empty for assistant messages that only
    # request tool calls.
    attr_reader :content

    # The files sent or returned with the message, as an array of
    # Attachment objects.
    attr_reader :attachments

    # The ID of the model that produced the message, +nil+ on user messages.
    attr_reader :model

    # The tool calls the assistant requested, as a Hash of ToolCall objects
    # keyed by call ID, or +nil+.
    attr_reader :tool_calls

    # The ID of the tool call this message answers. Set only on tool result
    # messages.
    attr_reader :tool_call_id

    # The raw provider response: a Faraday::Response, or the result body
    # Hash for messages retrieved from a Batch.
    attr_reader :raw

    # The model's reasoning output as a Thinking object, or +nil+ when the
    # provider returned none.
    attr_reader :thinking

    # The source citations as an array of Citation objects, normalized
    # across providers.
    attr_reader :citations

    # Why the model stopped: +:stop+, +:max_tokens+, +:tool_calls+, or
    # +:content_filter+. Any other reason comes through as the provider
    # spelled it, such as Anthropic's +:pause_turn+.
    attr_reader :finish_reason

    # The provider-executed tool steps in this response, as an array of
    # ServerToolCall objects. Empty unless the chat enabled tools with
    # Chat#with_server_tools and the model used one.
    attr_reader :server_tool_calls

    # The provider-shaped content blocks of this assistant message, kept
    # verbatim when the response used server tools so later requests can
    # replay the turn exactly. +nil+ otherwise.
    attr_reader :raw_content # :nodoc:

    # The provider-shaped reasoning payload of this assistant message, kept
    # verbatim so later requests can replay the model's reasoning exactly.
    # +nil+ when the provider returned none.
    attr_reader :raw_reasoning # :nodoc:

    # The Chat this message belongs to, set when it is added to a
    # conversation. Backs #tool_results.
    attr_accessor :conversation # :nodoc:

    def initialize(options = {}) # :nodoc:
      @role = options.fetch(:role).to_sym
      @tool_calls = coerce_tool_calls(options[:tool_calls])
      @content = normalize_content(options.fetch(:content))
      @config = options[:config]
      @attachments = Attachment.wrap(options[:attachments], config: @config)
      @model = options[:model]
      @tool_call_id = options[:tool_call_id]
      @tokens = options[:tokens] || Tokens.new(
        input: options[:input_tokens],
        output: options[:output_tokens],
        cache_read: options[:cache_read_tokens],
        cache_write: options[:cache_write_tokens],
        thinking: options[:thinking_tokens],
        server_tool_use: options[:server_tool_use],
        reported_cost: options[:reported_cost]
      )
      @raw = options[:raw]
      @thinking = coerce_thinking(options[:thinking], options[:thinking_signature])
      @citations = Array(options[:citations]).map { |citation| coerce_value(citation, Citation) }
      @server_tool_calls = Array(options[:server_tool_calls]).map { |call| coerce_value(call, ServerToolCall) }
      @raw_content = options[:raw_content]
      @raw_reasoning = options[:raw_reasoning]
      @finish_reason = options[:finish_reason]&.to_sym
      self.ruby_llm_usage_entries = options[:usage_entries] if options[:usage_entries]
      @cache_until_here = options.fetch(:cache_until_here, false)

      ensure_valid_role
    end

    # Returns #content parsed as JSON, memoized after the first call.
    # Useful for reading structured output responses.
    #
    #   response = chat.with_schema(PersonSchema).ask "Generate a person"
    #   response.parsed # => {"name" => "Alice", "age" => 30}
    #
    def parsed
      return if content.nil? || content.empty?

      @parsed ||= JSON.parse(content)
    end

    def with_attachments(attachments) # :nodoc:
      wrapped = Attachment.wrap(attachments, config: @config)
      dup.tap { |message| message.instance_variable_set(:@attachments, wrapped) }
    end

    # Returns +true+ if the assistant requested one or more tool calls,
    # +false+ otherwise.
    def tool_call?
      !tool_calls.nil? && !tool_calls.empty?
    end

    # Returns +true+ if the message carries the result of a tool call,
    # +false+ otherwise.
    def tool_result?
      !tool_call_id.nil? && !tool_call_id.empty?
    end

    # Returns the tool result messages answering this message's tool calls,
    # or an empty array when it made none. Mirrors the +tool_results+
    # association on acts_as_message records.
    def tool_results
      return [] unless tool_call? && conversation

      conversation.messages.select do |message|
        message.tool_result? && tool_calls.key?(message.tool_call_id)
      end
    end

    # Returns +true+ if #finish_reason indicates the model finished
    # normally, +false+ otherwise. A turn that stopped to call tools is
    # reported by #tool_call_stop? instead, whatever the provider named it.
    def stopped?
      finish_reason == :stop && !tool_call?
    end

    # Returns +true+ if the response was cut off by a token limit,
    # +false+ otherwise.
    def max_tokens?
      finish_reason == :max_tokens
    end

    # Returns +true+ if the model stopped to request tool calls,
    # +false+ otherwise.
    def tool_call_stop?
      finish_reason == :tool_calls || (tool_call? && finish_reason == :stop)
    end

    # Returns +true+ if a provider safety filter stopped the response,
    # +false+ otherwise.
    def content_filtered?
      finish_reason == :content_filter
    end

    # Returns usage aggregated across every provider attempt that produced this
    # message. Messages constructed by hand report the token counts they were
    # built with.
    def tokens
      return @tokens if ruby_llm_usage_entries.empty?

      ruby_llm_usage_tokens
    end

    # Returns a Cost pricing this message's token usage in US dollars.
    # Pricing comes from #model_info, or from +model:+ when given.
    #
    #   response.cost.total
    #
    def cost(model: nil)
      return ruby_llm_usage_cost if model.nil? && ruby_llm_usage_entries.any?

      Cost.new(tokens:, model: model || model_info)
    end

    # Marks this message as an explicit prompt cache boundary. Providers
    # that support prompt caching cache the conversation up to and
    # including this message. Returns +self+.
    #
    #   chat.add_message(role: :user, content: long_context).cache_until_here
    #
    def cache_until_here
      @cache_until_here = true
      self
    end

    # Returns +true+ if the message carries an explicit prompt cache
    # boundary, +false+ otherwise.
    def cache_until_here?
      @cache_until_here
    end

    # Returns a Hash of the message's attributes, with token counts merged
    # in as +:input_tokens+, +:output_tokens+, and related keys. Omits
    # +nil+ values and empty attachment and citation lists.
    def to_h
      {
        role: role,
        content: content,
        attachments: list_to_h(attachments),
        model: model,
        tool_calls: tool_calls&.transform_values(&:to_h),
        tool_call_id: tool_call_id,
        thinking: thinking&.text,
        thinking_signature: thinking&.signature,
        citations: list_to_h(citations),
        server_tool_calls: list_to_h(server_tool_calls),
        raw_content: raw_content,
        raw_reasoning: raw_reasoning,
        finish_reason: finish_reason,
        cache_until_here: cache_until_here? || nil
      }.merge(tokens.to_h).compact
    end

    # Returns the Model record for #model from the model registry, or
    # +nil+ when the message has no model or the model is unknown.
    def model_info
      return unless model

      @model_info ||= RubyLLM.models.find(model)
    rescue ModelNotFoundError
      nil
    end

    private

    def list_to_h(list)
      list.empty? ? nil : list.map(&:to_h)
    end

    def coerce_tool_calls(tool_calls)
      return tool_calls unless tool_calls.is_a?(Hash)

      tool_calls.to_h do |id, call|
        next [id, call] unless call.is_a?(Hash)

        attributes = call.transform_keys(&:to_sym)
        [id, ToolCall.new(id: attributes[:id] || id, name: attributes[:name],
                          arguments: attributes[:arguments] || {},
                          thought_signature: attributes[:thought_signature])]
      end
    end

    def coerce_thinking(thinking, signature)
      case thinking
      when nil, Thinking then thinking
      when Hash then Thinking.build(**thinking.transform_keys(&:to_sym).slice(:text, :signature))
      else Thinking.build(text: thinking.to_s, signature: signature)
      end
    end

    def coerce_value(value, klass)
      value.is_a?(Hash) ? klass.from_h(value) : value
    end

    def normalize_content(content)
      return '' if role == :assistant && content.nil? && tool_calls && !tool_calls.empty?
      return content if content.nil? || content.is_a?(String)

      raise ArgumentError,
            "Message content must be a String, got #{content.class}. " \
            'Pass files via attachments: and structured data as JSON.'
    end

    def ensure_valid_role
      raise InvalidRoleError, "Expected role to be one of: #{ROLES.join(', ')}" unless ROLES.include?(role)
    end

    def inspect_attributes # :nodoc:
      {
        role: role,
        content: content,
        tool_calls: tool_calls&.values&.map(&:name),
        tool_call_id: tool_call_id,
        model: model,
        finish_reason: finish_reason
      }
    end
  end
end
