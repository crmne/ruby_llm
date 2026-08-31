# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Anthropic
      # Chat methods for the Anthropic API implementation
      module Chat
        ANTHROPIC_INLINE_REQUEST_LIMIT = 24 * 1024 * 1024
        ANTHROPIC_FILE_UPLOAD_LIMIT = 500 * 1024 * 1024
        CACHE_CONTROL_TYPE = 'ephemeral'
        PROMPT_CACHE_OPTIONS = %i[ttl].freeze
        BETA_HEADER = 'anthropic-beta'
        COMPACTION_BETA = 'compact-2026-01-12'
        COMPACTION_EDIT_TYPE = 'compact_20260112'
        COUNT_TOKENS_KEYS = %i[model messages system tools tool_choice thinking].freeze

        module_function

        def completion_url
          'v1/messages'
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil,
                           schema: nil, thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          warn_unsupported_citations(model) if citations && !model.supports?(:citations)
          tool_prefs ||= {}
          system_messages, chat_messages = separate_messages(messages)
          explicit_boundaries = cache_boundaries?(messages, caching:)
          system_content = build_system_content(system_messages, caching:)

          build_base_payload(chat_messages, model, stream, thinking, citations: citations, caching:).tap do |payload|
            payload[:max_tokens] = max_output_tokens if max_output_tokens
            add_optional_fields(payload, system_content:, tools:, tool_prefs:, temperature:, schema:)
            payload[:cache_control] = prompt_cache_control(caching) if caching && !explicit_boundaries
          end
        end

        def count_tokens_url
          'v1/messages/count_tokens'
        end

        def render_count_tokens_payload(messages, tools:, model:, tool_prefs: nil, thinking: nil, schema: nil,
                                        citations: false, caching: nil)
          render_payload(
            messages,
            tools: tools,
            tool_prefs: tool_prefs,
            temperature: nil,
            model: model,
            schema: schema,
            thinking: thinking,
            citations: citations,
            caching: caching
          ).slice(*COUNT_TOKENS_KEYS)
        end

        def parse_count_tokens_response(response)
          response.body['input_tokens']
        end

        def warn_unsupported_citations(model)
          RubyLLM.logger.warn(
            "#{model.id} does not support citations according to the model registry. " \
            'with_citations may have no effect.'
          )
        end

        def separate_messages(messages)
          messages.partition { |msg| msg.role == :system }
        end

        def build_system_content(system_messages, caching: nil)
          return [] if system_messages.empty?

          # Anthropic's `system` parameter accepts an array of text content blocks
          # (each optionally with cache_control); each :system message becomes its
          # own block in the resulting array.
          system_messages.flat_map do |msg|
            blocks = Media.format_content(msg.content, msg.attachments).dup
            cache_boundary?(msg, caching:) ? inject_cache_control(blocks, caching:) : blocks
          end
        end

        def build_base_payload(chat_messages, model, stream, thinking, citations: false, caching: nil)
          payload = {
            model: model.id,
            messages: format_messages(chat_messages, thinking:, citations:, caching:),
            stream: stream,
            max_tokens: model.max_output_tokens || 4096
          }

          add_thinking_fields(payload, thinking)

          payload
        end

        def format_messages(messages, thinking: nil, citations: false, caching: nil)
          rendered = []
          tool_result_blocks = []

          messages.each do |msg|
            if msg.tool_result?
              tool_result_blocks << Tools.format_tool_result_block(msg)
              inject_cache_control(tool_result_blocks, caching:) if cache_boundary?(msg, caching:)
              next
            end

            unless tool_result_blocks.empty?
              rendered << { role: 'user', content: tool_result_blocks }
              tool_result_blocks = []
            end

            formatted = format_message(msg, thinking:, citations:, caching:)
            rendered << formatted unless formatted[:content].empty?
          end

          rendered << { role: 'user', content: tool_result_blocks } unless tool_result_blocks.empty?
          rendered
        end

        def add_optional_fields(payload, system_content:, tools:, tool_prefs:, temperature:, schema: nil)
          if tools.any?
            payload[:tools] = tools.values.map { |t| Tools.function_for(t) }
            unless tool_prefs[:choice].nil? && tool_prefs[:calls].nil?
              payload[:tool_choice] = Tools.build_tool_choice(tool_prefs)
            end
          end
          payload[:system] = system_content unless system_content.empty?
          payload[:temperature] = temperature unless temperature.nil?
          payload[:output_config] = payload.fetch(:output_config, {}).merge(build_output_config(schema)) if schema
        end

        def apply_end_user(payload, identifier)
          Utils.deep_merge(payload, { metadata: { user_id: identifier } })
        end

        # Anthropic compacts through a context_management edit. Omitting the
        # trigger leaves the API on its own default threshold; the API
        # rejects an explicit one below its minimum, so RubyLLM passes the
        # value through rather than second-guessing it.
        def apply_compaction(payload, compaction)
          Utils.deep_merge(payload, { context_management: { edits: [compaction_edit(compaction)] } })
        end

        def compaction_edit(compaction)
          edit = { type: COMPACTION_EDIT_TYPE }
          edit[:trigger] = { type: 'input_tokens', value: compaction[:at] } if compaction[:at]
          edit[:instructions] = compaction[:instructions] if compaction[:instructions]
          edit[:pause_after_compaction] = true if compaction[:pause_after]
          edit
        end

        def apply_compaction_headers(headers, _compaction)
          headers.merge(BETA_HEADER => join_betas(headers[BETA_HEADER], COMPACTION_BETA))
        end

        # The Files API is still a beta, so a request that references an
        # uploaded file has to carry its beta header too.
        def apply_files_beta(headers, payload)
          return headers unless provider_file_source?(payload)

          headers.merge(BETA_HEADER => join_betas(headers[BETA_HEADER], Files::BETA_HEADER))
        end

        def provider_file_source?(payload)
          blocks = Array(payload[:messages]).flat_map { |message| Array(message[:content]) }
          blocks.concat(Array(payload[:system]))
          blocks.any? { |block| block.is_a?(Hash) && block[:source].is_a?(Hash) && block[:source][:type] == 'file' }
        end

        # Anthropic takes several betas as one comma-separated header, so an
        # added beta joins whatever a server tool or with_headers already set.
        def join_betas(existing, beta)
          (existing.to_s.split(',').map(&:strip).reject(&:empty?) + [beta]).uniq.join(',')
        end

        def supports_provider_file_references?
          true
        end

        def default_large_file_upload_threshold
          ANTHROPIC_INLINE_REQUEST_LIMIT
        end

        def provider_file_upload_limit
          ANTHROPIC_FILE_UPLOAD_LIMIT
        end

        def provider_file_attachable?(attachment)
          attachment.image? || attachment.pdf? || attachment.text?
        end

        def build_output_config(schema)
          normalized = RubyLLM::Utils.deep_dup(schema[:schema])
          normalized.delete(:strict)
          normalized.delete('strict')
          { format: { type: 'json_schema', schema: normalized } }
        end

        def parse_completion_body(data, raw:)
          content_blocks = data['content'] || []

          text_content, citations = extract_text_and_citations(content_blocks)
          thinking_content = extract_thinking_content(content_blocks)
          thinking_signature = extract_thinking_signature(content_blocks)
          tool_use_blocks = Tools.find_tool_uses(content_blocks)
          server_tool_calls = extract_server_tool_calls(content_blocks)

          build_message(data, content: text_content, citations:, thinking: thinking_content,
                              thinking_signature:, tool_use_blocks:, server_tool_calls:,
                              raw_content: server_tool_calls.any? ? content_blocks : nil, raw:)
        end

        # Any block that is not text, thinking, or a function tool_use is a
        # provider-executed tool step. Matching by shape rather than by an
        # allowlist keeps tools Anthropic ships later flowing through.
        def server_tool_block?(block)
          type = block['type'].to_s
          type == 'server_tool_use' || type == 'mcp_tool_use' || type == 'compaction' ||
            type.end_with?('_tool_result')
        end

        def extract_server_tool_calls(blocks)
          blocks.select { |block| server_tool_block?(block) }.map do |block|
            ServerToolCall.new(
              type: block['type'],
              name: block['name'],
              id: block['id'] || block['tool_use_id'],
              input: block['input'],
              result: block['content'],
              raw: block
            )
          end
        end

        def extract_text_and_citations(blocks)
          text = +''
          citations = []

          blocks.each do |block|
            next unless block['type'] == 'text'

            block_text = block['text'].to_s
            Array(block['citations']).each do |citation|
              citations << parse_citation(citation, text: block_text,
                                                    start_index: text.length,
                                                    end_index: text.length + block_text.length)
            end
            text << block_text
          end

          [text, citations]
        end

        def parse_citation(data, text: nil, start_index: nil, end_index: nil)
          end_page = data['end_page_number']

          Citation.new(
            url: citation_url(data),
            title: data['document_title'] || data['title'],
            cited_text: data['cited_text'],
            text: text,
            start_index: start_index,
            end_index: end_index,
            source_index: data['document_index'] || data['search_result_index'],
            start_page: data['start_page_number'],
            end_page: end_page && (end_page - 1)
          )
        end

        # Search result citations carry the developer-provided source string.
        def citation_url(data)
          url = data['url'] || data['source']
          url if url&.match?(%r{\Ahttps?://}i)
        end

        def extract_thinking_content(blocks)
          thinking_blocks = blocks.select { |c| c['type'] == 'thinking' }
          thoughts = thinking_blocks.map { |c| c['thinking'] || c['text'] }.join
          thoughts.empty? ? nil : thoughts
        end

        def extract_thinking_signature(blocks)
          thinking_block = blocks.find { |c| c['type'] == 'thinking' } ||
                           blocks.find { |c| c['type'] == 'redacted_thinking' }
          thinking_block&.dig('signature') || thinking_block&.dig('data')
        end

        def build_message(data, content:, citations:, thinking:, thinking_signature:, tool_use_blocks:, raw:,
                          server_tool_calls: [], raw_content: nil)
          usage = aggregate_usage(data['usage'])
          thinking_tokens = usage.dig('output_tokens_details', 'thinking_tokens') ||
                            usage.dig('output_tokens_details', 'reasoning_tokens') ||
                            usage['thinking_tokens'] ||
                            usage['reasoning_tokens']

          Message.new(
            role: :assistant,
            content: content,
            citations: citations,
            thinking: Thinking.build(text: thinking, signature: thinking_signature),
            tool_calls: Tools.parse_tool_calls(tool_use_blocks),
            server_tool_calls: server_tool_calls,
            raw_content: raw_content,
            input_tokens: usage['input_tokens'],
            output_tokens: usage['output_tokens'],
            cache_read_tokens: extract_cache_read_tokens(data),
            cache_write_tokens: extract_cache_write_tokens(data),
            thinking_tokens: thinking_tokens,
            server_tool_use: usage['server_tool_use'],
            finish_reason: data['stop_reason'],
            model: data['model'],
            raw: raw
          )
        end

        def format_message(msg, thinking: nil, citations: false, caching: nil)
          thinking_enabled = thinking&.enabled?

          if msg.role == :assistant && msg.raw_content
            format_raw_assistant_message(msg, caching:)
          elsif msg.tool_call?
            format_tool_call_with_thinking(msg, thinking_enabled, caching:)
          elsif msg.tool_result?
            Tools.format_tool_result(msg)
          else
            format_basic_message_with_thinking(msg, thinking_enabled, citations: citations, caching:)
          end
        end

        # Turns that used server tools replay their provider-shaped blocks
        # verbatim: the API requires the tool_use/result blocks and their
        # citations back exactly as returned.
        def format_raw_assistant_message(msg, caching: nil)
          blocks = msg.raw_content.dup
          inject_cache_control(blocks, caching:) if cache_boundary?(msg, caching:)

          { role: 'assistant', content: blocks }
        end

        def format_basic_message_with_thinking(msg, thinking_enabled, citations: false, caching: nil)
          content_blocks = []

          if msg.role == :assistant && thinking_enabled
            thinking_block = build_thinking_block(msg.thinking)
            content_blocks << thinking_block if thinking_block
          end

          append_formatted_content(content_blocks, msg, citations: citations)
          inject_cache_control(content_blocks, caching:) if cache_boundary?(msg, caching:)

          {
            role: convert_role(msg.role),
            content: content_blocks
          }
        end

        def format_tool_call_with_thinking(msg, thinking_enabled, caching: nil)
          content_blocks = prepend_thinking_block([], msg, thinking_enabled)
          append_formatted_content(content_blocks, msg) unless msg.content.nil? || msg.content.empty?

          msg.tool_calls.each_value do |tool_call|
            content_blocks << {
              type: 'tool_use',
              id: tool_call.id,
              name: tool_call.name,
              input: tool_call.arguments
            }
          end
          inject_cache_control(content_blocks, caching:) if cache_boundary?(msg, caching:)

          {
            role: 'assistant',
            content: content_blocks
          }
        end

        def prepend_thinking_block(content_blocks, msg, thinking_enabled)
          return content_blocks unless thinking_enabled

          thinking_block = build_thinking_block(msg.thinking)
          content_blocks.unshift(thinking_block) if thinking_block

          content_blocks
        end

        def build_thinking_block(thinking)
          return nil unless thinking

          if thinking.text
            {
              type: 'thinking',
              thinking: thinking.text,
              signature: thinking.signature
            }.compact
          elsif thinking.signature
            {
              type: 'redacted_thinking',
              data: thinking.signature
            }
          end
        end

        def append_formatted_content(content_blocks, msg, citations: false)
          content_blocks.concat(Media.format_content(msg.content, msg.attachments, citations: citations))
        end

        def cache_boundaries?(messages, caching: nil)
          caching != false && messages.any?(&:cache_until_here?)
        end

        def cache_boundary?(message, caching: nil)
          caching != false && message.cache_until_here?
        end

        def inject_cache_control(blocks, caching: nil)
          return blocks if blocks.empty?

          last = blocks.last
          return blocks if last.is_a?(Hash) && (last[:cache_control] || last['cache_control'])
          return blocks unless last.is_a?(Hash)

          blocks[-1] = last.merge(cache_control: prompt_cache_control(caching))
          blocks
        end

        def prompt_cache_control(caching = nil)
          options = prompt_cache_options(caching)

          { type: CACHE_CONTROL_TYPE }.tap do |control|
            control[:ttl] = options[:ttl] if options[:ttl]
          end
        end

        def prompt_cache_options(caching)
          return {} unless caching

          options = caching.to_h.transform_keys(&:to_sym)
          unsupported = options.keys - PROMPT_CACHE_OPTIONS
          return options if unsupported.empty?

          raise ArgumentError,
                "Anthropic prompt caching accepts :ttl, got #{format_cache_option_keys(unsupported)}"
        end

        def format_cache_option_keys(keys)
          keys.map { |key| ":#{key}" }.join(', ')
        end

        def convert_role(role)
          case role
          when :tool, :user then 'user'
          else 'assistant'
          end
        end

        def add_thinking_fields(payload, thinking)
          thinking_payload = build_thinking_payload(thinking)
          return unless thinking_payload

          payload[:thinking] = thinking_payload[:thinking] if thinking_payload[:thinking]
          return unless thinking_payload[:output_config]

          payload[:output_config] = payload.fetch(:output_config, {}).merge(thinking_payload[:output_config])
        end

        def build_thinking_payload(thinking)
          return nil unless thinking&.enabled?
          return { thinking: { type: 'disabled' } } if thinking.enabled == false

          effort = resolve_effort(thinking)
          return nil if effort == 'none'

          payload = {}
          mode = thinking_mode(thinking)
          payload[:thinking] = mode if mode
          payload[:output_config] = { effort: effort } if effort
          payload
        end

        # The thinking block is where a budget and a display setting live, and
        # adaptive is the only type Anthropic accepts without a budget. Effort
        # is a separate parameter, so it never picks a type.
        def thinking_mode(thinking)
          return { type: 'adaptive' } if thinking.enabled == true
          return nil unless thinking.budget || thinking.display

          mode = if thinking.budget
                   { type: 'enabled', budget_tokens: thinking.budget }
                 else
                   { type: 'adaptive' }
                 end
          mode[:display] = thinking.display if thinking.display
          mode
        end

        def resolve_effort(thinking)
          effort = thinking.effort.to_s
          effort.empty? ? nil : effort
        end
      end
    end
  end
end
