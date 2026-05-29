# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # OpenAI Responses API (/v1/responses) support.
      #
      # OpenAI reasoning models (gpt-5.x, o-series) reject `reasoning_effort`
      # alongside function tools on /v1/chat/completions:
      #   "Function tools with reasoning_effort are not supported ... use /v1/responses"
      # When a turn requests thinking AND ships tools, we transparently route it
      # through the Responses API instead, translating request + response shapes
      # so the rest of RubyLLM (Message/ToolCall/Thinking, the tool loop) is
      # unchanged. The decision is recorded in @openai_responses_mode by
      # render_payload and read back by completion_url / parse_completion_response
      # within the same Provider#complete call.
      module Responses
        module_function

        # Route to /v1/responses only for the exact combo that 400s on
        # chat/completions: a reasoning effort requested together with tools.
        def responses_api?(tools:, thinking:)
          !resolve_effort(thinking).nil? && tools.any?
        end

        # rubocop:disable Metrics/ParameterLists
        def render_responses_payload(messages, tools:, model:, stream:, schema:, thinking:, tool_prefs:)
          tool_prefs ||= {}
          system_messages, conversation = messages.partition { |msg| msg.role == :system }

          payload = {
            model: model.id,
            input: format_responses_input(conversation),
            stream: stream,
            store: false
          }

          instructions = system_messages.map { |msg| responses_text_content(msg.content) }.join("\n\n")
          payload[:instructions] = instructions unless instructions.empty?

          apply_responses_tools(payload, tools, tool_prefs)

          effort = resolve_effort(thinking)
          payload[:reasoning] = { effort: effort } if effort

          if schema
            payload[:text] = {
              format: { type: 'json_schema', name: schema[:name], schema: schema[:schema], strict: schema[:strict] }
            }
          end

          payload
        end
        # rubocop:enable Metrics/ParameterLists

        def apply_responses_tools(payload, tools, tool_prefs)
          return unless tools.any?

          payload[:tools] = tools.map { |_, tool| responses_tool_for(tool) }
          payload[:tool_choice] = responses_tool_choice(tool_prefs[:choice]) unless tool_prefs[:choice].nil?
          payload[:parallel_tool_calls] = tool_prefs[:calls] == :many unless tool_prefs[:calls].nil?
        end

        # Responses tools are flat ({type, name, description, parameters}) — not
        # nested under a "function" key like chat/completions.
        def responses_tool_for(tool)
          definition = {
            type: 'function',
            name: tool.name,
            description: tool.description,
            parameters: parameters_schema_for(tool)
          }
          return definition if tool.provider_params.empty?

          RubyLLM::Utils.deep_merge(definition, tool.provider_params)
        end

        def responses_tool_choice(choice)
          case choice
          when :auto, :none, :required then choice.to_s
          else { type: 'function', name: choice }
          end
        end

        # Translate RubyLLM messages into Responses `input` items.
        def format_responses_input(messages)
          messages.flat_map { |msg| responses_items_for(msg) }
        end

        def responses_items_for(msg)
          case msg.role
          when :tool      then [responses_tool_output_item(msg)]
          when :assistant then responses_assistant_items(msg)
          else                 [{ role: msg.role.to_s, content: responses_user_content(msg.content) }]
          end
        end

        def responses_tool_output_item(msg)
          { type: 'function_call_output', call_id: msg.tool_call_id, output: responses_text_content(msg.content) }
        end

        def responses_assistant_items(msg)
          items = msg.tool_calls&.values&.map do |tc|
            { type: 'function_call', call_id: tc.id, name: tc.name, arguments: JSON.generate(tc.arguments) }
          end || []
          text = responses_text_content(msg.content)
          items << { role: 'assistant', content: [{ type: 'output_text', text: text }] } unless text.empty?
          items
        end

        def responses_user_content(content)
          [{ type: 'input_text', text: responses_text_content(content) }]
        end

        def responses_text_content(content)
          return content if content.is_a?(String)
          return content.text.to_s if content.respond_to?(:text)

          content.to_s
        end

        def parse_responses_response(response)
          data = response.body
          return if data.nil? || data.empty?
          raise Error.new(response, data.dig('error', 'message')) if data.dig('error', 'message')

          parsed = parse_responses_output(data['output'] || [])
          content = parsed[:content]
          content = data['output_text'].to_s if content.empty? && data['output_text']
          build_responses_message(data, parsed, content, response)
        end

        def parse_responses_output(output)
          content = +''
          thinking = +''
          signature = nil
          tool_calls = {}
          output.each do |item|
            case item['type']
            when 'message'       then content << responses_message_text(item)
            when 'reasoning'     then thinking << responses_reasoning_text(item)
            when 'function_call' then add_responses_tool_call(tool_calls, item)
            end
            signature ||= item['encrypted_content'] if item['type'] == 'reasoning'
          end
          { content: content, thinking: thinking, signature: signature, tool_calls: tool_calls }
        end

        def responses_message_text(item)
          Array(item['content']).filter_map { |c| c['text'] if c['type'] == 'output_text' }.join
        end

        def responses_reasoning_text(item)
          Array(item['summary']).filter_map { |s| s['text'] if s['type'] == 'summary_text' }.join
        end

        def add_responses_tool_call(tool_calls, item)
          call_id = item['call_id'] || item['id']
          tool_calls[call_id] = ToolCall.new(
            id: call_id,
            name: item['name'],
            arguments: responses_tool_arguments(item['arguments'])
          )
        end

        def responses_tool_arguments(arguments)
          return {} if arguments.nil? || arguments.empty?

          JSON.parse(arguments)
        end

        def build_responses_message(data, parsed, content, response)
          usage = data['usage'] || {}
          Message.new(
            role: :assistant,
            content: content.empty? ? nil : content,
            thinking: Thinking.build(text: parsed[:thinking].empty? ? nil : parsed[:thinking],
                                     signature: parsed[:signature]),
            tool_calls: parsed[:tool_calls].empty? ? nil : parsed[:tool_calls],
            input_tokens: usage['input_tokens'],
            output_tokens: usage['output_tokens'],
            cached_tokens: usage.dig('input_tokens_details', 'cached_tokens'),
            cache_creation_tokens: 0,
            thinking_tokens: usage.dig('output_tokens_details', 'reasoning_tokens'),
            model_id: data['model'],
            raw: response
          )
        end
      end
    end
  end
end
