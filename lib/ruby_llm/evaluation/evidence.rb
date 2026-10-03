# frozen_string_literal: true

module RubyLLM
  class Evaluation
    class Evidence # :nodoc:
      FIELDS = {
        Embedding => %i[model vectors sparse_vectors],
        Transcription => %i[model text language duration segments words],
        OCR => %i[model markdown pages],
        Rerank => %i[model results],
        Moderation => %i[model results],
        Moderation::Result => %i[flagged? categories category_scores],
        Tokenization => %i[model ids],
        ServerToolCall => %i[type name id input result]
      }.freeze

      attr_reader :output, :messages, :tool_calls, :attachments, :data

      def initialize(result, adapters: {})
        @adapters = adapters
        @attachments = []
        conversation = result.is_a?(Agent) ? result.chat : result
        conversation = conversation.to_llm if conversation.respond_to?(:to_llm)
        @messages = case conversation
                    when Chat then conversation.messages.dup
                    when Message then [conversation]
                    else []
                    end.freeze
        @tool_calls = messages.flat_map { |message| Array(message.tool_calls&.values) }
        @tool_calls << result if result.is_a?(ToolCall)
        @tool_calls.freeze
        @output = primary_output(conversation, result)
        @data = Judge::Data.copy(serialize(conversation))
      end

      def serialize(value, ancestors = [])
        return Judge::Data.copy(value) if scalar?(value)

        raise ArgumentError, 'Evaluation evidence contains a cycle' if ancestors.any? { |item| item.equal?(value) }

        parents = [*ancestors, value]
        adapter = @adapters.find { |type, _| value.is_a?(type) }&.last
        return serialize(adapter.call(value), parents) if adapter

        serialize_value(value, parents)
      end

      private

      def serialize_value(value, parents)
        case value
        when Agent then serialize(value.chat, parents)
        when Chat then conversation_data(value, parents)
        when Message then message_data(value, parents)
        when ToolCall then serialize(value.to_h.except(:thought_signature), parents)
        when Image, Video, Speech then media_data(value)
        when Attachment then attachment_data(value)
        when Hash then serialize_hash(value, parents)
        when Array then value.map { |item| serialize(item, parents) }
        else serialize_object(value, parents)
        end
      end

      def scalar?(value)
        [String, Symbol, Numeric, TrueClass, FalseClass, NilClass].any? { |type| value.is_a?(type) }
      end

      def serialize_hash(value, parents)
        names = value.keys.map(&:to_s)
        raise ArgumentError, 'Duplicate evaluation evidence keys' unless names.uniq.size == names.size

        value.to_h do |key, item|
          [key.is_a?(Integer) ? key.to_s : key, serialize(item, parents)]
        end
      end

      def serialize_object(value, parents)
        fields = FIELDS.find { |type, _| value.is_a?(type) }&.last
        if fields
          return serialize(fields.to_h { |field| [field.to_s.delete_suffix('?'), value.public_send(field)] }, parents)
        end
        return serialize(value.to_h, parents) if value.respond_to?(:to_h)

        raise ArgumentError, "Cannot evaluate #{value.class}; declare an adapter with adapt"
      end

      def primary_output(conversation, result)
        case conversation
        when Chat then messages.reverse.find { |message| message.role == :assistant }&.content
        when Message then conversation.content
        else result
        end
      end

      def conversation_data(chat, parents)
        answer = chat.messages.reverse.find { |message| message.role == :assistant }&.content
        { output: answer, messages: serialize(chat.messages, parents), complete: chat.complete?, waiting: chat.waiting?,
          pending_approvals: chat.pending_approvals.map(&:id), cancelled: chat.cancelled?, model: chat.model.id }
      end

      def message_data(message, parents)
        { role: message.role, content: message.content, model: message.model, finish_reason: message.finish_reason,
          tool_calls: serialize(message.tool_calls, parents), tool_call_id: message.tool_call_id,
          citations: serialize(message.citations, parents),
          server_tool_calls: serialize(message.server_tool_calls, parents),
          attachments: message.attachments.map { |attachment| attachment_data(attachment) } }
      end

      def attachment_data(attachment)
        @attachments << attachment
        { attachment: @attachments.length, filename: attachment.filename, content_type: attachment.mime_type }
      end

      def media_data(media)
        data = media.data
        data = Base64.strict_encode64(data) if data && !media.is_a?(Image)
        source = data ? "data:#{media.mime_type};base64,#{data}" : media.url
        raise ArgumentError, 'Media result has no content' unless source

        @attachments << source
        { attachment: @attachments.length, content_type: media.mime_type, model: media.model }
      end
    end
  end
end
