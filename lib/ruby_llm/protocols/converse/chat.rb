# frozen_string_literal: true

require 'json'

module RubyLLM
  module Protocols
    class Converse
      # Chat methods for Bedrock Converse API.
      module Chat
        BEDROCK_INLINE_DOCUMENT_LIMIT = 4_500_000

        module_function

        def completion_url
          "/model/#{escape_model_id(@model.id)}/converse"
        end

        # An application inference profile is referenced by its ARN, which contains a "/"
        # (".../application-inference-profile/<id>"). Left raw, that "/" is parsed as a path
        # separator in both the request URL and the SigV4 canonical path (Auth#canonical_uri),
        # so AWS receives a truncated, invalid modelId ("The provided model identifier is
        # invalid"). Percent-encoding the "/" keeps the id a single path segment; canonical_uri
        # then re-encodes per segment, double-encoding it as SigV4 requires for non-S3 services,
        # so the signed and sent paths stay consistent. This is a no-op for ordinary model ids,
        # which contain no "/"; other characters such as ":" (e.g. "...-v1:0") are valid within
        # a path segment and continue to be handled by canonical_uri unchanged.
        def escape_model_id(model_id)
          model_id.to_s.gsub('/', '%2F')
        end

        # rubocop:disable Metrics/ParameterLists,Lint/UnusedMethodArgument
        def render_payload(messages, tools:, temperature:, model:, stream: false,
                           schema: nil, thinking: nil, citations: false, tool_prefs: nil)
          warn_unsupported_citations(model) if citations
          tool_prefs ||= {}
          @used_document_names = {}
          system_messages, chat_messages = messages.partition { |msg| msg.role == :system }
          payload = {
            messages: format_messages(chat_messages)
          }

          system_blocks = format_system(system_messages)
          payload[:system] = system_blocks unless system_blocks.empty?

          payload[:inferenceConfig] = format_inference_config(model, temperature)

          tool_config = format_tool_config(tools, tool_prefs)
          payload[:toolConfig] = tool_config if tool_config

          additional_fields = format_additional_model_request_fields(thinking)
          payload[:additionalModelRequestFields] = additional_fields if additional_fields

          output_config = build_output_config(schema)
          payload[:outputConfig] = output_config if output_config

          payload
        end
        # rubocop:enable Metrics/ParameterLists,Lint/UnusedMethodArgument

        def warn_unsupported_citations(model)
          RubyLLM.logger.warn(
            "RubyLLM does not support citations on Bedrock yet. Ignoring with_citations for #{model.id}."
          )
        end

        def supports_provider_file_references?
          true
        end

        def default_large_file_upload_threshold
          BEDROCK_INLINE_DOCUMENT_LIMIT
        end

        def provider_file_attachable?(attachment)
          attachment.pdf? || attachment.document? || attachment.text?
        end

        def parse_completion_response(response)
          parse_completion_body(response.body, raw: response)
        end

        def parse_completion_body(data, raw:)
          return if data.nil? || data.empty?

          content_blocks = data.dig('output', 'message', 'content') || []
          usage = data['usage'] || {}
          thinking_text, thinking_signature = parse_thinking(content_blocks)

          Message.new(
            role: :assistant,
            content: parse_text_content(content_blocks),
            thinking: Thinking.build(text: thinking_text, signature: thinking_signature),
            tool_calls: parse_tool_calls(content_blocks),
            input_tokens: input_tokens(usage),
            output_tokens: usage['outputTokens'],
            cached_tokens: usage['cacheReadInputTokens'],
            cache_creation_tokens: usage['cacheWriteInputTokens'],
            thinking_tokens: reasoning_tokens(usage),
            finish_reason: data['stopReason'],
            model_id: data['modelId'],
            raw: raw
          )
        end

        def input_tokens(usage)
          input_tokens = usage['inputTokens']
          return unless input_tokens

          [input_tokens.to_i - usage['cacheReadInputTokens'].to_i - usage['cacheWriteInputTokens'].to_i, 0].max
        end

        def reasoning_tokens(usage)
          usage['reasoningTokens'] || usage.dig('outputTokensDetails', 'reasoningTokens')
        end

        def format_messages(messages)
          rendered = []
          tool_result_blocks = []

          messages.each do |msg|
            if msg.tool_result?
              tool_result_blocks << format_tool_result_block(msg)
              next
            end

            unless tool_result_blocks.empty?
              rendered << { role: 'user', content: tool_result_blocks }
              tool_result_blocks = []
            end

            message = format_non_tool_message(msg)
            rendered << message if message
          end

          rendered << { role: 'user', content: tool_result_blocks } unless tool_result_blocks.empty?
          rendered
        end

        def format_non_tool_message(msg)
          content = format_message_content(msg)
          return nil if content.empty?

          {
            role: format_role(msg.role),
            content: content
          }
        end

        def format_message_content(msg)
          if msg.content.is_a?(RubyLLM::Content::Raw)
            return format_raw_content(msg.content) if msg.role == :assistant

            return sanitize_non_assistant_raw_blocks(format_raw_content(msg.content))
          end

          blocks = []

          thinking_block = format_thinking_block(msg.thinking)
          blocks << thinking_block if msg.role == :assistant && thinking_block

          text_and_media_blocks = Media.format_content(msg.content, used_document_names: @used_document_names)
          blocks.concat(text_and_media_blocks) if text_and_media_blocks

          if msg.tool_call?
            msg.tool_calls.each_value do |tool_call|
              blocks << {
                toolUse: {
                  toolUseId: tool_call.id,
                  name: tool_call.name,
                  input: tool_call.arguments
                }
              }
            end
          end

          blocks
        end

        def format_raw_content(content)
          value = content.value
          value.is_a?(Array) ? value : [value]
        end

        def sanitize_non_assistant_raw_blocks(blocks)
          blocks.filter_map do |block|
            next unless block.is_a?(Hash)
            next if block.key?(:reasoningContent) || block.key?('reasoningContent')

            block
          end
        end

        def format_tool_result_block(msg)
          {
            toolResult: {
              toolUseId: msg.tool_call_id,
              content: format_tool_result_content(msg.content)
            }
          }
        end

        def format_tool_result_content(content)
          return format_raw_tool_result_content(content.value) if content.is_a?(RubyLLM::Content::Raw)
          return [{ json: content }] if content.is_a?(Hash) || content.is_a?(Array)
          return format_content_tool_result_content(content) if content.is_a?(RubyLLM::Content)

          [text_tool_result_block(content)]
        end

        def format_content_tool_result_content(content)
          blocks = []
          blocks << text_tool_result_block(content.text) unless content.text.to_s.empty?
          content.attachments.each { |attachment| blocks << text_tool_result_block(attachment.for_llm) }
          blocks.empty? ? [text_tool_result_block(nil)] : blocks
        end

        def text_tool_result_block(text)
          text = text.to_s
          text = '(no output)' if text.empty?
          { text: text }
        end

        def format_raw_tool_result_content(raw_value)
          blocks = raw_value.is_a?(Array) ? raw_value : [raw_value]

          normalized = blocks.filter_map do |block|
            normalize_tool_result_block(block)
          end

          normalized.empty? ? [{ text: raw_value.to_s }] : normalized
        end

        def normalize_tool_result_block(block)
          return nil unless block.is_a?(Hash)
          return block if tool_result_content_block?(block)

          nil
        end

        def tool_result_content_block?(block)
          %w[text json document image].any? do |key|
            block.key?(key) || block.key?(key.to_sym)
          end
        end

        def format_role(role)
          case role
          when :assistant then 'assistant'
          else 'user'
          end
        end

        def format_system(messages)
          messages.flat_map { |msg| Media.format_content(msg.content, used_document_names: @used_document_names) }
        end

        def format_inference_config(_model, temperature)
          config = {}
          config[:temperature] = temperature unless temperature.nil?
          config
        end

        def format_tool_config(tools, tool_prefs)
          return nil if tools.empty?

          config = {
            tools: tools.values.map { |tool| format_tool(tool) }
          }

          return config if tool_prefs.nil? || tool_prefs[:choice].nil?

          tool_choice = format_tool_choice(tool_prefs[:choice])
          config[:toolChoice] = tool_choice if tool_choice
          config
        end

        def format_tool_choice(choice)
          case choice
          when :auto
            { auto: {} }
          when :none
            nil
          when :required
            { any: {} }
          else
            { tool: { name: choice.to_s } }
          end
        end

        def format_tool(tool)
          input_schema = tool.params_schema || RubyLLM::Tool::SchemaDefinition.from_parameters(tool.parameters)&.json_schema

          tool_spec = {
            toolSpec: {
              name: tool.name,
              description: tool.description,
              inputSchema: {
                json: input_schema || default_input_schema
              }
            }
          }

          return tool_spec if tool.provider_params.empty?

          RubyLLM::Utils.deep_merge(tool_spec, tool.provider_params)
        end

        def format_additional_model_request_fields(thinking)
          fields = {}

          reasoning_fields = format_reasoning_fields(thinking)
          fields = RubyLLM::Utils.deep_merge(fields, reasoning_fields) if reasoning_fields

          fields.empty? ? nil : fields
        end

        def build_output_config(schema)
          return nil unless schema

          cleaned = RubyLLM::Utils.deep_dup(schema[:schema])
          cleaned.delete(:strict)
          cleaned.delete('strict')

          {
            textFormat: {
              type: 'json_schema',
              structure: {
                jsonSchema: {
                  schema: JSON.generate(cleaned),
                  name: schema[:name]
                }
              }
            }
          }
        end

        def format_reasoning_fields(thinking)
          return nil unless thinking&.enabled?

          effort_config = effort_reasoning_config(thinking)
          return effort_config if effort_config

          budget_reasoning_config(thinking)
        end

        def effort_reasoning_config(thinking)
          effort = thinking.effort.to_s
          return nil if effort.empty? || effort == 'none'

          if Converse.reasoning_embedded?(@model)
            { reasoning_config: { type: 'enabled', reasoning_effort: effort } }
          else
            { reasoning_effort: effort }
          end
        end

        def budget_reasoning_config(thinking)
          budget = thinking.budget
          return nil unless budget.is_a?(Integer)

          { reasoning_config: { type: 'enabled', budget_tokens: budget } }
        end

        def format_thinking_block(thinking)
          return nil unless thinking

          if thinking.text
            {
              reasoningContent: {
                reasoningText: {
                  text: thinking.text,
                  signature: thinking.signature
                }.compact
              }
            }
          elsif thinking.signature
            {
              reasoningContent: {
                redactedContent: thinking.signature
              }
            }
          end
        end

        def parse_text_content(content_blocks)
          text = content_blocks.filter_map { |block| block['text'] if block['text'].is_a?(String) }.join
          text.empty? ? nil : text
        end

        def parse_thinking(content_blocks)
          text = +''
          signature = nil

          content_blocks.each do |block|
            chunk_text, chunk_signature = parse_reasoning_content_block(block)
            text << chunk_text if chunk_text
            signature ||= chunk_signature
          end

          [text.empty? ? nil : text, signature]
        end

        def parse_reasoning_content_block(block)
          reasoning_content = block['reasoningContent']
          return [nil, nil] unless reasoning_content.is_a?(Hash)

          reasoning_text = reasoning_content['reasoningText'] || {}
          text = reasoning_text['text'].is_a?(String) ? reasoning_text['text'] : nil
          signature = reasoning_text['signature'] if reasoning_text['signature'].is_a?(String)
          signature ||= reasoning_content['redactedContent'] if reasoning_content['redactedContent'].is_a?(String)
          [text, signature]
        end

        def parse_tool_calls(content_blocks)
          tool_calls = {}

          content_blocks.each do |block|
            tool_use = block['toolUse']
            next unless tool_use

            tool_call_id = tool_use['toolUseId']
            tool_calls[tool_call_id] = ToolCall.new(
              id: tool_call_id,
              name: tool_use['name'],
              arguments: tool_use['input'] || {}
            )
          end

          tool_calls.empty? ? nil : tool_calls
        end

        def default_input_schema
          {
            'type' => 'object',
            'properties' => {},
            'required' => []
          }
        end
      end
    end
  end
end
