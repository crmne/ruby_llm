# frozen_string_literal: true

require 'set'
require 'rubygems/version'

module RubyLLM
  module Providers
    class Gemini
      # Chat methods for the Gemini API implementation
      module Chat
        module_function

        def completion_url
          "models/#{@model}:generateContent"
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil) # rubocop:disable Metrics/ParameterLists,Lint/UnusedMethodArgument
          @model = model.id
          payload = {
            contents: format_messages(messages),
            generationConfig: {}
          }

          payload[:generationConfig][:temperature] = temperature unless temperature.nil?

          payload[:generationConfig].merge!(structured_output_config(schema, model)) if schema

          payload[:tools] = format_tools(tools) if tools.any?
          payload
        end

        private

        def format_messages(messages)
          formatter = MessageFormatter.new(
            messages,
            format_role: method(:format_role),
            format_parts: method(:format_parts),
            format_tool_result: method(:format_tool_result)
          )
          formatter.format
        end

        def format_role(role)
          case role
          when :assistant then 'model'
          when :system then 'user'
          when :tool then 'function'
          else role.to_s
          end
        end

        def format_parts(msg)
          if msg.tool_call?
            format_tool_call(msg)
          elsif msg.tool_result?
            format_tool_result(msg)
          else
            Media.format_content(msg.content)
          end
        end

        def parse_completion_response(response)
          data = response.body
          tool_calls = extract_tool_calls(data)

          Message.new(
            role: :assistant,
            content: parse_content(data),
            tool_calls: tool_calls,
            input_tokens: data.dig('usageMetadata', 'promptTokenCount'),
            output_tokens: calculate_output_tokens(data),
            model_id: data['modelVersion'] || response.env.url.path.split('/')[3].split(':')[0],
            raw: response
          )
        end

        def convert_schema_to_gemini(schema)
          return nil unless schema

          GeminiSchema.new(schema).to_h
        end

        def parse_content(data)
          candidate = data.dig('candidates', 0)
          return '' unless candidate

          return '' if function_call?(candidate)

          parts = candidate.dig('content', 'parts')
          return '' unless parts&.any?

          build_response_content(parts)
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
          normalized = RubyLLM::Utils.deep_dup(schema)
          normalized.delete(:strict)
          normalized.delete('strict')
          RubyLLM::Utils.deep_stringify_keys(normalized)
        end

        def gemini_version(model)
          return nil unless model

          candidates = [
            safe_string(model.id),
            safe_string(model.respond_to?(:family) ? model.family : nil),
            safe_string(model_metadata_value(model, :version)),
            safe_string(model_metadata_value(model, 'version')),
            safe_string(model_metadata_value(model, :description))
          ].compact

          candidates.each do |candidate|
            version = extract_version(candidate)
            return version if version
          end

          nil
        end

        def model_metadata_value(model, key)
          return unless model.respond_to?(:metadata)

          metadata = model.metadata
          return unless metadata.is_a?(Hash)

          metadata[key] || metadata[key.to_s]
        end

        def safe_string(value)
          value&.to_s
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
          def initialize(messages, format_role:, format_parts:, format_tool_result:)
            @messages = messages
            @index = 0
            @tool_call_names = {}
            @format_role = format_role
            @format_parts = format_parts
            @format_tool_result = format_tool_result
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
            { role: 'function', parts: parts }
          end

          def remember_tool_calls
            current_message.tool_calls.each do |tool_call_id, tool_call|
              @tool_call_names[tool_call_id] = tool_call.name
            end
          end

          def build_standard_message(message)
            {
              role: @format_role.call(message.role),
              parts: @format_parts.call(message)
            }
          end

          def format_tool_result(message, tool_name)
            @format_tool_result.call(message, tool_name)
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
