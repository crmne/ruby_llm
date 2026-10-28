# frozen_string_literal: true

module RubyLLM
  class OpenTelemetry
    # The opt-in content attributes, in the GenAI semantic conventions'
    # message format. Attachments are described, never sent as bytes.
    module Content # :nodoc:
      module_function

      def request(operation, payload)
        case operation
        when 'chat' then chat_request(payload[:input_messages] || [])
        when 'execute_tool' then { 'gen_ai.tool.call.arguments' => json(payload[:tool_arguments]) }
        else {}
        end.compact
      end

      def response(operation, payload)
        case operation
        when 'chat' then chat_response(payload[:response])
        when 'execute_tool' then { 'gen_ai.tool.call.result' => json(payload[:result]) }
        else {}
        end.compact
      end

      def chat_request(messages)
        system, conversation = messages.partition { |message| message.role == :system }
        {
          'gen_ai.system_instructions' => (json(system.flat_map { |message| parts(message) }) if system.any?),
          'gen_ai.input.messages' => (json(conversation.map { |message| message(message) }) if conversation.any?)
        }
      end

      def chat_response(response)
        return {} unless response.is_a?(Message)

        output = message(response)
        output[:finish_reason] = response.finish_reason.to_s if response.finish_reason
        { 'gen_ai.output.messages' => json([output]) }
      end

      def message(message)
        { role: message.role.to_s, parts: parts(message) }
      end

      def parts(message)
        return [tool_response(message)] if message.role == :tool

        thinking = message.thinking&.text
        [
          ({ type: 'reasoning', content: thinking } if present?(thinking)),
          ({ type: 'text', content: message.content } if present?(message.content)),
          *message.attachments.map { |attachment| attachment(attachment) },
          *(message.tool_calls || {}).each_value.map { |call| tool_call(call) }
        ].compact
      end

      def tool_response(message)
        { type: 'tool_call_response', id: message.tool_call_id, response: message.content }
      end

      def tool_call(call)
        { type: 'tool_call', id: call.id, name: call.name, arguments: call.arguments }
      end

      def attachment(attachment)
        described = { modality: attachment.type.to_s, mime_type: attachment.mime_type }
        if attachment.provider_file?
          { type: 'file', **described, file_id: attachment.provider_file_id }
        elsif attachment.url?
          { type: 'uri', **described, uri: attachment.source.to_s }
        else
          { type: 'attachment', **described, filename: attachment.filename }
        end
      end

      def present?(text)
        text.is_a?(String) && !text.empty?
      end

      def json(value)
        return if value.nil?

        value.is_a?(String) ? value : JSON.generate(value)
      end
    end
  end
end
