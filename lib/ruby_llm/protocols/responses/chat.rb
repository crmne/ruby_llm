# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # Chat methods of the OpenAI Responses API
      module Chat
        def completion_url
          'responses'
        end

        OPENAI_INLINE_FILE_LIMIT = 50 * 1024 * 1024
        OPENAI_FILE_UPLOAD_LIMIT = 512 * 1024 * 1024
        PROMPT_CACHE_OPTIONS = %i[key ttl mode retention].freeze
        CACHE_BREAKPOINT_ROLES = %i[user system].freeze

        module_function

        # rubocop:disable-next Metrics/PerceivedComplexity
        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil, schema: nil,
                           thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          warn_unsupported_citations(model) if citations && !model.supports?(:citations)
          tool_prefs ||= {}
          # store: false leaves the provider holding no state, so reasoning has
          # to ride back in the response. xAI only encrypts it when asked.
          payload = {
            model: model.id,
            input: format_input(messages, caching:),
            instructions: format_instructions(messages, caching:),
            stream: stream,
            store: false,
            include: ['reasoning.encrypted_content']
          }.compact

          payload[:temperature] = temperature unless temperature.nil?
          payload[:max_output_tokens] = max_output_tokens unless max_output_tokens.nil?

          if tools.any?
            payload[:tools] = tools.map { |_, tool| tool_for(tool) }
            payload[:tool_choice] = build_tool_choice(tool_prefs[:choice]) unless tool_prefs[:choice].nil?
            payload[:parallel_tool_calls] = tool_prefs[:calls] == :many unless tool_prefs[:calls].nil?
          end

          payload[:text] = { format: schema_format(schema) } if schema

          effort = resolve_effort(thinking)
          payload[:reasoning] = { effort: effort } if effort
          payload.merge!(prompt_cache_params(caching)) if caching
          force_explicit_cache_mode(payload) if caching != false && cache_boundaries?(messages)

          payload
        end

        def parse_completion_body(data, raw:)
          raise Error.new(data.dig('error', 'message'), response: raw) if data.dig('error', 'message')

          output = data['output'] || []
          content = parse_output_text(output)
          server_tool_calls = parse_server_tool_items(output)

          finish_reason = parse_finish_reason(data)

          Message.new(
            role: :assistant,
            content: content,
            citations: parse_citations(data, output, content),
            thinking: Thinking.build(
              text: parse_reasoning_summary(output),
              signature: parse_reasoning_signature(output)
            ),
            tool_calls: parse_function_calls(output, response: raw, finish_reason: finish_reason),
            server_tool_calls: server_tool_calls,
            raw_content: server_tool_calls.any? ? output : nil,
            model: data['model'],
            raw: raw,
            finish_reason: finish_reason,
            **parse_usage(data['usage'] || {})
          )
        end

        # context_management is an OpenAI parameter that only OpenAI's own
        # endpoints serve; the other services on this wire format reject it.
        COMPACTION_PROVIDERS = %w[openai azure].freeze
        COMPACTION_IGNORED_OPTIONS = %i[instructions pause_after].freeze

        # OpenAI names the threshold compact_threshold and takes the entries
        # as a flat array, where Anthropic nests a trigger object under
        # context_management.edits. It writes the summary itself, so there is
        # nothing to steer with instructions and no pausing to opt into.
        def apply_compaction(payload, compaction)
          return super unless COMPACTION_PROVIDERS.include?(@provider.slug)

          warn_ignored_compaction_options(compaction)
          entry = { type: 'compaction' }
          entry[:compact_threshold] = compaction[:at] if compaction[:at]
          payload.merge(context_management: [entry])
        end

        def warn_ignored_compaction_options(compaction)
          ignored = compaction.keys & COMPACTION_IGNORED_OPTIONS
          return if ignored.empty?

          RubyLLM.logger.debug do
            "#{@provider.name} compaction takes no #{ignored.join(', ')}, dropping"
          end
        end

        CLIENT_OUTPUT_ITEM_TYPES = %w[message reasoning function_call].freeze

        # Output items beyond text, reasoning, and function calls record
        # provider-executed tool steps (web_search_call, code_interpreter_call,
        # and whatever OpenAI ships next). They are kept raw and replayed.
        def parse_server_tool_items(output)
          output.reject { |item| CLIENT_OUTPUT_ITEM_TYPES.include?(item['type']) }.map do |item|
            ServerToolCall.new(
              type: item['type'],
              name: item['name'],
              id: item['id'],
              input: item['action'] || item['arguments'] || item['code'],
              result: server_tool_result(item),
              raw: item
            )
          end
        end

        # Result payloads differ by item type; compaction items carry an
        # opaque encrypted_content instead of a readable result.
        SERVER_TOOL_RESULT_KEYS = %w[result results outputs output encrypted_content].freeze

        def server_tool_result(item)
          key = SERVER_TOOL_RESULT_KEYS.find { |candidate| item[candidate] }
          item[key] if key
        end

        def parse_citations(data, output, content)
          citations = parse_output_citations(output, content)
          citations.any? ? citations : parse_root_citations(data)
        end

        def parse_output_citations(output, content)
          annotations = output.select { |item| item['type'] == 'message' }.flat_map do |message|
            Array(message['content']).flat_map { |part| Array(part['annotations']) }
          end

          parse_annotations(annotations, content)
        end

        # Responses annotations carry url_citation fields inline rather than
        # nested under a url_citation key like Chat Completions.
        def parse_annotations(annotations, content)
          super(Array(annotations).map { |annotation| normalize_annotation(annotation) }, content)
        end

        def normalize_annotation(annotation)
          return annotation if annotation.key?('url_citation') || annotation['type'] != 'url_citation'

          { 'url_citation' => annotation }
        end

        def prompt_cache_params(caching)
          options = prompt_cache_options(caching)
          cache_options = build_prompt_cache_options(options)

          {}.tap do |params|
            params[:prompt_cache_key] = options[:key] if options[:key]
            params[:prompt_cache_options] = cache_options unless cache_options.empty?
          end
        end

        def build_prompt_cache_options(options)
          ttl = options[:ttl] || retention_ttl(options[:retention])

          {}.tap do |cache_options|
            cache_options[:mode] = options[:mode] if options[:mode]
            cache_options[:ttl] = ttl if ttl
          end
        end

        def retention_ttl(retention)
          return unless retention

          RubyLLM.logger.warn(
            'with_caching retention: is deprecated; OpenAI replaced prompt_cache_retention ' \
            'with prompt_cache_options. Use ttl: instead.'
          )
          retention
        end

        def force_explicit_cache_mode(payload)
          payload[:prompt_cache_options] = { mode: 'explicit' }.merge(payload[:prompt_cache_options] || {})
        end

        def cache_boundaries?(messages)
          messages.any? { |msg| msg.cache_until_here? && CACHE_BREAKPOINT_ROLES.include?(msg.role) }
        end

        def prompt_cache_options(caching)
          options = caching.to_h.transform_keys(&:to_sym)
          unsupported = options.keys - PROMPT_CACHE_OPTIONS
          return options if unsupported.empty?

          raise ArgumentError,
                "Responses prompt caching accepts :key, :ttl, and :mode, got #{format_cache_option_keys(unsupported)}"
        end

        def format_cache_option_keys(keys)
          keys.map { |key| ":#{key}" }.join(', ')
        end

        def parse_usage(usage)
          details = usage['input_tokens_details'] || usage['prompt_tokens_details'] || {}
          cached = details['cached_tokens']
          cache_writes = details['cache_write_tokens']
          input = usage['input_tokens']

          {
            input_tokens: input && [input.to_i - cached.to_i - cache_writes.to_i, 0].max,
            output_tokens: usage['output_tokens'],
            cache_read_tokens: cached,
            cache_write_tokens: cache_writes,
            thinking_tokens: usage.dig('output_tokens_details', 'reasoning_tokens')
          }
        end

        def schema_format(schema)
          {
            type: 'json_schema',
            name: schema[:name],
            schema: schema[:schema],
            strict: schema[:strict]
          }
        end

        # System messages marked as cache boundaries, or carrying attachments,
        # ride along as input items, because the +instructions+ parameter is a
        # plain string and cannot carry a breakpoint marker or a file.
        def format_instructions(messages, caching: nil)
          instructions = messages.select { |msg| msg.role == :system && !system_input_item?(msg, caching:) }
                                 .map { |msg| msg.content.to_s }

          instructions.empty? ? nil : instructions.join("\n\n")
        end

        def format_input(messages, caching: nil)
          messages.reject { |msg| msg.role == :system && !system_input_item?(msg, caching:) }
                  .flat_map { |msg| format_item(msg, caching:) }
        end

        def system_input_item?(msg, caching: nil)
          msg.role == :system && ((caching != false && msg.cache_until_here?) || msg.attachments.any?)
        end

        def format_item(msg, caching: nil)
          case msg.role
          when :system
            item = { role: 'system', content: format_content(msg.content, msg.attachments) }
            caching != false && msg.cache_until_here? ? inject_cache_breakpoint(item) : item
          when :tool
            format_tool_items(msg)
          when :assistant
            format_assistant_items(msg)
          else
            item = { role: 'user', content: format_content(msg.content, msg.attachments) }
            caching != false && msg.cache_until_here? ? inject_cache_breakpoint(item) : item
          end
        end

        def inject_cache_breakpoint(item)
          parts = cache_breakpoint_parts(item[:content])
          return item unless parts&.last.is_a?(Hash)

          parts[-1] = parts.last.merge(prompt_cache_breakpoint: { mode: 'explicit' })
          item.merge(content: parts)
        end

        def cache_breakpoint_parts(content)
          case content
          when Array then content.dup
          when String then [{ type: 'input_text', text: content }] unless content.empty?
          end
        end

        # Function call outputs are text-only on the wire, so tool attachments
        # ride a user item spliced in right after the result.
        def format_tool_items(msg)
          items = [{
            type: 'function_call_output',
            call_id: msg.tool_call_id,
            output: format_content(msg.content)
          }]

          if msg.attachments.any?
            parts = [{ type: 'input_text', text: "Attachments from tool call #{msg.tool_call_id}:" }]
            parts.concat(Media.format_content(nil, msg.attachments))
            items << { role: 'user', content: parts }
          end

          items
        end

        def format_assistant_items(msg)
          # Turns that used server tools replay their output items verbatim,
          # reasoning and tool results included, as stateless chaining expects.
          return msg.raw_content if msg.raw_content

          items = []
          items << format_reasoning_item(msg.thinking) if msg.thinking&.signature
          items << { role: 'assistant', content: format_output_content(msg) } unless empty_content?(msg.content)
          items.concat(format_function_call_items(msg.tool_calls)) if msg.tool_call?
          items
        end

        def format_reasoning_item(thinking)
          {
            type: 'reasoning',
            summary: thinking.text ? [{ type: 'summary_text', text: thinking.text }] : [],
            encrypted_content: thinking.signature
          }
        end

        def format_function_call_items(tool_calls)
          tool_calls.map do |_, tc|
            {
              type: 'function_call',
              call_id: tc.id,
              name: tc.name,
              arguments: JSON.generate(tc.arguments)
            }
          end
        end

        def format_output_content(msg)
          [{ type: 'output_text', text: msg.content }]
        end

        def empty_content?(content)
          content.nil? || content.strip.empty?
        end

        MESSAGE_TEXT_KEYS = { 'output_text' => 'text', 'refusal' => 'refusal' }.freeze

        def parse_output_text(output)
          texts = output.select { |item| item['type'] == 'message' }.flat_map do |message|
            Array(message['content']).filter_map do |part|
              key = MESSAGE_TEXT_KEYS[part['type']]
              part[key] if key
            end
          end

          texts.empty? ? nil : texts.join
        end

        def parse_finish_reason(data)
          data.dig('incomplete_details', 'reason') || (data['status'] if data['status'] == 'completed')
        end

        def parse_function_calls(output, response: nil, finish_reason: nil)
          calls = output.select { |item| item['type'] == 'function_call' }
          return nil if calls.empty?

          calls.to_h do |call|
            arguments = call['arguments']

            [
              call['call_id'],
              ToolCall.new(
                id: call['call_id'],
                name: call['name'],
                arguments: parse_function_call_arguments(arguments, response: response, finish_reason: finish_reason)
              )
            ]
          end
        end

        def parse_function_call_arguments(arguments, response: nil, finish_reason: nil)
          return {} if arguments.nil? || arguments.empty?

          JSON.parse(arguments)
        rescue JSON::ParserError => e
          raise ToolCallParseError.new(response: response, finish_reason: finish_reason), cause: e
        end

        def parse_reasoning_summary(output)
          texts = output.select { |item| item['type'] == 'reasoning' }.flat_map do |item|
            Array(item['summary']).filter_map { |part| part['text'] }
          end

          texts.empty? ? nil : texts.join("\n")
        end

        def parse_reasoning_signature(output)
          output.find { |item| item['type'] == 'reasoning' }&.dig('encrypted_content')
        end

        def supports_provider_file_references?
          true
        end

        def default_large_file_upload_threshold
          OPENAI_INLINE_FILE_LIMIT
        end

        def provider_file_upload_limit
          OPENAI_FILE_UPLOAD_LIMIT
        end

        def provider_file_attachable?(attachment)
          attachment.pdf? || attachment.document?
        end

        def provider_file_upload_options(_attachment)
          { purpose: 'user_data' }
        end
      end
    end
  end
end
