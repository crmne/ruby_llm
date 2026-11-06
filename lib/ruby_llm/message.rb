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
  #   response.finish_reason # => :stop
  #
  # A Message also carries everything else the provider returned: token
  # usage (#tokens), reasoning output (#thinking), source citations
  # (#citations), and requested tool calls (#tool_calls).
  class Message
    include Support::Inspectable
    include Accounting::Usage::Result

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
    alias model_id model

    attr_writer :model_info # :nodoc:

    # Returns the slug of the provider that produced the message, from its
    # last successful attempt, or +nil+ when none is recorded, as on user
    # messages. A reply from a model given to Chat#with_fallbacks names that
    # model's provider.
    def provider
      @provider || ruby_llm_usage_entries.reverse.find(&:succeeded?)&.provider
    end

    # Marks the message as the work of a fallback model.
    def stood_in(model:, provider:) # :nodoc:
      @model ||= model
      @provider = provider
      @stood_in = true
      self
    end

    def stood_in? # :nodoc:
      @stood_in || false
    end

    # The tool calls the assistant requested, as an Enumerable of ToolCall
    # objects in provider order, also readable by call ID. Empty when there
    # are none.
    #
    #   response.tool_calls.map(&:name) # => ["weather"]
    #   response.tool_calls["call_1"]   # => #<RubyLLM::ToolCall ...>
    #
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
    # named it, as a lowercase Symbol, such as Anthropic's +:pause_turn+ or
    # Gemini's +:malformed_function_call+.
    attr_reader :finish_reason

    # The ContentFilter verdicts the provider reported on the request and
    # this response, or an empty Array. Read them to see which filter ended
    # a response that is #content_filtered?. Only the live response carries
    # them: #to_h leaves them out, so a persisted chat never stores them.
    attr_reader :content_filters

    # The provider-executed tool steps in this response, as an array of
    # ServerToolCall objects. Empty unless the chat enabled tools with
    # Chat#with_provider_tools and the model used one.
    attr_reader :server_tool_calls

    # The MCP::Result behind a tool result message, when the MCP tool that
    # returned it has a UI and did not fail, so your app can render the UI
    # again with the result. +nil+ otherwise.
    attr_reader :mcp_result

    # The provider-shaped content blocks of this assistant message, kept
    # verbatim when the response used server tools so later requests can
    # replay the turn exactly. +nil+ otherwise.
    attr_reader :raw_content # :nodoc:

    # The provider-shaped reasoning payload of this assistant message, kept
    # verbatim so later requests can replay the model's reasoning exactly.
    # +nil+ when the provider returned none.
    attr_reader :raw_reasoning # :nodoc:

    # The provider's label for this assistant text within its turn, such as
    # OpenAI's +commentary+ or +final_answer+, kept so later requests can
    # send it back. +nil+ when the provider gave none.
    attr_reader :phase # :nodoc:

    # The provider's opaque state for an assistant message it has not
    # finished, which a later request sends back to continue it. +nil+ once
    # the message is complete.
    attr_reader :continuation # :nodoc:

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
      @provider = options[:provider]
      @supplied_cost = coerce_value(options[:cost], Cost)
      @tool_call_id = options[:tool_call_id]
      @provider_call_id = options[:provider_call_id] || options[:provider_tool_call_id]
      @tokens = options[:tokens] || Tokens.new(
        input: options[:input_tokens],
        output: options[:output_tokens],
        cache_read: options[:cache_read_tokens],
        cache_write: options[:cache_write_tokens],
        cache_write_by_ttl: options[:cache_write_tokens_by_ttl],
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
      @phase = options[:phase]
      @continuation = options[:continuation]
      @mcp_result = coerce_mcp_result(options[:mcp_result])
      @finish_reason = options[:finish_reason]&.to_sym
      @content_filters = coerce_list(options[:content_filters], ContentFilter)
      self.ruby_llm_usage_entries = options[:usage_entries] if options[:usage_entries]
      @cache_until_here = options.fetch(:cache_until_here, false)
      @cache_ttl = options[:cache_ttl] if @cache_until_here

      ensure_valid_role
    end

    # Returns #content parsed as JSON, memoized after the first call.
    # Useful for reading structured output responses. When the provider
    # marks part of the turn as commentary before the final answer, only
    # the final answer is parsed.
    #
    #   response = chat.with_schema(PersonSchema).ask "Generate a person"
    #   response.parsed # => {"name" => "Alice", "age" => 30}
    #
    def parsed
      text = answer_text
      return if text.nil? || text.empty?

      @parsed ||= JSON.parse(text)
    end

    # Returns the pages a hosted web search returned for this message, as an
    # array of WebSource objects with each address once. Reads what the message
    # keeps, so a restored message answers the same. Empty when the message
    # ran no search or its provider reports no sources.
    #
    #   response = chat.with_provider_tools(:web_search).ask "What changed in Ruby 4.0?"
    #   response.web_sources.map(&:url)
    #
    # Sources come from the outside world and are not a safe allowlist on their
    # own: a result can be attacker-controlled, and OpenAI can list a page the
    # model chose to open beside what its search found.
    #
    def web_sources
      return [] if server_tool_calls.empty? || provider.nil?

      Array(Provider.resolve(provider)&.web_sources(self)).uniq(&:url)
    end

    # Returns a copy of the message with the given fields changed, like
    # Data#with. The message itself is left alone. Change +content+ or
    # +attachments+:
    #
    #   message.with(content: "[left out]")
    #
    # New content also drops what holds the old text: on an assistant
    # message its thinking, citations, server tool calls, raw response, and
    # native response blocks, and on a tool result its MCP result. Raises
    # ArgumentError for another field.
    def with(**changes)
      unknown = changes.keys - %i[content attachments]
      raise ArgumentError, "Message#with cannot change #{unknown.join(', ')}" if unknown.any?

      changes.reduce(self) do |message, (field, value)|
        field == :content ? message.with_content(value) : message.with_attachments(value)
      end
    end

    def with_content(content) # :nodoc:
      (role == :assistant ? without_native_content : dup).tap do |message|
        message.instance_variable_set(:@content, normalize_content(content))
        message.instance_variable_set(:@mcp_result, nil)
        if role == :assistant
          message.instance_variable_set(:@citations, [])
          message.instance_variable_set(:@server_tool_calls, [])
          message.instance_variable_set(:@raw, nil)
        end
        message.remove_instance_variable(:@parsed) if message.instance_variable_defined?(:@parsed)
      end
    end

    # Returns whether a tool ended the turn with this result, with
    # Tool#halt. Its finish reason is +:halted+.
    def halted?
      finish_reason == :halted
    end

    # Returns whether this is the part of a streamed reply the chat kept
    # when it was cancelled (see Chat#cancel), or the result that closed a
    # tool call it left unfinished. Its finish reason is +:cancelled+.
    def cancelled?
      finish_reason == :cancelled
    end

    def mark_cancelled # :nodoc:
      @finish_reason = :cancelled
      self
    end

    def with_attachments(attachments) # :nodoc:
      wrapped = Attachment.wrap(attachments, config: @config)
      dup.tap { |message| message.instance_variable_set(:@attachments, wrapped) }
    end

    def with_tool_calls(tool_calls) # :nodoc:
      dup.tap { |message| message.instance_variable_set(:@tool_calls, coerce_tool_calls(tool_calls)) }
    end

    def with_tool_call_id(tool_call_id) # :nodoc:
      dup.tap { |message| message.instance_variable_set(:@tool_call_id, tool_call_id) }
    end

    def without_native_content(raw_content: nil) # :nodoc:
      dup.tap do |message|
        message.instance_variable_set(:@thinking, nil)
        message.instance_variable_set(:@raw_reasoning, nil)
        message.instance_variable_set(:@phase, nil)
        message.instance_variable_set(:@continuation, nil)
        message.instance_variable_set(:@raw_content, raw_content)
        message.instance_variable_set(:@tool_calls, coerce_tool_calls(tool_calls_without_thought_signatures))
      end
    end

    # Returns +true+ if the assistant requested one or more tool calls,
    # +false+ otherwise.
    def tool_call?
      !tool_calls.empty?
    end

    # Returns +true+ if the message carries the result of a tool call,
    # +false+ otherwise.
    def tool_result?
      !tool_call_id.nil? && !tool_call_id.empty?
    end

    def provider_call_id # :nodoc:
      return @provider_call_id if @provider_call_id
      return tool_call_id unless tool_result? && conversation

      conversation.messages.reverse_each do |message|
        call = message.tool_calls[tool_call_id]
        return call.provider_call_id if call
      end
      tool_call_id
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

    # Returns the error text of a failed tool result, or +nil+.
    def tool_error_message
      tool_result_payload&.[]('error')
    end

    # Returns +true+ if the response was cut off by a token limit,
    # +false+ otherwise.
    def max_tokens?
      finish_reason == :max_tokens
    end
    alias truncated? max_tokens?

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
    # Uses recorded attempt costs, an explicitly supplied +cost:+, or pricing
    # from #model_info. An explicit +model:+ overrides those costs for repricing.
    #
    #   response.cost.total
    #
    def cost(model: nil)
      return ruby_llm_usage_cost if model.nil? && ruby_llm_usage_entries.any?
      return @supplied_cost if model.nil? && @supplied_cost

      Cost.new(tokens: model ? tokens.without_reported_cost : tokens, model: model || model_info)
    end

    # Marks this message as an explicit prompt cache boundary. Providers
    # with boundary controls use the conversation up to and including this
    # message as the cacheable prefix. Pass +ttl:+, in any form
    # Chat#with_caching takes, to give this boundary its own cache lifetime
    # instead of the +ttl:+ from Chat#with_caching, on
    # providers that set a lifetime per boundary. Returns +self+.
    #
    #   chat.add_message(role: :user, content: long_context).cache_until_here
    #   chat.add_message(role: :user, content: handbook).cache_until_here(ttl: "1h")
    #
    # To mark system instructions, pass +cache_until_here:+ to
    # Chat#with_instructions.
    def cache_until_here(ttl: nil)
      @cache_until_here = true
      @cache_ttl = ttl
      self
    end

    # Returns the cache lifetime given to this message's boundary, such as
    # <tt>"1h"</tt>, or +nil+ when the chat's caching policy applies.
    attr_reader :cache_ttl

    def self.cache_boundary_options(value) # :nodoc:
      return {} if value == true

      options = value.transform_keys(&:to_sym) if value.is_a?(Hash)
      return options if options && (options.keys - %i[ttl]).empty?

      raise ArgumentError, "cache_until_here accepts true, false, or ttl:, got #{value.inspect}"
    end

    # Returns +true+ if the message carries an explicit prompt cache
    # boundary, +false+ otherwise.
    def cache_until_here?
      @cache_until_here
    end

    # Returns a Hash of the message's attributes, with token counts merged
    # in as +:input_tokens+, +:output_tokens+, and related keys. Omits
    # +nil+ values and empty attachment and citation lists. Includes +:cost+
    # only when supplied explicitly, preserving unknown costs on round-trip,
    # and +:reported_cost+ when the provider reported its own price.
    def to_h
      {
        role: role,
        content: content,
        attachments: list_to_h(attachments),
        model: model,
        provider: provider,
        cost: @supplied_cost && cost.to_h,
        reported_cost: tokens.reported_cost,
        tool_calls: tool_calls.empty? ? nil : tool_calls.transform_values(&:to_h),
        tool_call_id: tool_call_id,
        provider_call_id: @provider_call_id,
        thinking: thinking&.text,
        thinking_signature: thinking&.signature,
        citations: list_to_h(citations),
        server_tool_calls: list_to_h(server_tool_calls),
        raw_content: raw_content,
        raw_reasoning: raw_reasoning,
        phase: phase,
        continuation: continuation,
        mcp_result: mcp_result&.dump,
        finish_reason: finish_reason,
        cache_until_here: cache_until_here? || nil,
        cache_ttl: cache_ttl
      }.merge(tokens.to_h).compact
    end

    # Returns the response's Model from its provider's registry, falling
    # back to the requested model when the response ID is unknown.
    # Restored messages use the last successful attempt's provider and model.
    # Messages without request context look up #model, or return +nil+ if unknown.
    def model_info
      return @model_info if @model_info

      entry = ruby_llm_usage_entries.reverse.find(&:succeeded?)
      @model_info = if entry&.model
                      RubyLLM.models.find(entry.model, provider: entry.provider)
                    elsif model
                      RubyLLM.models.find(model)
                    end
    rescue ModelNotFoundError
      nil
    end

    private

    def answer_text
      slug = ruby_llm_usage_entries.reverse.find(&:succeeded?)&.provider if raw_content || phase
      (Provider.resolve(slug)&.answer_text(self) if slug) || content
    end

    def tool_result_payload
      return unless tool_result? && content

      payload = JSON.parse(content)
      payload if payload.is_a?(Hash)
    rescue JSON::ParserError
      nil
    end

    def list_to_h(list)
      list.empty? ? nil : list.map(&:to_h)
    end

    def coerce_tool_calls(tool_calls)
      return tool_calls if tool_calls.is_a?(ToolCall::Collection)
      if tool_calls.is_a?(Array) && tool_calls.all?(ToolCall)
        return ToolCall::Collection.new(ToolCall.index(tool_calls))
      end

      ToolCall::Collection.new(
        tool_calls.to_h do |id, call|
          [id, call.is_a?(Hash) ? tool_call_from_h(id, call) : call]
        end
      )
    end

    def tool_call_from_h(id, call)
      attributes = call.transform_keys(&:to_sym)
      ToolCall.new(id: attributes[:id] || id, name: attributes[:name],
                   provider_call_id: attributes[:provider_call_id] || attributes[:provider_id],
                   arguments: attributes[:arguments] || {},
                   malformed_arguments: attributes[:malformed_arguments],
                   namespace: attributes[:namespace],
                   thought_signature: attributes[:thought_signature], remote: attributes.fetch(:remote, false))
    end

    def tool_calls_without_thought_signatures
      tool_calls.transform_values do |call|
        call.dup.tap { |copy| copy.thought_signature = nil }
      end
    end

    def coerce_thinking(thinking, signature)
      case thinking
      when Thinking then thinking
      when nil then Thinking.build(signature: signature)
      when Hash then Thinking.build(**thinking.transform_keys(&:to_sym).slice(:text, :signature))
      else Thinking.build(text: thinking.to_s, signature: signature)
      end
    end

    def coerce_value(value, klass)
      value.is_a?(Hash) ? klass.from_h(value) : value
    end

    def coerce_list(values, klass)
      Array(values).map { |value| coerce_value(value, klass) }
    end

    def coerce_mcp_result(value)
      value.is_a?(Hash) ? MCP::Result.load(value.transform_keys(&:to_s)) : value
    end

    def normalize_content(content)
      return '' if role == :assistant && content.nil? && tool_call?
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
        tool_calls: tool_calls.map(&:name),
        tool_call_id: tool_call_id,
        model: model,
        finish_reason: finish_reason
      }
    end
  end
end
