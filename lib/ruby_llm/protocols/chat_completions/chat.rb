# frozen_string_literal: true

module RubyLLM
  module Protocols
    class ChatCompletions
      # Chat methods of the OpenAI API integration
      module Chat
        OPENAI_INLINE_FILE_LIMIT = 50 * 1024 * 1024
        OPENAI_FILE_UPLOAD_LIMIT = 512 * 1024 * 1024
        PROMPT_CACHE_OPTIONS = %i[key ttl mode retention].freeze

        def completion_url
          'chat/completions'
        end

        module_function

        # rubocop:disable Metrics/PerceivedComplexity
        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil, schema: nil,
                           thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          warn_unsupported_citations(model) if citations && !model.supports?(:citations)
          tool_prefs ||= {}
          payload = {
            model: model.id,
            messages: format_messages(messages, caching: caching),
            stream: stream
          }

          payload[:temperature] = temperature unless temperature.nil?
          payload[:max_tokens] = max_output_tokens unless max_output_tokens.nil?
          if tools.any?
            payload[:tools] = tools.map { |_, tool| tool_for(tool) }
            payload[:tool_choice] = build_tool_choice(tool_prefs[:choice]) unless tool_prefs[:choice].nil?
            payload[:parallel_tool_calls] = tool_prefs[:calls] == :many unless tool_prefs[:calls].nil?
          end

          if schema
            schema_name = schema[:name]
            schema_def = schema[:schema]
            strict = schema[:strict]

            payload[:response_format] = {
              type: 'json_schema',
              json_schema: {
                name: schema_name,
                schema: schema_def,
                strict: strict
              }
            }
          end

          effort = resolve_effort(thinking)
          payload[:reasoning_effort] = effort if effort

          payload[:stream_options] = { include_usage: true } if stream
          apply_prompt_cache_params(payload, messages, caching)
          payload
        end
        # rubocop:enable Metrics/PerceivedComplexity

        def warn_unsupported_citations(model)
          RubyLLM.logger.warn(
            "#{model.id} does not support citations according to the model registry. " \
            'with_citations may have no effect.'
          )
        end

        def parse_completion_body(data, raw:)
          raise Error.new(data.dig('error', 'message'), response: raw) if data.dig('error', 'message')

          message_data = data.dig('choices', 0, 'message')
          raise no_completion_message_error(data, raw) unless message_data

          usage = data['usage'] || {}
          thinking_tokens = thinking_tokens(usage)
          content, thinking_from_blocks = extract_content_and_thinking(message_data['content'])
          thinking_text = thinking_from_blocks || extract_thinking_text(message_data)
          thinking_signature = extract_thinking_signature(message_data)

          finish_reason = data.dig('choices', 0, 'finish_reason')

          Message.new(
            role: :assistant,
            content: content,
            citations: extract_citations(message_data, data, content),
            thinking: Thinking.build(text: thinking_text, signature: thinking_signature),
            raw_reasoning: extract_raw_reasoning(message_data),
            tool_calls: parse_tool_calls(message_data['tool_calls'], response: raw, finish_reason: finish_reason),
            input_tokens: input_tokens(usage),
            output_tokens: output_tokens(usage),
            cache_read_tokens: cache_read_tokens(usage),
            cache_write_tokens: cache_write_tokens(usage),
            thinking_tokens: thinking_tokens,
            server_tool_use: server_tool_use(usage),
            reported_cost: reported_cost(usage),
            finish_reason: finish_reason,
            model: data['model'],
            raw: raw
          )
        end

        def reported_cost(_usage)
          nil
        end

        def server_tool_use(usage)
          usage['server_tool_use'] || usage['server_tool_use_details']
        end

        def no_completion_message_error(data, raw)
          finish_reason = data.dig('choices', 0, 'finish_reason')
          message = 'Provider returned no completion message'
          message = "#{message} (finish_reason: #{finish_reason})" if finish_reason
          Error.new(message, response: raw)
        end

        def input_tokens(usage)
          return usage['prompt_cache_miss_tokens'] if usage['prompt_cache_miss_tokens']

          prompt_tokens = usage['prompt_tokens']
          return unless prompt_tokens

          [prompt_tokens.to_i - cache_read_tokens(usage).to_i - cache_write_tokens(usage).to_i, 0].max
        end

        def output_tokens(usage)
          completion_tokens = usage['completion_tokens']
          return unless completion_tokens

          completion_tokens = completion_tokens.to_i
          generated_tokens = generated_tokens_from_total(usage)
          return completion_tokens unless generated_tokens && generated_tokens > completion_tokens

          generated_tokens
        end

        def generated_tokens_from_total(usage)
          prompt_tokens = usage['prompt_tokens']
          total_tokens = usage['total_tokens']
          return unless prompt_tokens && total_tokens

          [total_tokens.to_i - prompt_tokens.to_i, 0].max
        end

        def cache_read_tokens(usage)
          usage.dig('prompt_tokens_details', 'cached_tokens') || usage['prompt_cache_hit_tokens']
        end

        def cache_write_tokens(usage)
          usage.dig('prompt_tokens_details', 'cache_write_tokens') ||
            usage.dig('input_tokens_details', 'cache_write_tokens') ||
            0
        end

        def thinking_tokens(usage)
          usage.dig('completion_tokens_details', 'reasoning_tokens') || usage['reasoning_tokens']
        end

        def extract_citations(message_data, data, content)
          annotations = parse_annotations(message_data['annotations'], content)
          return annotations if annotations.any?

          parse_root_citations(data)
        end

        def parse_annotations(annotations, content)
          Array(annotations).filter_map do |annotation|
            details = annotation['url_citation']
            next unless details.is_a?(Hash)

            start_index = details['start_index']
            end_index = details['end_index']

            Citation.new(
              url: details['url'],
              title: details['title'],
              text: annotated_text(content, start_index, end_index),
              start_index: start_index,
              end_index: end_index
            )
          end
        end

        def annotated_text(content, start_index, end_index)
          return nil unless content.is_a?(String) && start_index && end_index

          content[start_index...end_index]
        end

        # Perplexity and xAI return search citations at the root of the response.
        def parse_root_citations(data)
          search_results = data['search_results']
          return parse_search_results(search_results) if search_results.is_a?(Array) && search_results.any?

          Array(data['citations']).each_with_index.filter_map do |url, index|
            Citation.new(url: url, source_index: index) if url.is_a?(String)
          end
        end

        def parse_search_results(results)
          results.each_with_index.filter_map do |result, index|
            next unless result.is_a?(Hash)

            Citation.new(
              url: result['url'],
              title: result['title'],
              cited_text: result['snippet'],
              source_index: index
            )
          end
        end

        def apply_prompt_cache_params(payload, messages, caching)
          return unless openai_prompt_caching?

          payload.merge!(prompt_cache_params(caching)) if caching
          force_explicit_cache_mode(payload) if cache_boundaries?(messages)
        end

        def openai_prompt_caching?
          true
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
          messages.any?(&:cache_until_here?)
        end

        def prompt_cache_options(caching)
          options = caching.to_h.transform_keys(&:to_sym)
          unsupported = options.keys - PROMPT_CACHE_OPTIONS
          return options if unsupported.empty?

          raise ArgumentError,
                'Chat Completions prompt caching accepts :key, :ttl, and :mode, ' \
                "got #{format_cache_option_keys(unsupported)}"
        end

        def format_cache_option_keys(keys)
          keys.map { |key| ":#{key}" }.join(', ')
        end

        def format_messages(messages, caching: nil)
          messages_for_provider(messages).flat_map do |msg|
            formatted = {
              role: format_role(msg.role),
              content: format_message_content(msg, caching: caching),
              tool_calls: format_tool_calls(msg.tool_calls),
              tool_call_id: msg.tool_call_id
            }.compact.merge(format_thinking(msg))

            msg.tool_result? && msg.attachments.any? ? [formatted, tool_attachment_message(msg)] : [formatted]
          end
        end

        # Chat Completions tool messages are text-only on the wire, so tool
        # attachments ride a user message spliced in right after the result.
        def tool_attachment_message(msg)
          parts = [Media.format_text("Attachments from tool call #{msg.tool_call_id}:")]
          parts.concat(format_content(nil, msg.attachments))
          { role: 'user', content: parts }
        end

        def messages_for_provider(messages)
          system_messages, other_messages = messages.partition { |msg| msg.role == :system }
          system_messages + other_messages
        end

        def format_message_content(msg, **)
          content = format_content(msg.content, msg.tool_result? ? [] : msg.attachments)
          return '' if content.nil? && thinking_only_assistant_message?(msg)
          return inject_cache_breakpoint(content) if msg.cache_until_here? && openai_prompt_caching?

          content
        end

        def inject_cache_breakpoint(content)
          parts = cache_breakpoint_parts(content)
          return content unless parts&.last.is_a?(Hash)

          parts[-1] = parts.last.merge(prompt_cache_breakpoint: { mode: 'explicit' })
          parts
        end

        def cache_breakpoint_parts(content)
          case content
          when Array then content.dup
          when String then [Media.format_text(content)] unless content.empty?
          end
        end

        def thinking_only_assistant_message?(msg)
          msg.role == :assistant && msg.thinking && !msg.tool_call?
        end

        def format_content(content, attachments = [])
          Media.format_content(content, attachments)
        end

        def format_role(role)
          case role
          when :system
            @config.openai_use_system_role ? 'system' : 'developer'
          else
            role.to_s
          end
        end

        def resolve_effort(thinking)
          return nil unless thinking

          thinking.respond_to?(:effort) ? thinking.effort : thinking
        end

        # safety_identifier is an OpenAI parameter; the other services on
        # this wire format reject or ignore it, so only OpenAI's own
        # endpoints receive it.
        def apply_end_user(payload, identifier)
          return super unless %w[openai azure].include?(@provider.slug)

          payload.merge(safety_identifier: identifier)
        end

        def supports_provider_file_references?
          @provider.slug == 'openai'
        end

        def default_large_file_upload_threshold
          OPENAI_INLINE_FILE_LIMIT
        end

        def provider_file_upload_limit
          OPENAI_FILE_UPLOAD_LIMIT
        end

        def provider_file_attachable?(attachment)
          attachment.pdf?
        end

        def provider_file_upload_options(_attachment)
          { purpose: 'user_data' }
        end

        def format_thinking(msg)
          return {} unless msg.role == :assistant

          thinking = msg.thinking
          return {} unless thinking

          payload = {}
          if thinking.text
            payload[:reasoning] = thinking.text
            payload[:reasoning_content] = thinking.text
          end
          payload[:reasoning_signature] = thinking.signature if thinking.signature
          payload
        end

        def extract_thinking_text(message_data)
          candidate = message_data['reasoning_content'] || message_data['reasoning'] || message_data['thinking']
          candidate.is_a?(String) ? candidate : nil
        end

        def extract_thinking_signature(message_data)
          candidate = message_data['reasoning_signature'] || message_data['signature']
          candidate.is_a?(String) ? candidate : nil
        end

        def extract_raw_reasoning(_message_data)
          nil
        end

        def extract_content_and_thinking(content)
          return extract_think_tag_content(content) if content.is_a?(String)
          return [content, nil] unless content.is_a?(Array)

          text = extract_text_from_blocks(content)
          thinking = extract_thinking_from_blocks(content)

          [text.empty? ? nil : text, thinking.empty? ? nil : thinking]
        end

        def extract_text_from_blocks(blocks)
          blocks.filter_map do |block|
            block['text'] if block['type'] == 'text' && block['text'].is_a?(String)
          end.join
        end

        def extract_thinking_from_blocks(blocks)
          blocks.filter_map do |block|
            next unless block['type'] == 'thinking'

            extract_thinking_text_from_block(block)
          end.join
        end

        def extract_thinking_text_from_block(block)
          thinking_block = block['thinking']
          return thinking_block if thinking_block.is_a?(String)

          if thinking_block.is_a?(Array)
            return thinking_block.filter_map { |item| item['text'] if item['type'] == 'text' }.join
          end

          block['text'] if block['text'].is_a?(String)
        end

        def extract_think_tag_content(text)
          return [text, nil] unless text.include?('<think>')

          thinking = text.scan(%r{<think>(.*?)</think>}m).join
          content = text.gsub(%r{<think>.*?</think>}m, '').strip

          [content.empty? ? nil : content, thinking.empty? ? nil : thinking]
        end
      end
    end
  end
end
