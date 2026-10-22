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
        PROMPT_CACHE_OPTIONS = %i[key ttl mode retention].freeze

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
            input: render_input(messages, caching:),
            instructions: render_instructions(messages, caching:),
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
          payload[:reasoning] = (payload[:reasoning] || {}).merge(summary: 'auto') if thinking&.display == :summarized
          payload.merge!(prompt_cache_params(caching)) if caching

          payload
        end

        def parse_completion_body(data, raw:)
          raise Error.new(provider_message: data.dig('error', 'message'), response: raw) if data.dig('error', 'message')

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
            tool_calls: parse_pending_tool_calls(output, response: raw, finish_reason: finish_reason),
            server_tool_calls: server_tool_calls,
            raw_content: keep_raw_output?(output, server_tool_calls) ? output : nil,
            phase: parse_phase(output),
            model: data['model'],
            raw: raw,
            finish_reason: finish_reason,
            **parse_usage(data['usage'] || {}),
            server_tool_use: parse_server_tool_use(data)
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
        TOOL_SEARCH_ITEM_TYPES = %w[tool_search_call tool_search_output].freeze

        PORTABLE_OUTPUT_ITEM_TYPES = (%w[message function_call] + TOOL_SEARCH_ITEM_TYPES).freeze

        # A message carries one thinking signature and one phase, so output
        # with more reasoning items or phases than that only replays whole
        # from its raw items.
        def keep_raw_output?(output, server_tool_calls)
          server_tool_calls.any? || output.any? { |item| namespaced_call?(item) } ||
            output.count { |item| item['type'] == 'reasoning' } > 1 || message_phases(output).uniq.size > 1
        end

        def parse_phase(output)
          message_phases(output).compact.last
        end

        def message_phases(output)
          output.select { |item| item['type'] == 'message' }.map { |item| item['phase'] }
        end

        def namespaced_call?(item)
          item['type'] == 'function_call' && !item['namespace'].nil?
        end

        def portable_raw_content(message)
          items = message.raw_content
          return unless items.is_a?(Array)
          return unless items.any? { |item| TOOL_SEARCH_ITEM_TYPES.include?(item['type']) || namespaced_call?(item) }

          kept = items.reject { |item| item['type'] == 'reasoning' }
          kept if kept.all? { |item| PORTABLE_OUTPUT_ITEM_TYPES.include?(item['type']) }
        end

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
          offset = 0
          output.select { |item| item['type'] == 'message' }.flat_map do |message|
            Array(message['content']).flat_map do |part|
              key = MESSAGE_TEXT_KEYS[part['type']]
              next [] unless key

              citations = offset_citations(parse_annotations(part['annotations'], nil), offset, content)
              offset += part[key].to_s.length
              citations
            end
          end
        end

        def parse_annotations(annotations, content)
          Array(annotations).filter_map do |annotation|
            case annotation['type']
            when 'file_citation', 'container_file_citation'
              parse_file_citation(annotation, content)
            else
              super([normalize_annotation(annotation)], content).first
            end
          end
        end

        def parse_file_citation(annotation, content)
          start_index = annotation['start_index']
          end_index = annotation['end_index']

          Citation.new(
            source_id: annotation['file_id'],
            title: annotation['filename'],
            source_index: annotation['index'],
            text: annotated_text(content, start_index, end_index),
            start_index: start_index,
            end_index: end_index
          )
        end

        def offset_citations(citations, offset, content)
          citations.map do |citation|
            start_index = citation.start_index && (citation.start_index + offset)
            end_index = citation.end_index && (citation.end_index + offset)

            Citation.new(citation.to_h.merge(
                           start_index: start_index,
                           end_index: end_index,
                           text: annotated_text(content, start_index, end_index)
                         ))
          end
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

        # Searches are billed by tool_usage, not by the web_search_call items
        # in the output, which can each run several.
        def parse_server_tool_use(response)
          response['tool_usage'].to_h.filter_map do |tool, usage|
            ["#{tool}_requests", usage['num_requests']] if usage['num_requests']
          end.to_h
        end

        def schema_format(schema)
          {
            type: 'json_schema',
            name: schema[:name],
            schema: schema[:schema],
            strict: schema_strict(schema)
          }
        end

        # The +instructions+ parameter is a plain string and cannot carry a
        # breakpoint marker or a file. When any system message needs one, every
        # system message rides along as an input item, so their order holds.
        def render_instructions(messages, caching: nil)
          system = messages.select { |msg| msg.role == :system }
          return if system.empty? || system_input_items?(system, caching:)

          system.map { |msg| msg.content.to_s }.join("\n\n")
        end

        def render_input(messages, caching: nil)
          system, conversation = messages.partition { |msg| msg.role == :system }
          system_items = if system_input_items?(system, caching:)
                           system.flat_map { |msg| [render_item(msg, caching:)].flatten(1) }
                         else
                           []
                         end

          system_items + render_conversation(conversation, caching:)
        end

        def render_conversation(messages, caching: nil)
          messages.each_with_object([]) do |message, input|
            raw = message.raw_content
            if raw.is_a?(Hash) && raw['object'] == 'response.compaction'
              input.replace(raw.fetch('output'))
            else
              input.concat([render_item(message, caching:)].flatten(1))
            end
          end
        end

        def system_input_items?(messages, caching: nil)
          messages.any? { |msg| system_input_item?(msg, caching:) }
        end

        def system_input_item?(msg, caching: nil)
          msg.role == :system && ((caching != false && msg.cache_until_here?) || msg.attachments.any?)
        end

        def render_item(msg, caching: nil)
          case msg.role
          when :system
            item = { role: 'system', content: render_content(msg.content, msg.attachments) }
            caching != false && msg.cache_until_here? ? inject_cache_breakpoint(item) : item
          when :tool
            render_tool_items(msg)
          when :assistant
            render_assistant_items(msg)
          else
            item = { role: 'user', content: render_content(msg.content, msg.attachments) }
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
        def render_tool_items(msg)
          return msg.raw_content if msg.raw_content

          items = [{
            type: 'function_call_output',
            call_id: msg.provider_call_id,
            output: render_content(msg.content)
          }]

          if msg.attachments.any?
            items << render_attachment_item("Attachments from tool call #{msg.provider_call_id}:", msg.attachments)
          end

          items
        end

        def render_attachment_item(label, attachments)
          parts = [{ type: 'input_text', text: label }]
          parts.concat(render_content(nil, attachments))
          { role: 'user', content: parts }
        end

        # Assistant output is text-only on the wire, so the attachments of a
        # replayed assistant turn ride a user item spliced in after it.
        def render_assistant_items(msg)
          # Turns that used server tools replay their output items verbatim,
          # reasoning and tool results included, as stateless chaining expects.
          return msg.raw_content if msg.raw_content

          items = []
          items << render_reasoning_item(msg.thinking) if own_signature(msg)
          items << render_output_item(msg) unless empty_content?(msg.content)
          items.concat(render_function_call_items(msg.tool_calls)) if msg.tool_call?
          items << render_attachment_item('Attachments from the assistant:', msg.attachments) if msg.attachments.any?
          items
        end

        def render_reasoning_item(thinking)
          {
            type: 'reasoning',
            summary: thinking.text ? [{ type: 'summary_text', text: thinking.text }] : [],
            encrypted_content: thinking.signature
          }
        end

        def render_function_call_items(tool_calls)
          tool_calls.map do |_, tc|
            {
              type: 'function_call',
              call_id: tc.provider_call_id,
              name: tc.name,
              arguments: JSON.generate(tc.arguments)
            }
          end
        end

        def render_output_item(msg)
          { role: 'assistant', content: [{ type: 'output_text', text: msg.content }], phase: msg.phase }.compact
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

        FINISH_REASONS = {
          'completed' => :stop, 'function_call' => :tool_calls,
          'max_output_tokens' => :max_tokens, 'content_filter' => :content_filter
        }.freeze

        def finish_reasons = FINISH_REASONS

        def parse_finish_reason(data)
          normalize_finish_reason(data.dig('incomplete_details', 'reason') || parse_completed_reason(data))
        end

        def parse_completed_reason(data)
          return unless data['status'] == 'completed'

          Array(data['output']).any? { |item| item['type'] == 'function_call' } ? 'function_call' : 'completed'
        end

        def parse_function_calls(output, response: nil, finish_reason: nil)
          calls = output.select { |item| item['type'] == 'function_call' }
          return nil if calls.empty?

          ToolCall.index(calls.map do |call|
            arguments = call['arguments']

            ToolCall.new(
              provider_call_id: call['call_id'],
              name: call['name'],
              arguments: parse_function_call_arguments(arguments, response: response, finish_reason: finish_reason)
            )
          end, by: :provider_call_id)
        end

        def parse_function_call_arguments(arguments, response: nil, finish_reason: nil)
          return {} if arguments.nil? || arguments.empty?

          Hash(JSON.parse(arguments))
        rescue JSON::ParserError, TypeError => e
          raise ToolCallParseError.for(response:, finish_reason:), cause: e
        end

        def parse_reasoning_summary(output)
          texts = output.select { |item| item['type'] == 'reasoning' }.flat_map do |item|
            Array(item['summary']).filter_map { |part| part['text'] }
          end

          texts.empty? ? nil : texts.join("\n\n")
        end

        def parse_reasoning_signature(output)
          output.find { |item| item['type'] == 'reasoning' }&.dig('encrypted_content')
        end

        def provider_file_references?
          true
        end

        def default_large_file_upload_threshold
          OPENAI_INLINE_FILE_LIMIT
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
