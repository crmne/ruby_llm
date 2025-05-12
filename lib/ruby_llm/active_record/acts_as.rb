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

          delegate :add_message,
                   to: :to_llm
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

        # Load existing messages into chat
        messages.each do |msg|
          @chat.add_message(msg.to_llm)
        end

        # Set up message persistence
        @chat.on_new_message { persist_new_message }
             .on_end_message { |msg| persist_message_completion(msg) }
      end

      def with_instructions(instructions, replace: false)
        transaction do
          # If replace is true, remove existing system messages
          messages.where(role: :system).destroy_all if replace

          # Create the new system message
          messages.create!(
            role: :system,
            content: instructions
          )
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
        to_llm.with_model(...)
        self
      end

      def with_temperature(...)
        to_llm.with_temperature(...)
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
        message_record = messages.create!(
          role: :user,
          content: content
        )

        if with.present?
          files = Array(with).reject(&:blank?)

          if files.any? && files.first.is_a?(ActionDispatch::Http::UploadedFile)
            message_record.attachments.attach(files)
          else
            attach_files(message_record, process_attachments(with))
          end
        end

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
        @message = messages.create!(
          role: :assistant,
          content: String.new
        )
      end

      def persist_message_completion(message)
        return unless message

        if message.tool_call_id
          tool_call_id = self.class.tool_call_class.constantize.find_by(tool_call_id: message.tool_call_id)&.id
        end

        transaction do
          @message.update(
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

      def process_attachments(attachments) # rubocop:disable Metrics/PerceivedComplexity
        return {} if attachments.nil?

        result = {}
        files = Array(attachments)

        files.each do |file|
          content_type = if file.respond_to?(:content_type)
                           file.content_type
                         elsif file.is_a?(ActiveStorage::Attachment)
                           file.blob.content_type
                         else
                           RubyLLM::MimeTypes.detect_from_path(file.to_s)
                         end

          if RubyLLM::MimeTypes.image?(content_type)
            result[:image] ||= []
            result[:image] << file
          elsif RubyLLM::MimeTypes.audio?(content_type)
            result[:audio] ||= []
            result[:audio] << file
          else
            # Default to PDF for unknown types
            result[:pdf] ||= []
            result[:pdf] << file
          end
        end

        result
      end

      def attach_files(message, attachments_hash)
        return unless message.respond_to?(:attachments)

        %i[image audio pdf].each do |type|
          Array(attachments_hash[type]).each do |file_source|
            attach_file(message, file_source)
          end
        end
      end

      def attach_file(message, file_source)
        if file_source.to_s.match?(%r{^https?://})
          # For URLs, create a special attachment that just stores the URL
          content_type = RubyLLM::MimeTypes.detect_from_path(file_source.to_s)

          # Create a minimal blob that just stores the URL
          blob = ActiveStorage::Blob.create_and_upload!(
            io: StringIO.new('URL Reference'),
            filename: File.basename(file_source),
            content_type: content_type,
            metadata: { original_url: file_source.to_s }
          )
          message.attachments.attach(blob)
        elsif file_source.respond_to?(:read)
          # Handle various file source types
          message.attachments.attach(
            io: file_source,
            filename: extract_filename(file_source),
            content_type: RubyLLM::MimeTypes.detect_from_path(extract_filename(file_source))
          ) # Already a file-like object
        elsif file_source.is_a?(::ActiveStorage::Attachment)
          # Copy from existing ActiveStorage attachment
          message.attachments.attach(file_source.blob)
        elsif file_source.is_a?(::ActiveStorage::Blob)
          message.attachments.attach(file_source)
        else
          # Local file path
          message.attachments.attach(
            io: File.open(file_source),
            filename: File.basename(file_source),
            content_type: RubyLLM::MimeTypes.detect_from_path(file_source)
          )
        end
      end

      def extract_filename(file)
        file.respond_to?(:original_filename) ? file.original_filename : 'attachment'
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

      def extract_content # rubocop:disable Metrics/PerceivedComplexity
        return content unless respond_to?(:attachments) && attachments.attached?

        content_obj = RubyLLM::Content.new(content)

        # We need to keep tempfiles alive for the duration of the API call
        @_tempfiles = []

        attachments.each do |attachment|
          attachment_data = if attachment.metadata&.key?('original_url')
                              attachment.metadata['original_url']
                            elsif defined?(ActiveJob) && caller.any? { |c| c.include?('active_job') }
                              # We're in a background job - need to download the data
                              temp_file = Tempfile.new([File.basename(attachment.filename.to_s, '.*'),
                                                        File.extname(attachment.filename.to_s)])
                              temp_file.binmode
                              temp_file.write(attachment.download)
                              temp_file.flush
                              temp_file.rewind

                              # Store the tempfile reference in the instance variable to prevent GC
                              @_tempfiles << temp_file

                              # Return the file object itself, not just the path
                              temp_file
                            else
                              blob_path_for(attachment)
                            end

          if RubyLLM::MimeTypes.image?(attachment.content_type)
            content_obj.add_image(attachment_data)
          elsif RubyLLM::MimeTypes.audio?(attachment.content_type)
            content_obj.add_audio(attachment_data)
          elsif RubyLLM::MimeTypes.pdf?(attachment.content_type)
            content_obj.add_pdf(attachment_data)
          end
        end

        content_obj
      end

      private

      def blob_path_for(attachment)
        if Rails.application.routes.url_helpers.respond_to?(:rails_blob_path)
          Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)
        else
          attachment.service_url
        end
      end
    end
  end
end
