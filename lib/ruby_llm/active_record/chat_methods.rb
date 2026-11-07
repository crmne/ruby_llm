# frozen_string_literal: true

require 'active_support/concern'
require 'ruby_llm/active_record/attachment_helpers'
require 'ruby_llm/active_record/claim_heartbeat'
require 'ruby_llm/active_record/run_claims'
require 'ruby_llm/active_record/chat_approvals'
require 'ruby_llm/active_record/chat_cancellation'
require 'ruby_llm/active_record/chat_subagents'
require 'ruby_llm/active_record/chat_placeholders'
require 'ruby_llm/active_record/chat_reply_error'
require 'ruby_llm/active_record/system_instructions'
require 'ruby_llm/active_record/chat_queue'
require 'ruby_llm/active_record/chat_tool_call_state'
require 'ruby_llm/active_record/chat_run'
require 'ruby_llm/active_record/chat_agent_hooks'

module RubyLLM
  module ActiveRecord
    # ChatMethods provides the RubyLLM::Chat API on ActiveRecord models
    # declared with <tt>acts_as_chat</tt>, persisting every message to the
    # database. Configuration methods return +self+ so calls can be chained.
    #
    #   class Chat < ApplicationRecord
    #     acts_as_chat
    #   end
    #
    #   chat = Chat.create!(model: 'gpt-6-luna')
    #   chat.ask "What is the capital of France?"
    #   chat.messages.count # => 2
    #
    module ChatMethods
      extend ActiveSupport::Concern
      include RubyLLM::Support::DeprecatedEnumerable
      include AttachmentHelpers
      include RunClaims
      include ChatApprovals
      include ChatCancellation
      include ChatSubagents
      include ChatPlaceholders
      include ChatReplyError
      include SystemInstructions
      prepend ChatAgentHooks

      CANCELLATION_POLL_INTERVAL = 1.0 # :nodoc:
      COMPLETION_ERRORS = [ # :nodoc:
        CancelledError, Error, ConfigurationError, Faraday::Error, Timeout::Error, Errno::ETIMEDOUT
      ].freeze

      included do
        before_save :resolve_model
      end

      # Returns the record's attributes as a Hash, accepting the same options
      # as any Active Record model, rather than the message list Enumerable
      # would serialize.
      def as_json(options = nil)
        ActiveModel::Serializers::JSON.instance_method(:as_json).bind_call(self, options)
      end

      # When +true+, skips the model registry lookup so unregistered model ids
      # are accepted. Not persisted; set it again after reloading the record.
      attr_accessor :assume_model_exists

      # Overrides the wire protocol the provider would pick for the model, such
      # as +:responses+ or +:chat_completions+ for OpenAI, or +nil+ for the
      # provider default. Not persisted; set it again after reloading the record.
      attr_reader :protocol

      # Sets the protocol override, switching the underlying chat to it when
      # that is already built.
      def protocol=(value)
        @protocol = value
        @chat_model_stale = true if @chat
      end

      # An optional RubyLLM::Context supplying per-chat configuration. Not
      # persisted; set it again after reloading the record. Assigning one
      # rebinds the underlying chat, like #with_context.
      attr_reader :context

      # Requests cancellation of the current in-flight chat operation, or of
      # the run that will answer a message still waiting for one. The request
      # is persisted so a background job can observe it from another process,
      # and reaches the runs of the subagents with a chat record that the
      # chat's calls run (see RubyLLM::AgentTool). Does nothing when no run
      # holds the chat and nothing waits to run. Returns +self+.
      def cancel
        request_cancellation
        self
      end

      # Returns whether this record or its memoized in-memory chat has a
      # pending cancellation request.
      def cancelled?
        @chat&.cancelled? || self[:cancelled]
      end

      # Records approval for +tool_call+ (a ToolCall, a tool call record, or
      # an id) on the persisted tool call, so the next #complete executes it
      # from any process. Approving a call that is running or answered
      # changes nothing. With <tt>remember: true</tt>, later calls to the
      # same tool run without asking for the rest of the chat, as
      # RubyLLM::Chat#approve describes, in every process. Returns +self+.
      #
      #   chat.approve(params[:tool_call_id])
      #   chat.approve(params[:tool_call_id], remember: true)
      #   CompleteJob.perform_later(chat.id)
      #
      # A call of a subagent the chat waits on (see #pending_approvals) is
      # approved in the subagent's chat, and +remember+ applies there. The
      # next #complete carries the subagent on, then the chat.
      def approve(tool_call, remember: false)
        decision = remember ? 'remembered' : 'approved'
        deciding(tool_call, decision) do |record|
          to_llm.approve(record.to_llm, remember:) if record.result_id.nil?
          record_tool_call_decision(record, decision)
        end
      end

      # Records denial for +tool_call+ (a ToolCall, a tool call record, or
      # an id) on the persisted tool call. The next #complete appends a
      # structured denial result instead of executing the tool. Denying an
      # answered call changes nothing. A call of a subagent the chat waits
      # on is denied in the subagent's chat, as #approve does. Returns
      # +self+.
      #
      # Raises RubyLLM::ToolCallRunningError when the call is already
      # running.
      def deny(tool_call)
        deciding(tool_call, 'denied') { |record| to_llm.deny(record_tool_call_decision(record, 'denied').to_llm) }
      end

      def claiming_delivery(&) # :nodoc:
        exclusively(-> { false }) { transaction(requires_new: true, &) }
      end

      # Returns whether a process is running this chat's conversation loop:
      # calling the model or running tools from #complete, #step, #generate,
      # #run_tools, or #compact. Reads the database, so it sees runs in
      # other processes. While another process runs the chat, those methods
      # return without doing anything and #waiting? is +true+. A process
      # that dies stops counting as running within a minute.
      #
      #   retry_job wait: 1.minute if chat.running?
      #
      def running?
        return false unless run_claims?

        claimed_until = self.class.uncached { chat_row.pick(:claimed_until) }
        claimed_until&.future? || false
      end

      # Returns whether the conversation can't continue until something
      # outside it happens, as RubyLLM::Chat#waiting? describes, or until
      # the process that is #running? it finishes. Approvals, answers, and
      # tasks persist on their tool calls, so any process sees what the
      # chat waits on.
      def waiting?
        to_llm.waiting? || running_elsewhere?
      end

      # Returns whether the conversation is waiting on tool calls that
      # require approval and have no recorded decision, its own or those of
      # a subagent it waits on. See RubyLLM::Chat#awaiting_approval?.
      def awaiting_approval?
        to_llm.awaiting_approval? || (waiting? && subagent_pending_approvals?)
      end

      # Returns the persisted tool call records that require approval and
      # have no recorded decision, ready to render as approval cards. Pass
      # a record (or its tool_call_id) to #approve or #deny.
      # A record's +remote?+ identifies a provider-executed call. Records
      # come in the order the model made the calls.
      #
      #   chat.pending_approvals.each { |record| render record }
      #
      # Whether a call requires approval is decided when it is saved, by
      # the process that received it, so reading this queries the database
      # only and connects to no MCP server. A call whose tool decides with
      # a Tool.requires_approval block stays listed until the chat runs
      # again.
      #
      # The calls of the chat's subagents that have a chat record of their
      # own (see RubyLLM::AgentTool) are listed too, after the calls made
      # before them. A record's +message+ belongs to the chat that made the
      # call.
      def pending_approvals
        with_subagent_approvals(persisted_pending_approvals)
      end

      def messages_association # :nodoc:
        association(messages_association_name).reader
      end

      def find_tool_call(tool_call_id) # :nodoc:
        RubyLLM::ActiveRecord::ToolCall.find_by(
          tool_call_id: tool_call_id,
          message_type: messages_association.klass.polymorphic_name,
          message_id: messages_association.select(:id)
        )
      end

      def persist_usage_entry(entry) # :nodoc:
        usage_records_by_entry[entry] = Usage.transaction(requires_new: true) do
          ruby_llm_usages.create!(Usage.attributes_for(entry))
        end
      rescue StandardError => e
        RubyLLM.logger.warn("RubyLLM could not record #{entry.operation} usage: #{e.class}: #{e.message}")
      end

      def refresh_messages # :nodoc:
        messages_association.reset
        reload_usages
        sync_messages if @chat
      end

      # Sets the chat's model from an id, a RubyLLM::Model value, or the
      # associated internal model record.
      #
      #   chat.model = 'gpt-6-luna'
      #
      def model=(value)
        if value.is_a?(RubyLLM::ActiveRecord::Model)
          @pending_model_id = nil
          @pending_provider = nil
          super
        else
          @pending_model_id = value.respond_to?(:id) ? value.id : value
          @pending_provider = value.provider if value.respond_to?(:provider)
        end
        @chat_model_stale = true if @chat
      end

      # Stores +value+ as the model id, resolved to a model record before save.
      def model_id=(value)
        self.model = value
      end

      # Returns the model id assigned since the last save, or that of the
      # associated model record, or +nil+.
      #
      #   chat.model_id # => "gpt-6-luna"
      #
      def model_id
        @pending_model_id || model&.model_id
      end

      # Stores +value+ as the provider used when resolving the model id
      # before save.
      def provider=(value)
        @pending_provider = value
        @chat_model_stale = true if @chat
      end

      # Returns the provider assigned since the last save, or that of the
      # associated model record, or +nil+. A model id assigned without a
      # provider has none until save resolves it.
      def provider
        @pending_provider || (model&.provider unless @pending_model_id)
      end

      # Returns the underlying RubyLLM::Chat for this record, building it on
      # first call and memoizing it. The chat is loaded with the persisted
      # messages and wired to persist new ones. Subsequent calls return the
      # same chat without touching the database, switched to any model
      # assigned since; use #reload to refresh its message history from the
      # record.
      def to_llm
        @chat ||= build_llm_chat
        @chat.with_model(model_id, provider: provider&.to_sym, protocol:, assume_model_exists:) if @chat_model_stale
        @chat_model_stale = false
        @chat
      end

      # Reloads the record from the database, Rails-style, and refreshes the
      # underlying chat's model and persisted message history to match. Runtime-only
      # configuration such as tools, temperature, and callbacks is preserved;
      # a model or provider assigned since the last save is discarded.
      # Returns +self+.
      def reload(...)
        super
        @pending_model_id = @pending_provider = nil
        @chat_model_stale = true if @chat && chat_model_moved?
        sync_messages if @chat
        self
      end

      # Rebinds the underlying chat to +value+ so subsequent requests use its
      # configuration. Pass +nil+ to return to the global RubyLLM
      # configuration. The Context itself is runtime-only and is not
      # persisted.
      def with_context(value)
        @context = value
        @chat&.with_context(value)
        self
      end
      alias context= with_context

      # Sets the system instructions, persisting them as a message with the
      # +:system+ role. Replaces any persisted system messages unless
      # +append:+ is true. Pass <tt>persist: false</tt> to apply the
      # instructions only to the in-memory chat for this record instance.
      # With <tt>cache_until_here: true</tt> the instruction becomes an
      # explicit prompt cache boundary, and <tt>cache_until_here: { ttl: "1h" }</tt>
      # gives that boundary its own lifetime. Returns +self+.
      #
      #   chat.with_instructions "You are a Ruby expert."
      #   chat.with_instructions "Use short bullet points.", append: true
      #   chat.with_instructions current_context, persist: false
      #
      def with_instructions(instructions, append: false, persist: true, cache_until_here: false)
        to_llm

        if persist
          if instructions.nil?
            clear_persisted_system_instructions
          else
            persist_system_instruction(instructions, append:, cache_until_here:)
          end
        else
          store_unpersisted_instruction(instructions, append:, cache_until_here:)
        end

        sync_messages
        self
      end

      # Chat configuration and callback methods forwarded to the underlying
      # RubyLLM::Chat. Each behaves exactly as documented on RubyLLM::Chat,
      # then returns the record so calls chain.
      CHAINABLE_CHAT_DELEGATES = %i[
        with_tools with_mcp with_tool_options with_provider_tools with_fallbacks with_temperature answer decline
        with_max_output_tokens with_thinking with_citations with_caching
        with_end_user with_owner with_compaction with_context_budget with_code_execution with_skills
        with_provider_options with_headers with_schema
        convert_unsupported_attachments
        before_request before_message after_message before_tool_call around_tool_call after_tool_result
        after_tool_progress before_fallback after_fallback around_join after_file_write
      ].freeze

      ##
      # :method: with_tools
      # :call-seq: with_tools(*tools, defer: nil)
      #
      # Applies Chat#with_tools and returns this record.

      ##
      # :method: with_mcp
      # :call-seq: with_mcp(*servers, defer: nil)
      #
      # Applies Chat#with_mcp and returns this record.

      ##
      # :method: answer
      # :call-seq: answer(request, **values)
      #
      # Applies Chat#answer and returns this record. The answer persists
      # on the tool call, so any process can resume the call.

      ##
      # :method: decline
      # :call-seq: decline(request)
      #
      # Applies Chat#decline and returns this record.

      ##
      # :method: with_tool_options
      # :call-seq: with_tool_options(**options)
      #
      # Applies Chat#with_tool_options and returns this record.

      ##
      # :method: with_provider_tools
      # :call-seq: with_provider_tools(*tools, **tools_with_options)
      #
      # Applies Chat#with_provider_tools and returns this record.

      ##
      # :method: with_fallbacks
      # :call-seq: with_fallbacks(*models, on: Fallback::DEFAULT_ERRORS, drop_unsupported: false)
      #
      # Applies Chat#with_fallbacks and returns this record.

      ##
      # :method: with_temperature
      # :call-seq: with_temperature(temperature)
      #
      # Applies Chat#with_temperature and returns this record.

      ##
      # :method: with_max_output_tokens
      # :call-seq: with_max_output_tokens(max_output_tokens)
      #
      # Applies Chat#with_max_output_tokens and returns this record.

      ##
      # :method: with_thinking
      # :call-seq: with_thinking(enabled = true, **options)
      #
      # Applies Chat#with_thinking and returns this record.

      ##
      # :method: with_citations
      # :call-seq: with_citations(enabled = true)
      #
      # Applies Chat#with_citations and returns this record.

      ##
      # :method: with_caching
      # :call-seq: with_caching(options = {})
      #
      # Applies Chat#with_caching and returns this record.

      ##
      # :method: with_end_user
      # :call-seq: with_end_user(end_user)
      #
      # Applies Chat#with_end_user and returns this record.

      ##
      # :method: with_owner
      # :call-seq: with_owner(owner)
      #
      # Applies Chat#with_owner and returns this record. The owner is not
      # persisted, so set it, or let the agent's +owner+ set it, on each
      # record you load.

      ##
      # :method: with_context_budget
      # :call-seq: with_context_budget(budget = {}, per_result: nil, per_request: nil, window: nil)
      #
      # Applies Chat#with_context_budget and returns this record.

      ##
      # :method: with_compaction
      # :call-seq: with_compaction(options = {})
      #
      # Applies Chat#with_compaction and returns this record.

      ##
      # :method: with_code_execution
      # :call-seq: with_code_execution(enabled = true, **options)
      #
      # Applies Chat#with_code_execution and returns this record.

      ##
      # :method: with_skills
      # :call-seq: with_skills(*skills)
      #
      # Applies Chat#with_skills and returns this record.

      ##
      # :method: after_file_write
      # :call-seq: after_file_write(&block)
      #
      # Applies Chat#after_file_write and returns this record.

      ##
      # :method: with_provider_options
      # :call-seq: with_provider_options(provider_options)
      #
      # Applies Chat#with_provider_options and returns this record.

      ##
      # :method: with_headers
      # :call-seq: with_headers(headers)
      #
      # Applies Chat#with_headers and returns this record.

      ##
      # :method: with_schema
      # :call-seq: with_schema(schema)
      #
      # Applies Chat#with_schema and returns this record.

      ##
      # :method: convert_unsupported_attachments
      # :call-seq: convert_unsupported_attachments(&block)
      #
      # Applies Chat#convert_unsupported_attachments and returns this record.

      ##
      # :method: before_request
      # :call-seq: before_request(&block)
      #
      # Applies Chat#before_request and returns this record.

      ##
      # :method: before_message
      # :call-seq: before_message(&block)
      #
      # Applies Chat#before_message and returns this record.

      ##
      # :method: after_message
      # :call-seq: after_message(&block)
      #
      # Applies Chat#after_message and returns this record.

      ##
      # :method: before_tool_call
      # :call-seq: before_tool_call(&block)
      #
      # Applies Chat#before_tool_call and returns this record.

      ##
      # :method: after_tool_result
      # :call-seq: after_tool_result(&block)
      #
      # Applies Chat#after_tool_result and returns this record.

      ##
      # :method: around_tool_call
      # :call-seq: around_tool_call(&block)
      #
      # Applies Chat#around_tool_call and returns this record.

      ##
      # :method: after_tool_progress
      # :call-seq: after_tool_progress(&block)
      #
      # Applies Chat#after_tool_progress and returns this record.

      ##
      # :method: before_fallback
      # :call-seq: before_fallback(&block)
      #
      # Applies Chat#before_fallback and returns this record.

      ##
      # :method: after_fallback
      # :call-seq: after_fallback(&block)
      #
      # Applies Chat#after_fallback and returns this record.

      ##
      # :method: around_join
      # :call-seq: around_join(&block)
      #
      # Applies Chat#around_join and returns this record. The block
      # receives the QueuedMessage record and +join+, in the process that
      # runs the chat, inside the transaction that creates the message
      # record and deletes the queued one. <tt>join.call</tt> takes
      # attributes for the new message record and returns it, so the
      # record is saved with your own columns set:
      #
      #   chat.around_join do |queued, join|
      #     join.call(sender: queued.sender)
      #   end
      #
      # When the block raises, the transaction rolls back and the message
      # stays queued. When it never calls +join+, the queued record is
      # deleted without joining.

      ##
      # :method: caching
      # :call-seq: caching
      #
      # Delegates to Chat#caching. See that method for arguments and return values.

      ##
      # :method: citations
      # :call-seq: citations
      #
      # Delegates to Chat#citations. See that method for arguments and return values.

      ##
      # :method: code_execution
      # :call-seq: code_execution
      #
      # Delegates to Chat#code_execution. See that method for arguments and return values.

      ##
      # :method: skills
      # :call-seq: skills
      #
      # Delegates to Chat#skills. See that method for arguments and return values.

      ##
      # :method: file_store
      # :call-seq: file_store
      #
      # Delegates to Chat#file_store. See that method for arguments and return values.

      ##
      # :method: compaction
      # :call-seq: compaction
      #
      # Delegates to Chat#compaction. See that method for arguments and return values.

      ##
      # :method: context_budget
      # :call-seq: context_budget
      #
      # Delegates to Chat#context_budget. See that method for arguments and return values.

      ##
      # :method: concurrency
      # :call-seq: concurrency
      #
      # Delegates to Chat#concurrency. See that method for arguments and return values.

      ##
      # :method: end_user
      # :call-seq: end_user
      #
      # Delegates to Chat#end_user. See that method for arguments and return values.

      ##
      # :method: owner
      # :call-seq: owner
      #
      # Delegates to Chat#owner. See that method for arguments and return values.

      ##
      # :method: fallbacks
      # :call-seq: fallbacks
      #
      # Delegates to Chat#fallbacks. See that method for arguments and return values.

      ##
      # :method: headers
      # :call-seq: headers
      #
      # Delegates to Chat#headers. See that method for arguments and return values.

      ##
      # :method: max_output_tokens
      # :call-seq: max_output_tokens
      #
      # Delegates to Chat#max_output_tokens. See that method for arguments and return values.

      ##
      # :method: provider_options
      # :call-seq: provider_options
      #
      # Delegates to Chat#provider_options. See that method for arguments and return values.

      ##
      # :method: schema
      # :call-seq: schema
      #
      # Delegates to Chat#schema. See that method for arguments and return values.

      ##
      # :method: provider_tools
      # :call-seq: provider_tools
      #
      # Delegates to Chat#provider_tools. See that method for arguments and return values.

      ##
      # :method: temperature
      # :call-seq: temperature
      #
      # Delegates to Chat#temperature. See that method for arguments and return values.

      ##
      # :method: thinking
      # :call-seq: thinking()
      #
      # Delegates to Chat#thinking. See that method for arguments and return values.

      ##
      # :method: tool_options
      # :call-seq: tool_options()
      #
      # Delegates to Chat#tool_options. See that method for arguments and return values.

      ##
      # :method: tools
      # :call-seq: tools
      #
      # Delegates to Chat#tools. See that method for arguments and return values.

      ##
      # :method: deferred_tools
      # :call-seq: deferred_tools
      #
      # Delegates to Chat#deferred_tools. See that method for arguments and return values.

      ##
      # :method: mcp
      # :call-seq: mcp
      #
      # Delegates to Chat#mcp. See that method for arguments and return values.

      ##
      # :method: awaiting_input?
      # :call-seq: awaiting_input?
      #
      # Delegates to Chat#awaiting_input?. See that method for arguments and return values.

      ##
      # :method: pending_inputs
      # :call-seq: pending_inputs
      #
      # Delegates to Chat#pending_inputs. Requests persist on their tool
      # calls, so they survive restarts.

      ##
      # :method: awaiting_tasks?
      # :call-seq: awaiting_tasks?
      #
      # Delegates to Chat#awaiting_tasks?. See that method for arguments and return values.

      ##
      # :method: awaiting_person?
      # :call-seq: awaiting_person?
      #
      # Delegates to Chat#awaiting_person?. See that method for arguments and return values.

      ##
      # :method: pending_tasks
      # :call-seq: pending_tasks
      #
      # Delegates to Chat#pending_tasks. Tasks persist on their tool calls,
      # so any process can check on them and resume the chat.

      CHAINABLE_CHAT_DELEGATES.each do |name|
        define_method(name) do |*args, **kwargs, &block|
          to_llm.public_send(name, *args, **kwargs, &block)
          self
        end
      end

      # Chat values and operations whose return values pass through unchanged.
      #
      # The public methods behave as documented on RubyLLM::Chat.

      PASSTHROUGH_CHAT_DELEGATES = %i[
        caching citations code_execution compaction context_budget concurrency end_user owner fallbacks headers
        max_output_tokens provider_options schema provider_tools temperature thinking tool_options tools deferred_tools
        mcp skills file_store
        awaiting_input? pending_inputs awaiting_tasks? pending_tasks awaiting_person? add_completion count_tokens
        render
      ].freeze

      ##
      # :method: count_tokens
      # :call-seq: count_tokens(message = nil)
      #
      # Returns the number of input tokens the next request would carry,
      # counted by the provider over the persisted conversation.

      ##
      # :method: render
      # :call-seq: render
      #
      # Returns the next request payload with #before_request hooks applied.

      PASSTHROUGH_CHAT_DELEGATES.each do |name|
        define_method(name) do |*args, **kwargs, &block|
          to_llm.public_send(name, *args, **kwargs, &block)
        end
      end

      private_constant :CHAINABLE_CHAT_DELEGATES, :PASSTHROUGH_CHAT_DELEGATES

      # Switches the chat to +model_name+, resolving and saving the model
      # record and updating the underlying chat. Falls back to the configured
      # default model when +model_name+ is +nil+. Pass +protocol:+ to override
      # the wire protocol the provider would pick for the model. Returns +self+.
      #
      #   chat.with_model 'claude-sonnet-5'
      #
      def with_model(model_name, provider: nil, protocol: nil, assume_model_exists: false)
        model_name ||= (context&.config || RubyLLM.config).default_model
        self.model = model_name
        self.provider = provider if provider
        self.protocol = protocol
        self.assume_model_exists = assume_model_exists
        resolve_model
        save!
        to_llm
        self
      end

      # Persists +message_or_attributes+ as a message record, including any
      # attachments and tool calls. Accepts a RubyLLM::Message, an attributes
      # Hash, or a record responding to +to_llm+.
      # Returns the message record.
      #
      #   chat.add_message(role: :user, content: long_context)
      #
      def add_message(message_or_attributes)
        persist_message(message_or_attributes)
      end

      # Persists +message_or_attributes+ like #add_message, assigning
      # +record_attributes+ to the new record. Returns the message record.
      def persist_message(message_or_attributes, record_attributes = {}) # :nodoc:
        llm_message = to_llm.prepare_message(message_or_attributes) do |id|
          RubyLLM::ActiveRecord::ToolCall.exists?(tool_call_id: id)
        end

        message_record = create_message_record(llm_message, record_attributes)
        @last_message_id = message_record.id

        tool_call = find_tool_call(llm_message.tool_call_id) if llm_message.tool_call_id
        if tool_call && tool_call.result_id.nil?
          tool_call.mcp_result = llm_message.mcp_result&.dump if tool_call.has_attribute?(:mcp_result)
          tool_call.update!(result: message_record)
        end

        persist_content(message_record, llm_message.attachments) if llm_message.attachments.any?
        persist_tool_calls(llm_message.tool_calls, message_record:) if llm_message.tool_calls.present?

        @chat.add_message(llm_message)

        bind_message_chat(message_record)
      end

      # Deprecated: mark the message itself, or pass +cache_until_here:+ to
      # #with_instructions. Marks the latest persisted message as a prompt
      # cache boundary, or the latest in-memory message when none is
      # persisted yet. Warns through RubyLLM.deprecator. RubyLLM 3.0 removes
      # it. Returns +self+.
      #
      #   chat.with_instructions('Reusable analysis prompt', cache_until_here: { ttl: "1h" })
      #   chat.add_message(role: :user, content: long_context).cache_until_here
      #
      # Raises ArgumentError if the chat has no messages.
      def cache_until_here(ttl: nil)
        RubyLLM.deprecator.deprecate("#{self.class}#cache_until_here",
                                     replacement: 'Message#cache_until_here or with_instructions(cache_until_here:)',
                                     removal: '3.0')
        message_record = messages_association.order(:id).last
        if message_record
          bind_message_chat(message_record).cache_until_here(ttl:)
        elsif @chat&.messages&.any?
          @chat.messages.last.cache_until_here(ttl:)
        else
          raise ArgumentError, 'No messages to cache'
        end

        self
      end

      # Returns token usage aggregated across every persisted usage entry,
      # including retries and attempts that did not produce a message.
      #
      #   chat.tokens.input
      #
      def tokens
        RubyLLM::Tokens.aggregate(ruby_llm_usages.map(&:tokens))
      end

      # Returns a RubyLLM::Cost aggregating every persisted usage entry,
      # including retries and attempts that did not produce a message.
      #
      #   chat.cost.total
      #
      def cost
        records = ruby_llm_usages.to_a
        RubyLLM::Cost.aggregate(records.map(&:cost), complete: records.all?(&:cost_available?))
      end

      def ruby_llm_usage_entries # :nodoc:
        records = ruby_llm_usages.to_a
        ::ActiveRecord::Associations::Preloader.new(records:, associations: [:message, *Usage.owner_preload]).call
        records.map(&:to_entry)
      end

      # Persists +message+ as a user message, after every queued message
      # (see #queue), then runs the conversation loop and returns the latest
      # assistant RubyLLM::Message. The loop pauses when #awaiting_approval?
      # is true. Yields streaming chunks to a block.
      #
      #   chat.ask "What is the capital of France?"
      #   chat.ask "What's in this file?", with: "diagram.png"
      #
      def ask(message = nil, with: nil, &)
        ask_later(message, with: with)
        complete(&)
      end

      alias say ask

      # Deprecated: iterate <tt>to_llm.messages</tt> for the same objects, or
      # the message association for your records. Yields each RubyLLM::Message
      # in the conversation, or returns an Enumerator without a block. The
      # Enumerable methods built on it, such as +map+ and +count+, are
      # deprecated with it. Warns through RubyLLM.deprecator. RubyLLM 3.0
      # removes them.
      def each(&)
        RubyLLM.deprecator.deprecate("Enumerable on #{self.class}", replacement: "#{self.class}#to_llm.messages",
                                                                    removal: '3.0')
        to_llm.messages.each(&)
      end

      # Persists +message+ as a user message without calling the model, so
      # #complete can run later, usually in a job. Every queued message (see
      # #queue) is persisted first, in order. Returns +self+.
      #
      #   chat.ask_later params[:content]
      #   ChatResponseJob.perform_later(chat.id)
      #
      # While a run holds the chat, in this process or another, the message
      # is queued instead, as #queue does, so the transcript that run writes
      # stays whole. The run takes it at its next step, or the next
      # #complete does. An MCP::Prompt, which the queue can't hold, is
      # persisted either way.
      #
      # Raises PendingToolCallsError while the last response has tool calls
      # waiting for their results and no run holds the chat.
      def ask_later(message = nil, with: nil)
        return tap { queue(message, with:) } if running? && !message.is_a?(RubyLLM::MCP::Prompt)

        to_llm.raise_if_pending_tool_calls!
        to_llm.raise_if_prompt_attachments!(message, with)
        to_llm.take_queued_messages
        if message.is_a?(RubyLLM::MCP::Prompt)
          message.messages.each { |prompt_message| add_message(prompt_message) }
        else
          add_message(role: :user, content: message, attachments: with)
        end
        self
      end

      # Makes a single generation attempt, persists the response, and returns it as a
      # RubyLLM::Message. Tool calls in the response are not executed. See
      # RubyLLM::Chat#generate. Returns +nil+ without calling the model
      # while another process is #running? the chat. A block receives the
      # chunks as it does in #complete.
      def generate(&block)
        exclusively(-> {}) { completing(block) { |on_chunk| to_llm.generate(&on_chunk) } }
      end

      # Compacts the model context and persists its assistant Message without
      # deleting earlier messages. See RubyLLM::Chat#compact. Returns +nil+
      # without calling the model while another process is #running? the
      # chat.
      def compact
        exclusively(-> {}) { completing { to_llm.compact } }
      end

      # Executes the pending tool calls and persists their results without
      # calling the model. See RubyLLM::Chat#run_tools. Does nothing while
      # another process is #running? the chat. Returns +self+.
      def run_tools
        exclusively(-> {}) { to_llm.run_tools }
        self
      end

      # Advances the conversation by one move: runs the pending tool calls if
      # there are any, otherwise generates a response. Returns +nil+ once the
      # chat is complete or #waiting?, including while another process is
      # #running? it. See RubyLLM::Chat#step. A block receives the chunks as
      # it does in #complete.
      #
      #   chat.step until chat.complete? || chat.waiting?
      #
      def step(&block)
        exclusively(-> {}) { completing(block) { |on_chunk| to_llm.step(&on_chunk) } }
      end

      # Returns whether the conversation has no pending work, neither a
      # response to generate nor tool calls to run. See
      # RubyLLM::Chat#complete?.
      def complete?
        to_llm.complete?
      end

      # Runs the completion loop on the underlying chat, persisting each
      # message, and returns the latest RubyLLM::Message. Pauses when a tool
      # requires approval. When the API call fails, destroys the empty assistant
      # message and any orphaned tool results, then re-raises the error. When
      # the block raises, destroys the empty assistant message and re-raises.
      # Tool calls paused on a task or an MCP input request stay, so the next
      # #complete picks them up.
      #
      # Only one process runs a chat at a time. While another process is
      # #running? it, returns the latest message without calling the model
      # or running tools, and #waiting? is +true+. Work recorded while this
      # process ran, such as an approval, continues before it returns. A job
      # that finds the chat running tries again later, which also covers a
      # process that dies, since its claim expires within a minute:
      #
      #   def perform(chat_id)
      #     chat = ChatAgent.find(chat_id)
      #     chat.complete(&:broadcast)
      #     retry_job wait: 1.minute if chat.running?
      #   end
      #
      # Each chunk passed to the block also answers +message+, the record
      # it streams into, and +broadcast+ (see ChunkMethods). When the
      # messages broadcast with Turbo, the chat's page refreshes once the
      # run ends.
      #
      # Queued messages join as RubyLLM::Chat#complete describes, including
      # those another process queues while this one runs. A message that
      # steers, queued as the run ends, starts another loop before
      # #complete returns. When #cancel stops the run while messages wait
      # in the queue, the run goes on with them before #complete returns,
      # as the next #complete would. It raises CancelledError when none
      # wait, or when the stop came before the run began.
      #
      # When the chats table has a +reply_error+ column, a failed reply
      # saves a short message for the person there before the error is
      # raised, and the next run clears it, so the chat's page can show it
      # whenever it loads. The message comes from I18n:
      # +ruby_llm.reply_error.too_long+ for ContextLengthExceededError,
      # +ruby_llm.reply_error.failed+ for any other error, with English
      # defaults.
      def complete(&block)
        operation = :complete
        loop do
          busy = stopped_before_run = false
          response = exclusively(-> { busy = true }) do
            stopped_before_run = self[:cancelled]
            clear_reply_error
            completing(block) { |on_chunk| to_llm.public_send(operation, &on_chunk) }
          end
          return latest_message if busy

          operation = operation_after_run
          return response unless operation
        rescue CancelledError
          raise if stopped_before_run || ChatQueue.new(self).none?

          operation = :complete
        end
      rescue StandardError => e
        record_reply_error(e)
        raise
      ensure
        broadcast_refresh_to(self, request_id: nil) if broadcasts_messages?
      end

      # Queues +message+ in the chat's +ruby_llm_queued_messages+ table, as
      # RubyLLM::Chat#queue describes, and returns the QueuedMessage record.
      # Attachments given with +with:+ are stored with Active Storage and
      # move to the message it becomes. +sender+ is any record, such as the
      # user who asked; it is stored and handed back, never interpreted.
      #
      # Any process can queue a message. The process that runs the chat
      # takes it at its next step; when none is running, run #complete,
      # usually in a job. #ask_later queues for you while a run holds the
      # chat, so reach for #queue when a message should wait for the turn
      # to end (<tt>steer: false</tt>) or keep its +sender+.
      #
      #   chat.queue params[:content], sender: Current.user
      #   ChatResponseJob.perform_later(chat.id)
      #
      def queue(message = nil, with: nil, steer: true, sender: nil)
        to_llm.queue(message, with:, steer:, sender:)
      end

      # Returns the QueuedMessage records waiting in the queue, oldest
      # first, ready to render.
      def queued_messages = ruby_llm_queued_messages.scope.skip_query_cache!

      # Takes +queued+, a QueuedMessage record or its id, out of the queue
      # and deletes its attachments. Returns +true+, or +false+ once the
      # loop has taken it into the conversation or it was withdrawn already.
      # QueuedMessage#withdraw does the same from the record. See
      # RubyLLM::Chat#withdraw.
      def withdraw(queued)
        to_llm.withdraw(queued)
      end

      # Persists every queued message as a user message record, without
      # calling the model, and returns the records, oldest first. Each joins
      # through #around_join and runs #after_message, as
      # RubyLLM::Chat#join_queued_messages describes.
      #
      #   chat.join_queued_messages.map(&:content) # => ["Use the EU file"]
      #
      def join_queued_messages
        to_llm.join_queued_messages
      end

      private

      def create_message_record(llm_message, record_attributes)
        transaction do
          forget_stale_cancellation if llm_message.role == :user
          messages_association.create!(message_attributes(llm_message).merge(record_attributes))
        end
      end

      def broadcasts_messages?
        message_class = messages_association.klass
        message_class.include?(MessageBroadcasting) && message_class.broadcasting?
      end

      def completing(block = nil)
        yield ChunkMethods.streaming(block, on_error: method(:cleanup_after_block_failure)) { @message }
      rescue *COMPLETION_ERRORS => e
        cleanup_after_failure(e)
        raise
      end

      def chat_model_moved?
        [@chat.model.id, @chat.provider.slug] != [model_id, provider.to_s]
      end

      def latest_message
        to_llm.messages.reverse.find { |message| message.role != :system } || to_llm.messages.last
      end

      def bind_message_chat(message)
        message.association(message.chat_association_name).target = self
        message
      end

      def link_usage_entries(message)
        Usage.transaction(requires_new: true) do
          message.ruby_llm_usage_entries.each do |entry|
            record = usage_records_by_entry[entry]
            record&.update!(message: @message)
          end
        end
      rescue StandardError => e
        RubyLLM.logger.warn("RubyLLM could not link usage to message #{@message.id}: #{e.class}: #{e.message}")
      end

      def usage_records_by_entry
        @usage_records_by_entry ||= {}.compare_by_identity
      end

      def resolve_model
        config = context&.config || RubyLLM.config
        @pending_model_id ||= config.default_model unless model
        return unless @pending_model_id || (@pending_provider && model)

        model_info = resolve_model_info

        self.model = find_or_create_model(model_info)
        @pending_model_id = nil
        @pending_provider = nil
      end

      def resolve_model_info
        return find_registered_model unless assume_model_exists

        raise ArgumentError, 'Provider must be specified if assume_model_exists is true' unless @pending_provider

        begin
          find_registered_model
        rescue RubyLLM::ModelNotFoundError
          RubyLLM::Model.default(model_id, @pending_provider)
        end
      end

      def find_registered_model
        RubyLLM.models.find_configured(model_id, provider: @pending_provider, config: context&.config)
      end

      # An empty store would otherwise hold only this chat's model on the next
      # boot, since the registry reads whatever the store returns.
      def load_model_registry_into_store
        RubyLLM::ActiveRecord::Model.save_to_database(RubyLLM.models)
      rescue ::ActiveRecord::RecordInvalid, ::ActiveRecord::RecordNotUnique
        nil
      end

      def find_or_create_model(model_info)
        attributes = { model_id: model_info.id, provider: model_info.provider }
        load_model_registry_into_store if RubyLLM::ActiveRecord::Model.none?

        RubyLLM::ActiveRecord::Model.find_or_create_by!(attributes) do |record|
          record.name = model_info.name || model_info.id
          record.family = model_info.family
          record.model_created_at = model_info.created_at
          record.context_window = model_info.context_window
          record.max_output_tokens = model_info.max_output_tokens
          record.knowledge_cutoff = model_info.knowledge_cutoff
          record.capabilities = model_info.capabilities || []
          record.modalities = model_info.modalities.to_h
          record.pricing = model_info.pricing.to_h
          record.metadata = model_info.metadata || {}
        end
      rescue ::ActiveRecord::RecordInvalid, ::ActiveRecord::RecordNotUnique
        # Another process can insert the row between the lookup and the insert.
        RubyLLM::ActiveRecord::Model.find_by(attributes) || raise
      end

      def cleanup_after_failure(error)
        reason = error.is_a?(RubyLLM::CancelledError) ? 'chat cancelled' : 'API call failed'
        cleanup_failed_messages(reason:) if blank_placeholder?
        cleanup_orphaned_tool_results
        resync_messages if @chat
      end

      def cleanup_after_block_failure
        cleanup_failed_messages(reason: 'streaming block failed') if blank_placeholder?
      end

      def cleanup_failed_messages(reason:)
        RubyLLM.logger.warn "RubyLLM: #{reason}, destroying message: #{@message.id}"
        @message.destroy
      end

      def cleanup_orphaned_tool_results # rubocop:disable Metrics/PerceivedComplexity
        messages_association.reload
        last = eager_load_messages.last

        return unless last&.tool_call? || last&.tool_result?

        if last.tool_call?
          last.destroy unless last.ruby_llm_tool_calls.any?(&:paused?)
        else
          parent = last.ruby_llm_parent_tool_call
          tool_call_message = parent.message
          calls = tool_call_message.ruby_llm_tool_calls

          if calls.any? { |call| call.result.nil? } && calls.none?(&:paused?)
            calls.filter_map(&:result).each(&:destroy)
            tool_call_message.destroy
          end
        end
      end

      def eager_load_messages
        assoc = messages_association
        messages = assoc.to_a
        return messages unless assoc.respond_to?(:klass)

        associations = [:ruby_llm_tool_calls, :ruby_llm_parent_tool_call, { ruby_llm_usages: Usage.owner_preload }]
        associations << { attachments_attachments: :blob } if attachment_association?(assoc.klass)
        rich_text_reflection = assoc.klass.reflect_on_association(:rich_text_content)
        associations << :rich_text_content if rich_text_reflection

        ::ActiveRecord::Associations::Preloader.new(records: messages, associations: associations).call
        preload_action_text_embeds(messages) if rich_text_reflection
        messages
      end

      def attachment_association?(message_class)
        message_class.reflect_on_association(:attachments_attachments).present?
      end

      def build_llm_chat
        chat = (context || RubyLLM).chat(
          model: model_id,
          provider: provider&.to_sym,
          protocol: protocol,
          assume_model_exists: assume_model_exists || false
        )
        sync_messages(chat)
        chat.run = ChatRun.new(self)
        chat.tool_call_state = @tool_call_state = ChatToolCallState.new(self)
        chat.message_queue = ChatQueue.new(self)
        install_persistence_callbacks(chat)
      end

      def sync_messages(chat = @chat)
        snapshot_run_claim
        message_records = eager_load_messages
        @last_message_id = message_records.last&.id
        chat.messages = message_records
        linked_entry_pairs = message_records.zip(chat.messages).flat_map do |record, message|
          record.ruby_llm_usage_records.zip(message.ruby_llm_usage_entries)
        end
        linked_entries = linked_entry_pairs.to_h { |record, entry| [record.id, entry] }
        ::ActiveRecord::Associations::Preloader.new(records: ruby_llm_usages.to_a,
                                                    associations: Usage.owner_preload).call
        chat.usage_entries = ruby_llm_usages.map do |record|
          linked_entries.fetch(record.id) { record.to_entry }
        end
        reapply_runtime_instructions(chat)
        chat
      end

      def install_persistence_callbacks(chat)
        chat.before_message { persist_new_message }
        chat.after_message { |msg| persist_message_completion(msg) unless msg&.role == :user }
        chat
      end

      def clear_persisted_system_instructions
        association = messages_association
        association.where(role: :system).destroy_all
        association.reset
      end

      def replace_persisted_system_instructions(instructions, cache_until_here:)
        existing = messages_association.where(role: :system).order(:id).to_a
        if existing.one?
          update_persisted_system_instruction(existing.first, instructions, cache_until_here:)
        else
          clear_persisted_system_instructions
          messages_association.create!(role: :system, content: instructions,
                                       **cache_boundary_attributes(cache_until_here))
        end
      end

      # Rewriting the same instructions every turn would move the system row
      # behind the user messages and rebroadcast it each time.
      def update_persisted_system_instruction(record, instructions, cache_until_here:)
        attributes = system_instruction_attributes(record, instructions, cache_until_here)
        changed = attributes.any? { |column, value| record[column] != value }
        record.update!(attributes) if changed
        messages_association.reset
        record
      end

      def persist_system_instruction(instructions, append:, cache_until_here:)
        transaction do
          if append
            messages_association.create!(
              role: :system,
              content: instructions,
              **cache_boundary_attributes(cache_until_here)
            )
          else
            replace_persisted_system_instructions(instructions, cache_until_here:)
          end
        end
      end

      def cache_boundary_attributes(cache_until_here)
        ttl = RubyLLM::Message.cache_boundary_options(cache_until_here)[:ttl] if cache_until_here
        attributes = { cache_until_here: cache_until_here ? true : false }
        attributes[:cache_ttl] = ttl if ttl || messages_association.klass.column_names.include?('cache_ttl')
        attributes
      end

      def unpersisted_instructions
        @unpersisted_instructions ||= []
      end

      def store_unpersisted_instruction(instructions, append:, cache_until_here:)
        if instructions.nil?
          @unpersisted_instructions = []
          return
        end

        entry = [instructions, append, cache_until_here]
        if append
          unpersisted_instructions << entry
        else
          @unpersisted_instructions = [entry]
        end
      end

      def reapply_runtime_instructions(chat)
        unpersisted_instructions.each do |instructions, append, cache_until_here|
          chat.with_instructions(instructions, append:, cache_until_here:)
        end
      end

      def persist_message_completion(message)
        return unless message

        tool_call = find_tool_call(message.tool_call_id) if message.tool_call_id
        attrs = message_attributes(message)

        answered = fenced_by_run_claim do
          @message.assign_attributes(attrs)
          @message.save!
          raise ::ActiveRecord::Rollback if tool_call && !tool_result_recorded?(tool_call, message)

          persist_content(@message, message.attachments) if message.attachments.any?
          persist_tool_calls(message.tool_calls) if message.tool_calls.present?
          link_usage_entries(message)
          true
        end
        discard_superseded_message unless answered
      end

      def message_attributes(message)
        attrs = { role: message.role, content: message.content }
        assign_supported_attribute(attrs, :thinking_text, message.thinking&.text)
        assign_supported_attribute(attrs, :thinking_signature, message.thinking&.signature)
        assign_supported_attribute(attrs, :citations, message.citations.map(&:to_h).presence)
        assign_supported_attribute(attrs, :server_tool_calls, message.server_tool_calls.map(&:to_h).presence)
        assign_supported_attribute(attrs, :raw_content, message.raw_content)
        assign_supported_attribute(attrs, :raw_reasoning, message.raw_reasoning)
        assign_supported_attribute(attrs, :phase, message.phase)
        assign_supported_attribute(attrs, :continuation, message.continuation)
        assign_supported_attribute(attrs, :finish_reason, message.finish_reason)
        assign_supported_attribute(attrs, :cache_until_here, message.cache_until_here?)
        assign_supported_attribute(attrs, :cache_ttl, message.cache_ttl)
        assign_fallback_attributes(attrs, message) if message.stood_in?
        attrs
      end

      def assign_fallback_attributes(attributes, message)
        assign_supported_attribute(attributes, :model_id, message.model_id)
        assign_supported_attribute(attributes, :provider, message.provider)
      end

      def assign_supported_attribute(attributes, name, value)
        attributes[name] = value if messages_association.klass.column_names.include?(name.to_s)
      end

      def persist_tool_calls(tool_calls, message_record: @message)
        tool_calls.each do |tool_call|
          attributes = tool_call.to_h
          attributes[:tool_call_id] = attributes.delete(:id)
          malformed = attributes.delete(:malformed_arguments)
          attributes[:arguments] = without_nul(malformed) if malformed
          attributes[:approval] = 'pending' if to_llm.approval_pending?(tool_call)
          message_record.ruby_llm_tool_calls.create!(**attributes)
        end
      end

      # PostgreSQL jsonb cannot store U+0000.
      def without_nul(text)
        text.gsub("\u0000", '\u0000')
      end
    end
  end
end
