# frozen_string_literal: true

require 'active_support/concern'
require 'ruby_llm/active_record/attachment_helpers'

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
    #   chat = Chat.create!(model: 'gpt-5.6-luna')
    #   chat.ask "What is the capital of France?"
    #   chat.messages.count # => 2
    #
    module ChatMethods
      extend ActiveSupport::Concern
      include Enumerable
      include AttachmentHelpers

      CANCELLATION_POLL_INTERVAL = 1.0
      COMPLETION_ERRORS = [
        RubyLLM::CancelledError, RubyLLM::Error, Faraday::Error, Timeout::Error, Errno::ETIMEDOUT
      ].freeze

      included do
        before_save :resolve_model
      end

      # When +true+, skips the model registry lookup so unregistered model ids
      # are accepted. Not persisted; set it again after reloading the record.
      attr_accessor :assume_model_exists

      # Overrides the wire protocol the provider would pick for the model, such
      # as +:responses+ or +:chat_completions+ for OpenAI, or +nil+ for the
      # provider default. Not persisted; set it again after reloading the record.
      attr_accessor :protocol

      # An optional RubyLLM::Context supplying per-chat configuration, used
      # when building the underlying chat. Not persisted; set it again after
      # reloading the record.
      attr_accessor :context

      # Requests cancellation of the current in-flight chat operation. The
      # request is persisted so a background job can observe it from another
      # process.
      def cancel
        if persisted?
          update_column(:cancelled, true)
        else
          self[:cancelled] = true
        end

        @chat&.cancel
        self
      end

      # Returns whether this record or its memoized in-memory chat has a
      # pending cancellation request.
      def cancelled?
        @chat&.cancelled? || self[:cancelled]
      end

      # Records approval for +tool_call+ (a ToolCall, a tool call record, or
      # an id) on the persisted tool call, so the next #complete executes it
      # from any process. Returns +self+.
      #
      #   chat.approve(params[:tool_call_id])
      #   CompleteJob.perform_later(chat.id)
      #
      def approve(tool_call)
        record_tool_call_decision(tool_call, 'approved')
      end

      # Records denial for +tool_call+ (a ToolCall, a tool call record, or
      # an id) on the persisted tool call. The next #complete appends a
      # structured denial result instead of executing the tool. Returns
      # +self+.
      def deny(tool_call)
        record_tool_call_decision(tool_call, 'denied')
      end

      # Returns whether the conversation is parked on tool calls that
      # require approval and have no recorded decision. See
      # RubyLLM::Chat#awaiting_approval?.
      def awaiting_approval?
        to_llm.awaiting_approval?
      end

      # Returns the persisted tool call records that require approval and
      # have no recorded decision, ready to render as approval cards. Pass
      # a record (or its tool_call_id) to #approve or #deny.
      #
      #   chat.pending_approvals.each { |record| render record }
      #
      def pending_approvals
        ids = to_llm.pending_approvals.map(&:id)
        RubyLLM::ActiveRecord::ToolCall.where(
          tool_call_id: ids,
          message_type: self.class.message_class.constantize.polymorphic_name,
          message_id: messages_association.select(:id)
        )
      end

      def messages_association # :nodoc:
        send(messages_association_name)
      end

      # Sets the chat's model from an id, a RubyLLM::Model value, or the
      # associated internal model record.
      #
      #   chat.model = 'gpt-5.6-luna'
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
      end

      # Stores +value+ as the model id, resolved to a model record before save.
      def model_id=(value)
        @pending_model_id = value
      end

      # Returns the model id of the associated model record, or +nil+.
      #
      #   chat.model_id # => "gpt-5.6-luna"
      #
      def model_id
        model&.model_id || @pending_model_id
      end

      # Stores +value+ as the provider used when resolving the model id
      # before save.
      def provider=(value)
        @pending_provider = value
      end

      # Returns the provider of the associated model record, or +nil+.
      def provider
        model&.provider || @pending_provider
      end

      # Returns the underlying RubyLLM::Chat for this record, building it on
      # first call and memoizing it. The chat is loaded with the persisted
      # messages and wired to persist new ones. Subsequent calls return the
      # same chat without touching the database; use #reload to refresh its
      # message history from the record.
      def to_llm
        @chat ||= build_llm_chat # rubocop:disable Naming/MemoizedInstanceVariableName
      end

      # Reloads the record from the database, Rails-style, and refreshes the
      # underlying chat's persisted message history to match. Runtime-only
      # configuration such as tools, temperature, and callbacks is preserved.
      # Returns +self+.
      def reload(...)
        super
        sync_messages if @chat
        self
      end

      # Rebinds the underlying chat to +value+ so subsequent requests use its
      # configuration. Pass +nil+ to return to the global RubyLLM
      # configuration. The Context itself is runtime-only and is not
      # persisted.
      def with_context(value)
        self.context = value
        @chat&.with_context(value)
        self
      end

      # Sets the system instructions, persisting them as a message with the
      # +:system+ role. Replaces any persisted system messages unless
      # +append:+ is true. Pass <tt>persist: false</tt> to apply the
      # instructions only to the in-memory chat for this record instance.
      # With <tt>cache_until_here: true</tt> the instruction becomes an
      # explicit prompt cache boundary. Returns +self+.
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
        with_tools with_tool_options with_server_tools with_fallbacks with_temperature
        with_max_output_tokens with_thinking with_citations with_caching
        with_end_user with_compaction
        with_provider_options with_headers with_schema
        before_request before_message after_message before_tool_call after_tool_result
        before_fallback after_fallback
      ].freeze

      CHAINABLE_CHAT_DELEGATES.each do |name|
        define_method(name) do |*args, **kwargs, &block|
          to_llm.public_send(name, *args, **kwargs, &block)
          self
        end
      end

      # Chat values and operations whose return values pass through unchanged.
      #
      # The public methods behave as documented on RubyLLM::Chat.

      ##
      # :method: count_tokens
      # :call-seq: count_tokens(message = nil)
      #
      # Returns the number of input tokens the next request would carry,
      # counted by the provider over the persisted conversation.

      ##
      # :method: each
      # :call-seq: each(&block)
      #
      # Yields each message in the conversation. Returns an Enumerator without a block.

      ##
      # :method: render
      # :call-seq: render
      #
      # Returns the next request payload with #before_request hooks applied.

      PASSTHROUGH_CHAT_DELEGATES = %i[
        caching citations compaction concurrency end_user fallbacks headers max_output_tokens provider_options
        schema server_tools temperature thinking tool_options tools
        add_completion count_tokens each render
      ].freeze

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
        to_llm.with_model(model_id, provider: provider&.to_sym, protocol:, assume_model_exists:)
        self
      end

      # Persists +message_or_attributes+ (a RubyLLM::Message or an attributes
      # Hash) as a message record, including any attachments and tool calls.
      # Returns the message record.
      #
      #   chat.add_message(role: :user, content: long_context)
      #
      def add_message(message_or_attributes)
        llm_message = message_or_attributes.is_a?(RubyLLM::Message) ? message_or_attributes : RubyLLM::Message.new(message_or_attributes)

        message_record = messages_association.create!(message_attributes(llm_message))

        if llm_message.tool_call_id && (tool_call = find_tool_call(llm_message.tool_call_id))
          tool_call.update!(result: message_record)
        end

        persist_content(message_record, llm_message.attachments) if llm_message.attachments.any?
        persist_tool_calls(llm_message.tool_calls, message_record:) if llm_message.tool_calls.present?

        @chat&.add_message(llm_message)

        message_record
      end

      # Marks the latest persisted message as a prompt cache boundary, or the
      # latest in-memory message when none is persisted yet. Returns +self+.
      #
      #   chat.with_instructions('Reusable analysis prompt').cache_until_here
      #
      # Raises ArgumentError if the chat has no messages.
      def cache_until_here
        message_record = messages_association.order(:id).last
        if message_record
          message_record.cache_until_here
        elsif @chat&.messages&.any?
          @chat.cache_until_here
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

      # Persists +message+ as a user message, then runs the completion loop
      # and returns the assistant RubyLLM::Message. Yields streaming chunks
      # to the block when given.
      #
      #   chat.ask "What is the capital of France?"
      #   chat.ask "What's in this file?", with: "diagram.png"
      #
      def ask(message = nil, with: nil, &)
        ask_later(message, with: with)
        complete(&)
      end

      alias say ask

      # Persists +message+ as a user message without calling the model, so
      # #complete can run later. Returns +self+.
      #
      #   chat.ask_later "Summarize this document."
      #   chat.complete
      #
      def ask_later(message = nil, with: nil)
        to_llm.raise_if_pending_tool_calls!
        add_message(role: :user, content: message, attachments: with)
        self
      end

      # Makes a single generation attempt, persists the response, and returns it as a
      # RubyLLM::Message. Tool calls in the response are not executed. See
      # RubyLLM::Chat#generate.
      def generate(...)
        to_llm.generate(...)
      rescue *COMPLETION_ERRORS => e
        cleanup_after_failure(e)
        raise
      end

      # Executes the pending tool calls and persists their results without
      # calling the model. See RubyLLM::Chat#run_tools. Returns +self+.
      def run_tools
        to_llm.run_tools
        self
      end

      # Advances the conversation by one move: runs the pending tool calls if
      # there are any, otherwise generates a response. Returns +nil+ once the
      # chat is complete. See RubyLLM::Chat#step.
      #
      #   chat.step until chat.complete?
      #
      def step(...)
        to_llm.step(...)
      rescue *COMPLETION_ERRORS => e
        cleanup_after_failure(e)
        raise
      end

      # Returns whether the conversation has no pending work, neither a
      # response to generate nor tool calls to run. See
      # RubyLLM::Chat#complete?.
      def complete?
        to_llm.complete?
      end

      # Runs the completion loop on the underlying chat, persisting each
      # message, and returns the final assistant RubyLLM::Message. When the
      # API call fails, destroys the empty assistant message and any orphaned
      # tool results, then re-raises the error.
      def complete(...)
        to_llm.complete(...)
      rescue *COMPLETION_ERRORS => e
        cleanup_after_failure(e)
        raise
      end

      private

      def persist_usage_entry(entry)
        tokens = entry.tokens
        cost = entry.cost
        attributes = {
          operation: entry.operation,
          provider: entry.provider,
          model: entry.model,
          status: entry.status,
          input_tokens: tokens.input,
          output_tokens: tokens.output,
          cache_read_tokens: tokens.cache_read,
          cache_write_tokens: tokens.cache_write,
          thinking_tokens: tokens.thinking,
          input_cost: cost.input,
          output_cost: cost.output,
          cache_read_cost: cost.cache_read,
          cache_write_cost: cost.cache_write,
          thinking_cost: cost.thinking,
          total_cost: cost.total
        }
        record = ruby_llm_usages.create!(attributes)
        usage_records_by_entry[entry] = record
      end

      def link_usage_entries(message)
        message.ruby_llm_usage_entries.each do |entry|
          record = usage_records_by_entry[entry]
          record&.update!(message: @message)
        end
      end

      def usage_records_by_entry
        @usage_records_by_entry ||= {}.compare_by_identity
      end

      def resolve_model
        config = context&.config || RubyLLM.config
        @pending_model_id ||= config.default_model unless model
        return unless @pending_model_id

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
          RubyLLM::Model.default(@pending_model_id, @pending_provider)
        end
      end

      def find_registered_model
        RubyLLM.models.find(@pending_model_id, provider: @pending_provider, config: context&.config)
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
          last.destroy
        elsif last.tool_result?
          parent = last.ruby_llm_parent_tool_call
          tool_call_message = parent.message
          calls = tool_call_message.ruby_llm_tool_calls

          if calls.any? { |call| call.result.nil? }
            calls.filter_map(&:result).each(&:destroy)
            tool_call_message.destroy
          end
        end
      end

      def eager_load_messages
        assoc = messages_association
        messages = assoc.to_a
        return messages unless assoc.respond_to?(:klass)

        associations = %i[ruby_llm_tool_calls ruby_llm_parent_tool_call ruby_llm_usages]
        associations << { attachments_attachments: :blob } if attachment_association?(assoc.klass)

        ::ActiveRecord::Associations::Preloader.new(records: messages, associations: associations).call
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
        chat.cancellation_checker = proc { consume_persisted_cancellation_request }
        chat.approval_checker = proc { |tool_call| persisted_tool_call_approval(tool_call) }
        install_persistence_callbacks(chat)
      end

      def record_tool_call_decision(tool_call, decision)
        id = tool_call.respond_to?(:tool_call_id) ? tool_call.tool_call_id : tool_call
        id = id.id if id.respond_to?(:id) && !id.is_a?(String)
        record = find_tool_call(id)
        raise ArgumentError, "Unknown tool call: #{id.inspect}" unless record

        record.update!(approval: decision)
        self
      end

      def persisted_tool_call_approval(tool_call)
        record = find_tool_call(tool_call.id)
        return unless record&.has_attribute?(:approval)

        case record.approval
        when 'approved' then true
        when 'denied' then false
        end
      end

      def sync_messages(chat = @chat)
        message_records = eager_load_messages
        chat.messages = message_records
        linked_entry_pairs = message_records.zip(chat.messages).flat_map do |record, message|
          record.ruby_llm_usages.zip(message.ruby_llm_usage_entries)
        end
        linked_entries = linked_entry_pairs.to_h { |record, entry| [record.id, entry] }
        chat.usage_entries = ruby_llm_usages.map do |record|
          linked_entries.fetch(record.id) { record.to_entry }
        end
        reapply_runtime_instructions(chat)
        chat
      end

      def install_persistence_callbacks(chat)
        chat.before_message { persist_new_message }
        chat.usage_recorder = method(:persist_usage_entry)
        chat.after_message { |msg| persist_message_completion(msg) }
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
          messages_association.create!(role: :system, content: instructions, cache_until_here: cache_until_here)
        end
      end

      # Rewriting the same instructions every turn would move the system row
      # behind the user messages and rebroadcast it each time.
      def update_persisted_system_instruction(record, instructions, cache_until_here:)
        attributes = { content: instructions }
        attributes[:cache_until_here] = cache_until_here if record.has_attribute?(:cache_until_here)
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
              cache_until_here: cache_until_here
            )
          else
            replace_persisted_system_instructions(instructions, cache_until_here:)
          end
        end
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

      def persist_new_message
        @message.destroy if blank_placeholder?

        attrs = { role: :assistant, content: '' }
        @message = messages_association.create!(attrs)
      end

      def blank_placeholder?
        return false unless @message&.persisted? && @message.content.blank?
        return false if @message.respond_to?(:attachments) && @message.attachments.attached?

        !@message.ruby_llm_tool_calls.exists?
      end

      def persist_message_completion(message)
        return unless message

        tool_call = find_tool_call(message.tool_call_id) if message.tool_call_id
        attrs = message_attributes(message)

        transaction do
          @message.assign_attributes(attrs)
          @message.save!
          tool_call&.update!(result: @message)

          persist_content(@message, message.attachments) if message.attachments.any?
          persist_tool_calls(message.tool_calls) if message.tool_calls.present?
          link_usage_entries(message)
        end
      end

      def message_attributes(message)
        attrs = { role: message.role, content: message.content }
        assign_supported_attribute(attrs, :thinking_text, message.thinking&.text)
        assign_supported_attribute(attrs, :thinking_signature, message.thinking&.signature)
        assign_supported_attribute(attrs, :citations, message.citations.map(&:to_h).presence)
        assign_supported_attribute(attrs, :server_tool_calls, message.server_tool_calls.map(&:to_h).presence)
        assign_supported_attribute(attrs, :raw_content, message.raw_content)
        assign_supported_attribute(attrs, :raw_reasoning, message.raw_reasoning)
        assign_supported_attribute(attrs, :finish_reason, message.finish_reason)
        assign_supported_attribute(attrs, :cache_until_here, message.cache_until_here?)
        attrs
      end

      def assign_supported_attribute(attributes, name, value)
        attributes[name] = value if messages_association.klass.column_names.include?(name.to_s)
      end

      def persist_tool_calls(tool_calls, message_record: @message)
        tool_calls.each_value do |tool_call|
          attributes = tool_call.to_h
          attributes[:tool_call_id] = attributes.delete(:id)
          message_record.ruby_llm_tool_calls.create!(**attributes)
        end
      end

      def find_tool_call(tool_call_id)
        RubyLLM::ActiveRecord::ToolCall.find_by(
          tool_call_id: tool_call_id,
          message_type: self.class.message_class.constantize.polymorphic_name,
          message_id: messages_association.select(:id)
        )
      end

      def consume_persisted_cancellation_request
        if self[:cancelled]
          clear_cancellation_request
          return :cancelled
        end
        return unless persisted?
        return unless cancellation_poll_due?
        return unless persisted_cancellation_request?

        clear_cancellation_request
        :cancelled
      end

      # Jobs and requests run with the query cache on, which would replay the
      # first poll's answer for the rest of the run.
      def persisted_cancellation_request?
        self.class.uncached do
          self.class.unscoped.where(self.class.primary_key => id).pick(:cancelled)
        end
      end

      def clear_cancellation_request
        self[:cancelled] = false
        self.class.unscoped.where(self.class.primary_key => id).update_all(cancelled: false) if persisted?
      end

      def cancellation_poll_due?
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return false if @last_cancellation_poll_at && now - @last_cancellation_poll_at < CANCELLATION_POLL_INTERVAL

        @last_cancellation_poll_at = now
        true
      end
    end
  end
end
