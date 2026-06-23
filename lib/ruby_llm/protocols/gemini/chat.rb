# frozen_string_literal: true

require 'set'
require 'rubygems/version'

module RubyLLM
  module Protocols
    class Gemini
      # Chat methods for the Gemini API implementation
      module Chat
        GEMINI_INLINE_FILE_THRESHOLD = 20 * 1024 * 1024
        VERTEX_INLINE_FILE_THRESHOLD = 7 * 1024 * 1024
        GEMINI_FILE_UPLOAD_LIMIT = 2 * 1024 * 1024 * 1024

        module_function

        def completion_url
          "models/#{@model.id}:generateContent"
        end

        # rubocop:disable Metrics/ParameterLists,Metrics/PerceivedComplexity,Lint/UnusedMethodArgument
        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil,
                           thinking: nil, citations: false, tool_prefs: nil)
          warn_unsupported_citations(model) if citations && !model.citations?
          tool_prefs ||= {}
          payload = {
            contents: format_messages(messages),
            generationConfig: {}
          }

          payload[:generationConfig][:temperature] = temperature unless temperature.nil?

          payload[:generationConfig].merge!(structured_output_config(schema, model)) if schema
          payload[:generationConfig][:thinkingConfig] = build_thinking_config(model, thinking) if thinking&.enabled?

          if tools.any?
            payload[:tools] = format_tools(tools)
            # Gemini doesn't support controlling parallel tool calls
            payload[:toolConfig] = build_tool_config(tool_prefs[:choice]) unless tool_prefs[:choice].nil?
          end

          payload
        end
        # rubocop:enable Metrics/ParameterLists,Metrics/PerceivedComplexity,Lint/UnusedMethodArgument

        def warn_unsupported_citations(model)
          RubyLLM.logger.warn(
            "#{model.id} does not support citations according to the model registry. " \
            'Gemini citations come from Google Search grounding: with_params(tools: [{ google_search: {} }]).'
          )
        end

        def build_thinking_config(_model, thinking)
          config = { includeThoughts: true }

          config[:thinkingLevel] = thinking.effort if thinking.effort
          config[:thinkingBudget] = thinking.budget if thinking.budget.is_a?(Integer)

          config
        end

        def supports_provider_file_references?
          true
        end

        def default_large_file_upload_threshold
          @provider.slug == 'vertexai' ? VERTEX_INLINE_FILE_THRESHOLD : GEMINI_INLINE_FILE_THRESHOLD
        end

        def provider_file_upload_limit
          GEMINI_FILE_UPLOAD_LIMIT
        end

        def provider_file_attachable?(attachment)
          attachment.image? || attachment.video? || attachment.audio? || attachment.pdf? || attachment.text?
        end

        private

        def format_messages(messages)
          MessageFormatter.new(self, messages).format
        end

        def format_role(role)
          case role
          when :assistant then 'model'
          when :system, :tool then 'user'
          else role.to_s
          end
        end

        def format_parts(msg)
          if msg.tool_call?
            format_tool_call(msg)
          elsif msg.tool_result?
            format_tool_result(msg)
          else
            format_message_parts(msg)
          end
        end

        def format_message_parts(msg)
          parts = []

          parts << build_thought_part(msg.thinking) if msg.role == :assistant && msg.thinking

          content_parts = Media.format_content(msg.content)
          parts.concat(content_parts.is_a?(Array) ? content_parts : [content_parts])
          parts
        end

        def build_thought_part(thinking)
          part = { thought: true }
          part[:text] = thinking.text if thinking.text
          part[:thoughtSignature] = thinking.signature if thinking.signature
          part
        end

        def parse_completion_response(response)
          parse_completion_body(response.body, raw: response)
        end

        def parse_completion_body(data, raw:)
          parts = data.dig('candidates', 0, 'content', 'parts') || []
          tool_calls = extract_tool_calls(data)
          content = parse_content(data)

          Message.new(
            role: :assistant,
            content: content,
            citations: extract_citations(data, content),
            thinking: Thinking.build(
              text: extract_thought_parts(parts),
              signature: extract_thought_signature(parts)
            ),
            tool_calls: tool_calls,
            input_tokens: input_tokens(data),
            output_tokens: calculate_output_tokens(data),
            cached_tokens: data.dig('usageMetadata', 'cachedContentTokenCount'),
            thinking_tokens: data.dig('usageMetadata', 'thoughtsTokenCount'),
            finish_reason: data.dig('candidates', 0, 'finishReason'),
            model_id: data['modelVersion'] || @model&.id,
            raw: raw
          )
        end

        def input_tokens(data)
          prompt_tokens = data.dig('usageMetadata', 'promptTokenCount')
          return unless prompt_tokens

          [prompt_tokens.to_i - data.dig('usageMetadata', 'cachedContentTokenCount').to_i, 0].max
        end

        def convert_schema_to_gemini(schema)
          return nil unless schema

          # Extract inner schema if wrapper format (e.g., from RubyLLM::Schema.to_json_schema)
          schema = schema[:schema] || schema

          GeminiSchema.new(schema).to_h
        end

        def parse_content(data)
          candidate = data.dig('candidates', 0)
          return '' unless candidate

          return '' if function_call?(candidate)

          parts = candidate.dig('content', 'parts')
          return '' unless parts&.any?

          non_thought_parts = parts.reject { |part| part['thought'] }
          return '' unless non_thought_parts.any?

          build_response_content(non_thought_parts)
        end

        # Normalizes grounding metadata (Google Search grounding) into citations.
        def extract_citations(data, content)
          metadata = data.dig('candidates', 0, 'groundingMetadata')
          return [] unless metadata

          chunks = metadata['groundingChunks'] || []
          supports = metadata['groundingSupports'] || []
          return chunk_citations(chunks) if supports.empty?

          supports.flat_map { |support| support_citations(support, chunks, content) }
        end

        def support_citations(support, chunks, content)
          segment = support['segment'] || {}
          end_index = segment['endIndex']
          start_index = segment['startIndex'] || (0 if end_index)

          Array(support['groundingChunkIndices']).filter_map do |index|
            source = chunk_source(chunks[index])
            next unless source

            Citation.new(
              url: source['uri'],
              title: source['title'],
              text: segment['text'],
              start_index: byte_to_char_index(content, start_index),
              end_index: byte_to_char_index(content, end_index),
              source_index: index
            )
          end
        end

        def chunk_citations(chunks)
          chunks.each_with_index.filter_map do |chunk, index|
            source = chunk_source(chunk)
            next unless source

            Citation.new(url: source['uri'], title: source['title'], source_index: index)
          end
        end

        def chunk_source(chunk)
          return nil unless chunk.is_a?(Hash)

          chunk['web'] || chunk['retrievedContext']
        end

        # Grounding segment indices are byte offsets into the UTF-8 response text.
        def byte_to_char_index(content, byte_index)
          return nil unless content.is_a?(String) && byte_index

          content.byteslice(0, byte_index)&.length
        end

        def extract_thought_parts(parts)
          thought_parts = parts.select { |p| p['thought'] }
          thoughts = thought_parts.filter_map { |p| p['text'] }.join
          thoughts.empty? ? nil : thoughts
        end

        def extract_thought_signature(parts)
          parts.each do |part|
            signature = part['thoughtSignature'] ||
                        part['thought_signature'] ||
                        part.dig('functionCall', 'thoughtSignature') ||
                        part.dig('functionCall', 'thought_signature')
            return signature if signature
          end

          nil
        end

        def function_call?(candidate)
          parts = candidate.dig('content', 'parts')
          parts&.any? { |p| p['functionCall'] }
        end

        def calculate_output_tokens(data)
          candidates = data.dig('usageMetadata', 'candidatesTokenCount') || 0
          thoughts = data.dig('usageMetadata', 'thoughtsTokenCount') || 0
          candidates + thoughts
        end

        def response_json_schema_supported?(model)
          version = gemini_version(model)
          version && version >= Gem::Version.new('2.5')
        end

        def build_json_schema(schema)
          normalized = RubyLLM::Utils.deep_dup(schema[:schema])
          normalized.delete(:strict)
          normalized.delete('strict')
          RubyLLM::Utils.deep_stringify_keys(normalized)
        end

        def gemini_version(model)
          return nil unless model

          metadata = model.metadata
          candidates = [
            model.id,
            model.family,
            metadata[:version],
            metadata['version'],
            metadata[:description]
          ].compact.map(&:to_s)

          candidates.each do |candidate|
            version = extract_version(candidate)
            return version if version
          end

          nil
        end

        def extract_version(text)
          return nil unless text

          match = text.match(/(\d+\.\d+|\d+)/)
          return nil unless match

          Gem::Version.new(match[1])
        rescue ArgumentError
          nil
        end

        def structured_output_config(schema, model)
          {
            responseMimeType: 'application/json'
          }.tap do |config|
            if response_json_schema_supported?(model)
              config[:responseJsonSchema] = build_json_schema(schema)
            else
              config[:responseSchema] = convert_schema_to_gemini(schema)
            end
          end
        end

        # formats a message
        class MessageFormatter
          def initialize(provider, messages)
            @provider = provider
            @messages = messages
            @index = 0
            @tool_call_names = {}
          end

          def format
            formatted = []

            while current_message
              if tool_message?(current_message)
                tool_parts, next_index = collect_tool_parts
                formatted << build_tool_response(tool_parts)
                @index = next_index
              else
                remember_tool_calls if current_message.tool_call?
                formatted << build_standard_message(current_message)
                @index += 1
              end
            end

            formatted
          end

          private

          def current_message
            @messages[@index]
          end

          def tool_message?(message)
            message&.role == :tool
          end

          def collect_tool_parts
            parts = []
            index = @index

            while tool_message?(@messages[index])
              tool_message = @messages[index]
              tool_name = @tool_call_names.delete(tool_message.tool_call_id)
              parts.concat(format_tool_result(tool_message, tool_name))
              index += 1
            end

            [parts, index]
          end

          def build_tool_response(parts)
            { role: 'user', parts: parts }
          end

          def remember_tool_calls
            current_message.tool_calls.each do |tool_call_id, tool_call|
              @tool_call_names[tool_call_id] = tool_call.name
            end
          end

          def build_standard_message(message)
            {
              role: @provider.send(:format_role, message.role),
              parts: @provider.send(:format_parts, message)
            }
          end

          def format_tool_result(message, tool_name)
            @provider.send(:format_tool_result, message, tool_name)
          end
        end

        # converts json schema to gemini
        class GeminiSchema
          def initialize(schema)
            @raw_schema = RubyLLM::Utils.deep_dup(schema)
            @definitions = {}
          end

          def to_h
            return nil unless @raw_schema

            symbolized = symbolize_and_extract_definitions(@raw_schema)
            convert(symbolized, Set.new)
          end

          private

          attr_reader :definitions

          def symbolize_and_extract_definitions(value)
            case value
            when Hash
              value.each_with_object({}) do |(key, val), hash|
                key_sym = begin
                  key.to_sym
                rescue StandardError
                  key
                end

                if definition_key?(key_sym)
                  merge_definitions(val)
                else
                  hash[key_sym] = symbolize_and_extract_definitions(val)
                end
              end
            when Array
              value.map { |item| symbolize_and_extract_definitions(item) }
            else
              value
            end
          end

          def definition_key?(key)
            %i[$defs definitions].include?(key)
          end

          def merge_definitions(raw_defs)
            return unless raw_defs

            symbolized = symbolize_and_extract_definitions(raw_defs)
            @definitions = if definitions.empty?
                             symbolized
                           else
                             RubyLLM::Utils.deep_merge(definitions, symbolized)
                           end
          end

          def convert(schema, visited_refs)
            return default_string_schema unless schema.is_a?(Hash)

            schema = strip_unsupported_keys(schema)

            if schema[:$ref]
              resolved = resolve_reference(schema, visited_refs)
              return resolved if resolved
            end

            schema = normalize_any_of(schema)

            result = case schema[:type].to_s
                     when 'object'
                       build_object(schema, visited_refs)
                     when 'array'
                       build_array(schema, visited_refs)
                     when 'number'
                       build_scalar('NUMBER', schema, %i[format minimum maximum enum nullable multipleOf])
                     when 'integer'
                       build_scalar('INTEGER', schema, %i[format minimum maximum enum nullable multipleOf])
                     when 'boolean'
                       build_scalar('BOOLEAN', schema, %i[nullable])
                     else
                       build_scalar('STRING', schema, %i[enum format nullable])
                     end

            apply_description(result, schema)
            result
          end

          def strip_unsupported_keys(schema)
            schema.dup.tap do |copy|
              copy.delete(:strict)
              copy.delete(:additionalProperties)
            end
          end

          def resolve_reference(schema, visited_refs)
            ref = schema[:$ref]
            return unless ref
            return if visited_refs.include?(ref)

            referenced = lookup_definition(ref)
            return unless referenced

            overrides = schema.except(:$ref)
            visited_refs.add(ref)
            merged = RubyLLM::Utils.deep_merge(referenced, overrides)
            convert(merged, visited_refs)
          ensure
            visited_refs.delete(ref)
          end

          def lookup_definition(ref) # rubocop:disable Metrics/PerceivedComplexity
            segments = ref.to_s.split('/').reject(&:empty?)
            return nil if segments.empty?

            segments.shift if segments.first == '#'
            segments.shift if %w[$defs definitions].include?(segments.first)

            current = definitions

            segments.each do |segment|
              break current = nil unless current.is_a?(Hash)

              key = begin
                segment.to_sym
              rescue StandardError
                segment
              end
              current = current[key]
            end

            current ? RubyLLM::Utils.deep_dup(current) : nil
          end

          def normalize_any_of(schema)
            any_of = schema[:anyOf]
            return schema unless any_of

            options = Array(any_of).map { |option| RubyLLM::Utils.deep_symbolize_keys(option) }
            nullables, non_null = options.partition { |option| schema_type(option) == 'null' }

            base = RubyLLM::Utils.deep_symbolize_keys(non_null.first || { type: 'string' })
            base[:nullable] = true if nullables.any?

            without_any_of = schema.each_with_object({}) do |(key, value), result|
              result[key] = value unless key == :anyOf
            end

            without_any_of.merge(base)
          end

          def schema_type(option)
            (option[:type] || option['type']).to_s.downcase
          end

          def build_object(schema, visited_refs)
            properties = schema.fetch(:properties, {}).transform_values do |child|
              convert(child, visited_refs)
            end

            {
              type: 'OBJECT',
              properties: properties
            }.tap do |object|
              required = Array(schema[:required]).map(&:to_s).uniq
              object[:required] = required if required.any?
              object[:propertyOrdering] = schema[:propertyOrdering] if schema[:propertyOrdering]
              copy_attribute(object, schema, :nullable)
            end
          end

          def build_array(schema, visited_refs)
            items_schema = schema[:items] ? convert(schema[:items], visited_refs) : default_string_schema

            {
              type: 'ARRAY',
              items: items_schema
            }.tap do |array|
              copy_attribute(array, schema, :minItems)
              copy_attribute(array, schema, :maxItems)
              copy_attribute(array, schema, :nullable)
            end
          end

          def build_scalar(type, schema, allowed_keys)
            { type: type }.tap do |result|
              allowed_keys.each { |key| copy_attribute(result, schema, key) }
            end
          end

          def apply_description(target, schema)
            description = schema[:description]
            target[:description] = description if description
          end

          def copy_attribute(target, source, key)
            target[key] = source[key] if source.key?(key)
          end

          def default_string_schema
            { type: 'STRING' }
          end
        end
      end
    end
  end
end
