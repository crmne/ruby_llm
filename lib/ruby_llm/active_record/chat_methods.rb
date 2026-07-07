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
    #   chat = Chat.create!(model: 'gpt-5-nano')
    #   chat.ask "What is the capital of France?"
    #   chat.messages.count # => 2
    #
    module ChatMethods
      extend ActiveSupport::Concern
      include AttachmentHelpers

      included do
        before_save :resolve_model_from_strings
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

      def messages_association # :nodoc:
        send(messages_association_name)
      end

      def model_association # :nodoc:
        send(model_association_name)
      end

      def model_association=(value) # :nodoc:
        send("#{model_association_name}=", value)
      end

      # Sets the chat's model. A String is resolved to a model record before
      # save; a model record is assigned directly.
      #
      #   chat.model = 'gpt-5-nano'
      #
      def model=(value)
        if value.is_a?(String)
          @model_string = value
        elsif self.class.model_association_name == :model
          super
        else
          self.model_association = value
        end
      end

      # Stores +value+ as the model id, resolved to a model record before save.
      def model_id=(value)
        @model_string = value
      end

      # Returns the model id of the associated model record, or +nil+.
      #
      #   chat.model_id # => "gpt-5-nano"
      #
      def model_id
        model_association&.model_id
      end

      # Stores +value+ as the provider used when resolving the model id
      # before save.
      def provider=(value)
        @provider_string = value
      end

      # Returns the provider of the associated model record, or +nil+.
      def provider
        model_association&.provider
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

      # Sets the system instructions, persisting them as a message with the
      # +:system+ role. Replaces any persisted system messages unless
      # +append:+ is true. Returns +self+.
      #
      #   chat.with_instructions "You are a Ruby expert."
      #   chat.with_instructions "Use short bullet points.", append: true
      #
      def with_instructions(instructions, append: false)
        raise ArgumentError, 'To remove instructions, use without_instructions' if instructions.nil?

        persist_system_instruction(instructions, append:)

        to_llm.with_instructions(instructions, append:)
        self
      end

      # Deletes the persisted system messages and removes them from the
      # underlying chat. Returns +self+.
      def without_instructions
        clear_persisted_system_instructions
        to_llm.without_instructions
        self
      end

      def with_runtime_instructions(instructions, append: false) # :nodoc:
        if instructions.nil?
          @runtime_instructions = []
          sync_messages if @chat
          return self
        end

        store_runtime_instruction(instructions, append:)

        to_llm.with_instructions(instructions, append:)
        self
      end

      # Registers tools the model may call during the conversation. See
      # RubyLLM::Chat#with_tools. Returns +self+.
      #
      #   chat.with_tools Weather
      #
      def with_tools(...)
        to_llm.with_tools(...)
        self
      end

      # Removes all registered tools, leaving the tool options unchanged.
      # See RubyLLM::Chat#without_tools. Returns +self+.
      def without_tools
        to_llm.without_tools
        self
      end

      # Configures how the model uses the registered tools. See
      # RubyLLM::Chat#with_tool_options. Returns +self+.
      #
      #   chat.with_tools(Weather).with_tool_options(choice: :required)
      #
      def with_tool_options(...)
        to_llm.with_tool_options(...)
        self
      end

      # Resets the options set with #with_tool_options. See
      # RubyLLM::Chat#without_tool_options. Returns +self+.
      def without_tool_options
        to_llm.without_tool_options
        self
      end

      # Switches the chat to +model_name+, resolving and saving the model
      # record and updating the underlying chat. Falls back to the configured
      # default model when +model_name+ is +nil+. Pass +protocol:+ to override
      # the wire protocol the provider would pick for the model. Returns +self+.
      #
      #   chat.with_model 'claude-sonnet-4-6'
      #
      def with_model(model_name, provider: nil, protocol: nil, assume_model_exists: false)
        model_name ||= (context&.config || RubyLLM.config).default_model
        self.model = model_name
        self.provider = provider if provider
        self.protocol = protocol
        self.assume_model_exists = assume_model_exists
        resolve_model_from_strings
        save!
        to_llm.with_model(model_association.model_id, provider: model_association.provider.to_sym,
                                                      protocol:, assume_model_exists:)
        self
      end

      # Sets fallback models tried in order when the primary model fails.
      # Not persisted; reapply after reloading the record. See
      # RubyLLM::Chat#with_fallbacks. Returns +self+.
      #
      #   chat.with_fallbacks 'gpt-4.1-mini', 'claude-haiku-4-5'
      #
      def with_fallbacks(...)
        to_llm.with_fallbacks(...)
        self
      end

      # Removes all fallback models from the underlying chat. See
      # RubyLLM::Chat#without_fallbacks. Returns +self+.
      def without_fallbacks
        to_llm.without_fallbacks
        self
      end

      # Sets the sampling temperature on the underlying chat. See
      # RubyLLM::Chat#with_temperature. Returns +self+.
      def with_temperature(...)
        to_llm.with_temperature(...)
        self
      end

      # Caps the number of tokens the model may generate. See
      # RubyLLM::Chat#with_max_output_tokens. Returns +self+.
      def with_max_output_tokens(...)
        to_llm.with_max_output_tokens(...)
        self
      end

      # Removes the output token limit from the underlying chat. See
      # RubyLLM::Chat#without_max_output_tokens. Returns +self+.
      def without_max_output_tokens
        to_llm.without_max_output_tokens
        self
      end

      # Removes the temperature override from the underlying chat. See
      # RubyLLM::Chat#without_temperature. Returns +self+.
      def without_temperature
        to_llm.without_temperature
        self
      end

      # Configures extended thinking on the underlying chat. See
      # RubyLLM::Chat#with_thinking. Returns +self+.
      def with_thinking(...)
        to_llm.with_thinking(...)
        self
      end

      # Clears the thinking configuration on the underlying chat. See
      # RubyLLM::Chat#without_thinking. Returns +self+.
      def without_thinking
        to_llm.without_thinking
        self
      end

      # Enables citations on the underlying chat. See
      # RubyLLM::Chat#with_citations. Returns +self+.
      def with_citations
        to_llm.with_citations
        self
      end

      # Disables citations on the underlying chat. See
      # RubyLLM::Chat#without_citations. Returns +self+.
      def without_citations
        to_llm.without_citations
        self
      end

      # Configures prompt caching on the underlying chat. See
      # RubyLLM::Chat#with_caching. Returns +self+.
      def with_caching(...)
        to_llm.with_caching(...)
        self
      end

      # Disables prompt caching on the underlying chat. See
      # RubyLLM::Chat#without_caching. Returns +self+.
      def without_caching
        to_llm.without_caching
        self
      end

      # Sets options in the provider's request vocabulary on the underlying
      # chat. See RubyLLM::Chat#with_provider_options. Returns +self+.
      def with_provider_options(...)
        to_llm.with_provider_options(...)
        self
      end

      # Removes all provider request options from the underlying chat. See
      # RubyLLM::Chat#without_provider_options. Returns +self+.
      def without_provider_options
        to_llm.without_provider_options
        self
      end

      # Sets custom HTTP headers on the underlying chat. See
      # RubyLLM::Chat#with_headers. Returns +self+.
      def with_headers(...)
        to_llm.with_headers(...)
        self
      end

      # Removes all custom HTTP headers from the underlying chat. See
      # RubyLLM::Chat#without_headers. Returns +self+.
      def without_headers
        to_llm.without_headers
        self
      end

      # Sets a schema for structured output. See RubyLLM::Chat#with_schema.
      # Returns +self+.
      #
      #   chat.with_schema(PersonSchema).ask "Generate a person from Paris"
      #
      def with_schema(...)
        to_llm.with_schema(...)
        self
      end

      # Removes the structured output schema from the underlying chat. See
      # RubyLLM::Chat#without_schema. Returns +self+.
      def without_schema
        to_llm.without_schema
        self
      end

      # Registers a callback run before each new message is appended to the
      # conversation. See RubyLLM::Chat#before_message. Returns +self+.
      def before_message(...)
        to_llm.before_message(...)
        self
      end

      # Registers a callback run with each message once it has been appended,
      # including assistant responses and tool results. See
      # RubyLLM::Chat#after_message. Returns +self+.
      def after_message(...)
        to_llm.after_message(...)
        self
      end

      # Registers a callback run before each tool call executes.
      # See RubyLLM::Chat#before_tool_call. Returns +self+.
      def before_tool_call(...)
        to_llm.before_tool_call(...)
        self
      end

      # Registers a callback run after each tool call returns its result.
      # See RubyLLM::Chat#after_tool_result. Returns +self+.
      def after_tool_result(...)
        to_llm.after_tool_result(...)
        self
      end

      # Registers a callback run before a fallback model is tried.
      # See RubyLLM::Chat#before_fallback. Returns +self+.
      def before_fallback(...)
        to_llm.before_fallback(...)
        self
      end

      # Registers a callback run after a fallback attempt finishes.
      # See RubyLLM::Chat#after_fallback. Returns +self+.
      def after_fallback(...)
        to_llm.after_fallback(...)
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

        attrs = { role: llm_message.role, content: llm_message.content }
        add_finish_reason_attribute(attrs, llm_message, messages_association.klass)
        attrs[:cache_until_here] = llm_message.cache_until_here?
        parent_tool_call_assoc = messages_association.klass.reflect_on_association(:parent_tool_call)
        if parent_tool_call_assoc && llm_message.tool_call_id
          tool_call_id = find_tool_call_id(llm_message.tool_call_id)
          attrs[parent_tool_call_assoc.foreign_key] = tool_call_id if tool_call_id
        end

        message_record = messages_association.create!(attrs)

        persist_content(message_record, llm_message.attachments) if llm_message.attachments.any?
        persist_tool_calls(llm_message.tool_calls, message_record:) if llm_message.tool_calls.present?

        @chat.messages << llm_message if @chat

        message_record
      end

      # Marks the latest persisted message as a prompt cache boundary, or the
      # latest in-memory message when none is persisted yet. Returns +self+.
      #
      #   chat.with_instructions('Reusable analysis prompt').cache_until_here!
      #
      # Raises ArgumentError if the chat has no messages.
      def cache_until_here!
        message_record = messages_association.order(:id).last
        if message_record
          message_record.cache_until_here!
        elsif @chat&.messages&.any?
          @chat.cache_until_here!
        else
          raise ArgumentError, 'No messages to cache'
        end

        self
      end

      # Returns a RubyLLM::Cost aggregating the costs of every persisted
      # message.
      #
      #   chat.cost.total
      #
      def cost
        RubyLLM::Cost.aggregate(messages_association.map(&:cost))
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
        add_message(role: :user, content: message, attachments: with)
        self
      end

      # Makes a single model call, persists the response, and returns it as a
      # RubyLLM::Message. Tool calls in the response are not executed. See
      # RubyLLM::Chat#generate.
      def generate(...)
        to_llm.generate(...)
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
      rescue RubyLLM::Error => e
        cleanup_failed_messages if @message&.persisted? && @message.content.blank?
        cleanup_orphaned_tool_results
        raise e
      end

      private

      def resolve_model_from_strings
        config = context&.config || RubyLLM.config
        @model_string ||= config.default_model unless model_association
        return unless @model_string

        model_info, _provider = Models.resolve(
          @model_string,
          provider: @provider_string,
          assume_model_exists: assume_model_exists || false,
          config: config
        )

        self.model_association = find_or_create_model_record(model_info)
        @model_string = nil
        @provider_string = nil
      end

      def cleanup_failed_messages
        RubyLLM.logger.warn "RubyLLM: API call failed, destroying message: #{@message.id}"
        @message.destroy
      end

      def cleanup_orphaned_tool_results # rubocop:disable Metrics/PerceivedComplexity
        messages_association.reload
        last = eager_load_messages.max_by(&:id)

        return unless last&.tool_call? || last&.tool_result?

        if last.tool_call?
          last.destroy
        elsif last.tool_result?
          tool_call_message = last.parent_tool_call.message_association
          expected_results = tool_call_message.tool_calls_association.pluck(:id)
          fk_column = tool_call_message.class.reflections['tool_results'].foreign_key
          actual_results = tool_call_message.tool_results.pluck(fk_column)

          if expected_results.sort != actual_results.sort
            tool_call_message.tool_results.each(&:destroy)
            tool_call_message.destroy
          end
        end
      end

      def eager_load_messages
        assoc = messages_association
        messages = assoc.to_a
        return messages unless assoc.respond_to?(:klass)

        msg_class = assoc.klass
        associations = [
          msg_class.tool_calls_association_name,
          :parent_tool_call,
          msg_class.model_association_name
        ].compact

        ::ActiveRecord::Associations::Preloader.new(records: messages, associations: associations).call
        messages
      end

      def find_or_create_model_record(model_info)
        model_class = self.class.model_class.constantize
        model_class.find_or_create_by!(
          model_id: model_info.id,
          provider: model_info.provider
        ) do |m|
          m.name = model_info.name || model_info.id
          m.family = model_info.family
          m.context_window = model_info.context_window
          m.max_output_tokens = model_info.max_output_tokens
          m.capabilities = model_info.capabilities || []
          m.modalities = model_info.modalities.to_h
          m.pricing = model_info.pricing.to_h
          m.metadata = model_info.metadata || {}
        end
      end

      def current_llm_model_association(_message = nil)
        model_info = @chat&.model

        model_info ? find_or_create_model_record(model_info) : model_association
      end

      def build_llm_chat
        model_record = model_association
        chat = (context || RubyLLM).chat(
          model: model_record.model_id,
          provider: model_record.provider.to_sym,
          protocol: protocol,
          assume_model_exists: assume_model_exists || false
        )
        sync_messages(chat)
        install_persistence_callbacks(chat)
      end

      def sync_messages(chat = @chat)
        chat.messages = eager_load_messages
        reapply_runtime_instructions(chat)
        chat
      end

      def install_persistence_callbacks(chat)
        chat.before_message { persist_new_message }
        chat.after_message { |msg| persist_message_completion(msg) }
        chat
      end

      def clear_persisted_system_instructions
        association = messages_association
        association.where(role: :system).destroy_all
        association.reset
      end

      def replace_persisted_system_instructions(instructions)
        clear_persisted_system_instructions
        messages_association.create!(role: :system, content: instructions)
      end

      def persist_system_instruction(instructions, append:)
        transaction do
          if append
            messages_association.create!(role: :system, content: instructions)
          else
            replace_persisted_system_instructions(instructions)
          end
        end
      end

      def runtime_instructions
        @runtime_instructions ||= []
      end

      def store_runtime_instruction(instructions, append:)
        if append
          runtime_instructions << instructions
        else
          @runtime_instructions = [instructions]
        end
      end

      def reapply_runtime_instructions(chat)
        return if runtime_instructions.empty?

        first, *rest = runtime_instructions
        chat.with_instructions(first)
        rest.each { |instruction| chat.with_instructions(instruction, append: true) }
      end

      def persist_new_message
        @message.destroy if @message&.persisted? && @message.content.blank? && !@message.tool_calls_association.exists?

        attrs = { role: :assistant, content: '' }
        attrs[self.class.model_association_name] = current_llm_model_association
        @message = messages_association.create!(attrs)
      end

      def persist_message_completion(message)
        return unless message

        tool_call_id = find_tool_call_id(message.tool_call_id) if message.tool_call_id
        attrs = completion_attributes(message, message.content, tool_call_id)

        transaction do
          @message.assign_attributes(attrs)
          @message.save!

          persist_content(@message, message.attachments) if message.attachments.any?
          persist_tool_calls(message.tool_calls) if message.tool_calls.present?
        end
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def completion_attributes(message, content_text, tool_call_id)
        attrs = { role: message.role, content: content_text,
                  input_tokens: message.input_tokens, output_tokens: message.output_tokens }
        attrs[:cache_read_tokens] = message.cache_read_tokens if @message.has_attribute?(:cache_read_tokens)
        attrs[:cache_write_tokens] = message.cache_write_tokens if @message.has_attribute?(:cache_write_tokens)
        attrs[:thinking_text] = message.thinking&.text if @message.has_attribute?(:thinking_text)
        attrs[:thinking_signature] = message.thinking&.signature if @message.has_attribute?(:thinking_signature)
        attrs[:thinking_tokens] = message.thinking_tokens if @message.has_attribute?(:thinking_tokens)
        attrs[:citations] = message.citations.map(&:to_h).presence if @message.has_attribute?(:citations)
        attrs[:finish_reason] = message.finish_reason if @message.has_attribute?(:finish_reason)
        attrs[:cache_until_here] = message.cache_until_here? if @message.has_attribute?(:cache_until_here)
        model_record = current_llm_model_association(message)
        attrs[self.class.model_association_name] = model_record
        merge_cost_attributes(attrs, message, model_record)
        if tool_call_id
          parent_tool_call_assoc = @message.class.reflect_on_association(:parent_tool_call)
          attrs[parent_tool_call_assoc.foreign_key] = tool_call_id
        end
        attrs
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def merge_cost_attributes(attrs, message, model_record)
        return unless @message.has_attribute?(:total_cost) || @message.has_attribute?(:cost_details)

        cost = RubyLLM::Cost.new(tokens: message.tokens, model: model_record)
        attrs[:total_cost] = cost.total if @message.has_attribute?(:total_cost)
        attrs[:cost_details] = cost.to_h.presence if @message.has_attribute?(:cost_details)
      end

      def persist_tool_calls(tool_calls, message_record: @message)
        tool_call_klass = message_record.tool_calls_association.klass
        supports_thought_signature = tool_call_klass.column_names.include?('thought_signature')

        tool_calls.each_value do |tool_call|
          attributes = tool_call.to_h
          attributes.delete(:thought_signature) unless supports_thought_signature
          attributes[:tool_call_id] = attributes.delete(:id)
          message_record.tool_calls_association.create!(**attributes)
        end
      end

      def add_finish_reason_attribute(attrs, message, message_class)
        return unless message_class.column_names.include?('finish_reason')

        attrs[:finish_reason] = message.finish_reason
      end

      def find_tool_call_id(tool_call_id)
        messages = messages_association
        message_class = messages.klass
        tool_calls_assoc = message_class.tool_calls_association_name
        tool_call_table_name = message_class.reflect_on_association(tool_calls_assoc).table_name

        message_with_tool_call = messages.joins(tool_calls_assoc)
                                         .find_by(tool_call_table_name => { tool_call_id: tool_call_id })
        return nil unless message_with_tool_call

        tool_call = message_with_tool_call.tool_calls_association.find_by(tool_call_id: tool_call_id)
        tool_call&.id
      end
    end
  end
end
