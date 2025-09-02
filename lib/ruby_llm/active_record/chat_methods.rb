# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Methods mixed into chat models.
    module ChatMethods
      extend ActiveSupport::Concern

      included do
        before_save :resolve_model_from_strings
      end

      class_methods do
        attr_reader :tool_call_class, :model_class
      end

      attr_accessor :assume_model_exists, :context

      def model=(value)
        @model_string = value if value.is_a?(String)
        super unless value.is_a?(String)
      end

      def model_id=(value)
        @model_string = value
      end

      def model_id
        model&.model_id
      end

      def provider=(value)
        @provider_string = value
      end

      def provider
        model&.provider
      end

      private

      def resolve_model_from_strings # rubocop:disable Metrics/PerceivedComplexity
        return unless @model_string

        model_info, _provider = Models.resolve(
          @model_string,
          provider: @provider_string,
          assume_exists: assume_model_exists || false,
          config: context&.config || RubyLLM.config
        )

        model_class = self.class.model_class.constantize
        model_record = model_class.find_or_create_by!(
          model_id: model_info.id,
          provider: model_info.provider
        ) do |m|
          m.name = model_info.name || model_info.id
          m.family = model_info.family
          m.context_window = model_info.context_window
          m.max_output_tokens = model_info.max_output_tokens
          m.capabilities = model_info.capabilities || []
          m.modalities = model_info.modalities || {}
          m.pricing = model_info.pricing || {}
          m.metadata = model_info.metadata || {}
        end

        self.model = model_record
        @model_string = nil
        @provider_string = nil
      end

      public

      def to_llm
        raise 'No model specified' unless model

        @chat ||= (context || RubyLLM).chat(
          model: model.model_id,
          provider: model.provider.to_sym
        )
        @chat.reset_messages!

        messages.each do |msg|
          @chat.add_message(msg.to_llm)
        end

        setup_persistence_callbacks
      end

      def with_instructions(instructions, replace: false)
        transaction do
          messages.where(role: :system).destroy_all if replace
          messages.create!(role: :system, content: instructions)
        end
        to_llm.with_instructions(instructions)
        self
      end

      def with_tool(...)
        to_llm.with_tool(...)
        self
      end

      def with_tools(...)
        to_llm.with_tools(...)
        self
      end

      def with_model(model_name, provider: nil)
        self.provider = provider if provider
        self.model = model_name
        resolve_model_from_strings
        save!
        to_llm.with_model(model.model_id, provider: model.provider.to_sym)
        self
      end

      def with_temperature(...)
        to_llm.with_temperature(...)
        self
      end

      def with_params(...)
        to_llm.with_params(...)
        self
      end

      def with_headers(...)
        to_llm.with_headers(...)
        self
      end

      def with_schema(...)
        to_llm.with_schema(...)
        self
      end

      def on_new_message(&block)
        to_llm

        existing_callback = @chat.instance_variable_get(:@on)[:new_message]

        @chat.on_new_message do
          existing_callback&.call
          block&.call
        end
        self
      end

      def on_end_message(&block)
        to_llm

        existing_callback = @chat.instance_variable_get(:@on)[:end_message]

        @chat.on_end_message do |msg|
          existing_callback&.call(msg)
          block&.call(msg)
        end
        self
      end

      def on_tool_call(...)
        to_llm.on_tool_call(...)
        self
      end

      def on_tool_result(...)
        to_llm.on_tool_result(...)
        self
      end

      def create_user_message(content, with: nil)
        message_record = messages.create!(role: :user, content: content)
        persist_content(message_record, with) if with.present?
        message_record
      end

      def ask(message, with: nil, &)
        create_user_message(message, with:)
        complete(&)
      end

      alias say ask

      def complete(...)
        to_llm.complete(...)
      rescue RubyLLM::Error => e
        cleanup_failed_messages if @message&.persisted? && @message.content.blank?
        cleanup_orphaned_tool_results
        raise e
      end

      private

      def cleanup_failed_messages
        RubyLLM.logger.warn "RubyLLM: API call failed, destroying message: #{@message.id}"
        @message.destroy
      end

      def cleanup_orphaned_tool_results # rubocop:disable Metrics/PerceivedComplexity
        messages.reload
        last = messages.order(:id).last

        return unless last&.tool_call? || last&.tool_result?

        if last.tool_call?
          last.destroy
        elsif last.tool_result?
          tool_call_message = last.parent_tool_call.message
          expected_results = tool_call_message.tool_calls.pluck(:id)
          actual_results = tool_call_message.tool_results.pluck(:tool_call_id)

          if expected_results.sort != actual_results.sort
            tool_call_message.tool_results.each(&:destroy)
            tool_call_message.destroy
          end
        end
      end

      def setup_persistence_callbacks
        return @chat if @chat.instance_variable_get(:@_persistence_callbacks_setup)

        @chat.on_new_message { persist_new_message }
        @chat.on_end_message { |msg| persist_message_completion(msg) }

        @chat.instance_variable_set(:@_persistence_callbacks_setup, true)
        @chat
      end

      def persist_new_message
        @message = messages.create!(role: :assistant, content: '')
      end

      def persist_message_completion(message) # rubocop:disable Metrics/PerceivedComplexity
        return unless message

        tool_call_id = find_tool_call_id(message.tool_call_id) if message.tool_call_id

        transaction do
          content = message.content
          attachments_to_persist = nil

          if content.is_a?(RubyLLM::Content)
            attachments_to_persist = content.attachments if content.attachments.any?
            content = content.text
          elsif content.is_a?(Hash) || content.is_a?(Array)
            content = content.to_json
          end

          @message.update!(
            role: message.role,
            content: content,
            model: model,
            input_tokens: message.input_tokens,
            output_tokens: message.output_tokens
          )
          @message.write_attribute(@message.class.tool_call_foreign_key, tool_call_id) if tool_call_id
          @message.save!

          persist_content(@message, attachments_to_persist) if attachments_to_persist
          persist_tool_calls(message.tool_calls) if message.tool_calls.present?
        end
      end

      def persist_tool_calls(tool_calls)
        tool_calls.each_value do |tool_call|
          attributes = tool_call.to_h
          attributes[:tool_call_id] = attributes.delete(:id)
          @message.tool_calls.create!(**attributes)
        end
      end

      def find_tool_call_id(tool_call_id)
        self.class.tool_call_class.constantize.find_by(tool_call_id: tool_call_id)&.id
      end

      def persist_content(message_record, attachments)
        return unless message_record.respond_to?(:attachments)

        attachables = prepare_for_active_storage(attachments)
        message_record.attachments.attach(attachables) if attachables.any?
      end

      def prepare_for_active_storage(attachments)
        Utils.to_safe_array(attachments).filter_map do |attachment|
          case attachment
          when ActionDispatch::Http::UploadedFile, ActiveStorage::Blob
            attachment
          when ActiveStorage::Attached::One, ActiveStorage::Attached::Many
            attachment.blobs
          when Hash
            attachment.values.map { |v| prepare_for_active_storage(v) }
          else
            convert_to_active_storage_format(attachment)
          end
        end.flatten.compact
      end

      def convert_to_active_storage_format(source)
        return if source.blank?

        attachment = source.is_a?(RubyLLM::Attachment) ? source : RubyLLM::Attachment.new(source)

        {
          io: StringIO.new(attachment.content),
          filename: attachment.filename,
          content_type: attachment.mime_type
        }
      rescue StandardError => e
        RubyLLM.logger.warn "Failed to process attachment #{source}: #{e.message}"
        nil
      end
    end
  end
end
