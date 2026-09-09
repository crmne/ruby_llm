# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Interactions
      module Streaming # :nodoc:
        module_function

        def stream_response(payload, additional_headers = {})
          @interaction_steps = {}
          @interaction_response = {}
          @interaction_done = false
          response = stream_events(completion_url, payload, additional_headers) { |data| yield build_chunk(data) }
          raise Error.new('Gemini interaction stream ended before completion', response:) unless @interaction_done

          parse_completion_body(streamed_interaction, raw: response)
        end

        def build_chunk(data)
          @interaction_steps ||= {}
          @interaction_response ||= {}
          case data['event_type']
          when 'interaction.created'
            @interaction_response.merge!(data.fetch('interaction'))
          when 'interaction.completed'
            @interaction_done = true
            @interaction_response.merge!(data.fetch('interaction'))
            return final_interaction_chunk
          when 'error'
            raise Error, data.dig('error', 'message') || 'Gemini interaction failed'
          when 'step.start'
            @interaction_steps[data.fetch('index')] = Support::Utils.deep_dup(data.fetch('step'))
          when 'step.delta'
            step = @interaction_steps.fetch(data.fetch('index'))
            return append_interaction_delta(step, data.fetch('delta'))
          end
          Chunk.new(role: :assistant, content: nil)
        end

        def append_interaction_delta(step, delta)
          type = delta['type']
          case type
          when 'text'
            append_interaction_text(step, delta['text'])
            return Chunk.new(role: :assistant, content: delta['text'])
          when 'text_annotation'
            append_interaction_text(step, '')
            (step['content'].last['annotations'] ||= []) << delta['annotation']
          when 'thought_summary'
            (step['summary'] ||= []) << delta['content']
            return Chunk.new(role: :assistant, content: nil,
                             thinking: Thinking.build(text: delta.dig('content', 'text')))
          when 'thought_signature'
            step['signature'] = delta['signature']
          when 'arguments_delta'
            step['arguments'] = +'' unless step['arguments'].is_a?(String)
            step['arguments'] << delta['arguments'].to_s
          when 'image', 'audio', 'video', 'document'
            (step['content'] ||= []) << Support::Utils.deep_dup(delta)
          else
            step.merge!(delta.except('type'))
          end
          Chunk.new(role: :assistant, content: nil)
        end

        def append_interaction_text(step, text)
          content = step['content'] ||= []
          content << { 'type' => 'text', 'text' => +'' } unless content.last&.dig('type') == 'text'
          content.last['text'] << text.to_s
        end

        def streamed_interaction
          steps = @interaction_steps.sort.map do |_index, step|
            next step unless step['type'] == 'function_call'

            step.merge('arguments' => parse_interaction_arguments(step['arguments']))
          end
          @interaction_response.merge('steps' => steps)
        end

        def final_interaction_chunk
          message = parse_completion_body(streamed_interaction, raw: nil)
          Chunk.new(role: :assistant, content: nil, model: message.model, tokens: message.tokens,
                    citations: message.citations, tool_calls: message.tool_calls,
                    server_tool_calls: message.server_tool_calls, raw_content: message.raw_content,
                    attachments: message.attachments, finish_reason: message.finish_reason)
        end
      end
    end
  end
end
