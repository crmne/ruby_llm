# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Adds chat and message persistence capabilities to ActiveRecord models.
    # Provides a clean interface for storing chat history, message metadata,
    # and attachments in your database.
    module ActsAs
      extend ActiveSupport::Concern

      class_methods do # rubocop:disable Metrics/BlockLength
        def acts_as_chat(message_class: 'Message', tool_call_class: 'ToolCall')
          include ChatMethods

          @message_class = message_class.to_s
          @tool_call_class = tool_call_class.to_s

          has_many :messages,
                   -> { order(created_at: :asc) },
                   class_name: @message_class,
                   dependent: :destroy

          delegate :add_message, to: :to_llm
        end

        def acts_as_message(chat_class: 'Chat',
                            chat_foreign_key: nil,
                            tool_call_class: 'ToolCall',
                            tool_call_foreign_key: nil,
                            touch_chat: false)
          include MessageMethods

          @chat_class = chat_class.to_s
          @chat_foreign_key = chat_foreign_key || ActiveSupport::Inflector.foreign_key(@chat_class)

          @tool_call_class = tool_call_class.to_s
          @tool_call_foreign_key = tool_call_foreign_key || ActiveSupport::Inflector.foreign_key(@tool_call_class)

          belongs_to :chat,
                     class_name: @chat_class,
                     foreign_key: @chat_foreign_key,
                     inverse_of: :messages,
                     touch: touch_chat

          has_many :tool_calls,
                   class_name: @tool_call_class,
                   dependent: :destroy

          belongs_to :parent_tool_call,
                     class_name: @tool_call_class,
                     foreign_key: @tool_call_foreign_key,
                     optional: true,
                     inverse_of: :result

          delegate :tool_call?, :tool_result?, :tool_results, to: :to_llm
        end

        def acts_as_tool_call(message_class: 'Message', message_foreign_key: nil, result_foreign_key: nil)
          @message_class = message_class.to_s
          @message_foreign_key = message_foreign_key || ActiveSupport::Inflector.foreign_key(@message_class)
          @result_foreign_key = result_foreign_key || ActiveSupport::Inflector.foreign_key(name)

          belongs_to :message,
                     class_name: @message_class,
                     foreign_key: @message_foreign_key,
                     inverse_of: :tool_calls

          has_one :result,
                  class_name: @message_class,
                  foreign_key: @result_foreign_key,
                  inverse_of: :parent_tool_call,
                  dependent: :nullify
        end
      end
    end

    # Methods mixed into chat models to handle message persistence and
    # provide a conversation interface.
    module ChatMethods
      extend ActiveSupport::Concern

      class_methods do
        attr_reader :tool_call_class
      end

      def to_llm
        @chat ||= RubyLLM.chat(model: model_id)
        @chat.reset_messages!

        messages.each do |msg|
          @chat.add_message(msg.to_llm)
        end

        @chat.on_new_message { persist_new_message }
             .on_end_message { |msg| persist_message_completion(msg) }
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

      def with_model(...)
        update(model_id: to_llm.with_model(...).model.id)
        self
      end

      def with_temperature(...)
        to_llm.with_temperature(...)
        self
      end

      def with_context(...)
        to_llm.with_context(...)
        self
      end

      def on_new_message(...)
        to_llm.on_new_message(...)
        self
      end

      def on_end_message(...)
        to_llm.on_end_message(...)
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
        if @message&.persisted? && @message.content.blank?
          RubyLLM.logger.debug "RubyLLM: API call failed, destroying message: #{@message.id}"
          @message.destroy
        end
        raise e
      end

      private

      def persist_new_message
        @message = messages.create!(role: :assistant, content: String.new)
      end

      def persist_message_completion(message)
        return unless message

        tool_call_id = find_tool_call_id(message.tool_call_id) if message.tool_call_id

        transaction do
          @message.update!(
            role: message.role,
            content: message.content,
            model_id: message.model_id,
            input_tokens: message.input_tokens,
            output_tokens: message.output_tokens
          )
          @message.write_attribute(@message.class.tool_call_foreign_key, tool_call_id) if tool_call_id
          @message.save!
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

        # Let RubyLLM::Attachment handle the heavy lifting
        attachment = RubyLLM::Attachment.new(source)

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

    # Methods mixed into message models to handle serialization and
    # provide a clean interface to the underlying message data.
    module MessageMethods
      extend ActiveSupport::Concern

      class_methods do
        attr_reader :chat_class, :tool_call_class, :chat_foreign_key, :tool_call_foreign_key
      end

      def to_llm
        RubyLLM::Message.new(
          role: role.to_sym,
          content: extract_content,
          tool_calls: extract_tool_calls,
          tool_call_id: extract_tool_call_id,
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          model_id: model_id
        )
      end

      private

      def extract_tool_calls
        tool_calls.to_h do |tool_call|
          [
            tool_call.tool_call_id,
            RubyLLM::ToolCall.new(
              id: tool_call.tool_call_id,
              name: tool_call.name,
              arguments: tool_call.arguments
            )
          ]
        end
      end

      def extract_tool_call_id
        parent_tool_call&.tool_call_id
      end

      def extract_content
        return content unless respond_to?(:attachments) && attachments.attached?

        RubyLLM::Content.new(content).tap do |content_obj|
          @_tempfiles = []

          attachments.each do |attachment|
            tempfile = download_attachment(attachment)
            content_obj.add_attachment(tempfile, filename: attachment.filename.to_s)
          end
        end
      end

      def download_attachment(attachment)
        ext = File.extname(attachment.filename.to_s)
        basename = File.basename(attachment.filename.to_s, ext)
        tempfile = Tempfile.new([basename, ext])
        tempfile.binmode

        attachment.download { |chunk| tempfile.write(chunk) }

        tempfile.flush
        tempfile.rewind
        @_tempfiles << tempfile
        tempfile
      end
    end
  end
end
