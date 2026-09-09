# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Mistral
      module MultiCompletion # :nodoc:
        include Mistral::Content

        SERVER_TOOL_ALIASES = {
          image_generation: { tool: { type: 'image_generation' } },
          mcp: { tool: { type: 'connector' } }
        }.freeze

        module_function

        def server_tool_aliases
          SERVER_TOOL_ALIASES
        end

        def format_message_group(group, **options)
          content = group.first.raw_content
          return super unless group.one? && content.is_a?(Array) &&
                              content.all? { |entry| entry.is_a?(Hash) && entry['role'] }

          content.map { |entry| entry.except('index') }
        end

        def parse_completion_body(data, raw:)
          messages = data.dig('choices', 0, 'messages')
          return super unless messages.is_a?(Array)

          parse_multi_message(data, messages, raw:)
        end

        def multi_content(messages)
          output = messages.filter_map do |message|
            message.merge('type' => 'message.output') if message['role'] == 'assistant'
          end
          parse_conversation_content(output)
        end

        def multi_pending_calls(calls, results, raw:)
          pending = calls.reject { |call| results.key?(call['id']) }
          if pending.any? { |call| call.dig('metadata', 'tool_type') || call.dig('metadata', 'integration_id') }
            raise Error.new('Mistral returned an unfinished hosted tool call on Chat Completions', response: raw)
          end

          pending
        end

        def parse_multi_message(data, messages, raw:)
          content = multi_content(messages)
          results = messages.filter_map do |message|
            [message['tool_call_id'], message] if message['role'] == 'tool'
          end.to_h
          calls = messages.flat_map { |message| Array(message['tool_calls']) }
          pending = multi_pending_calls(calls, results, raw:)
          usage = data['usage'] || {}
          Message.new(role: :assistant, content: content[:text], thinking: Thinking.build(text: content[:thinking]),
                      attachments: content[:attachments], citations: content[:citations],
                      tool_calls: parse_tool_calls(pending, response: raw, finish_reason: :tool_calls),
                      server_tool_calls: parse_multi_steps(calls, results), raw_content: messages,
                      input_tokens: input_tokens(usage), output_tokens: output_tokens(usage),
                      cache_read_tokens: cache_read_tokens(usage), model: data['model'], raw: raw,
                      finish_reason: normalize_finish_reason(data.dig('choices', 0, 'finish_reason')))
        end

        def parse_multi_steps(calls, results)
          calls.filter_map do |call|
            result = results[call['id']]
            next unless result

            ServerToolCall.new(type: result['role'], id: call['id'], name: call.dig('function', 'name'),
                               input: call.dig('function', 'arguments'), result: result['content'], raw: result)
          end
        end

        def stream_response(payload, additional_headers = {}, &block)
          return super unless Array(payload[:tools]).any? { |tool| (tool[:type] || tool['type']) != 'function' }

          @multi_messages = {}
          @multi_usage = {}
          @multi_finish_reason = nil
          response = stream_events(completion_url, payload, additional_headers) do |data|
            block.call(build_multi_chunk(data))
          end
          raise Error.new('Mistral tool stream ended before completion', response:) unless @multi_finish_reason

          message = parse_completion_body(multi_response, raw: response)
          block.call(Chunk.new(role: :assistant, content: nil, tokens: message.tokens, model: message.model,
                               citations: message.citations, server_tool_calls: message.server_tool_calls,
                               tool_calls: message.tool_calls, raw_content: message.raw_content,
                               attachments: message.attachments, finish_reason: message.finish_reason))
          message
        end

        def build_multi_chunk(data)
          @multi_model = data['model']
          @multi_usage[data['id']] = data['usage'] if data['usage']
          choice = data.dig('choices', 0) || {}
          delta = choice['delta'] || {}
          index = delta.fetch('index', 0)
          @multi_finish_reason = nil unless @multi_messages.key?(index)
          entry = @multi_messages[index] ||= { 'content' => [], 'tool_calls' => [] }
          entry.merge!(delta.slice('role', 'tool_call_id', 'metadata'))
          append_multi_content(entry, delta['content'])
          append_multi_calls(entry, delta['tool_calls'])
          @multi_finish_reason = choice['finish_reason'] if choice['finish_reason']
          content, thinking = extract_content_and_thinking(delta['content']) if entry['role'] == 'assistant'
          Chunk.new(role: :assistant, content: content, thinking: Thinking.build(text: thinking), model: data['model'])
        end

        def append_multi_content(entry, content)
          return if content.nil?

          if content.is_a?(String)
            entry['content'] << { 'type' => 'text', 'text' => content }
          else
            entry['content'].concat(content)
          end
        end

        def append_multi_calls(entry, calls)
          Array(calls).each do |call|
            target = entry['tool_calls'][call.fetch('index', 0)] ||= { 'function' => { 'arguments' => +'' } }
            target.merge!(call.slice('id', 'type', 'metadata'))
            target['function']['name'] = call.dig('function', 'name') if call.dig('function', 'name')
            target['function']['arguments'] << call.dig('function', 'arguments').to_s
          end
        end

        def multi_response
          { 'model' => @multi_model, 'usage' => multi_usage,
            'choices' => [{ 'messages' => multi_messages, 'finish_reason' => @multi_finish_reason }] }
        end

        def multi_usage
          usages = @multi_usage.values
          usage = %w[prompt_tokens completion_tokens total_tokens].to_h do |key|
            [key, usages.sum { |value| value[key].to_i }]
          end
          usage['prompt_tokens_details'] = { 'cached_tokens' => usages.sum do |value|
            value.dig('prompt_tokens_details', 'cached_tokens').to_i
          end }
          usage
        end

        def multi_messages
          @multi_messages.sort.map do |_, message|
            message = message.reject { |key, value| key == 'tool_calls' && value.empty? }
            if message['role'] == 'tool' && message['content'].all? { |part| part['type'] == 'text' }
              message['content'] = message['content'].map { |part| part['text'] }.join
            end
            message
          end
        end
      end
    end
  end
end
