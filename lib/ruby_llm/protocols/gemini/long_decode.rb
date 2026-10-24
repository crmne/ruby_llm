# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      module LongDecode # :nodoc:
        def complete_request(payload, headers, usage_recorder: nil, &)
          original = Support::Utils.deep_dup(payload)
          segments = []
          parts = []
          seen = [payload[:continuationToken]].compact

          loop do
            @continuation_token = nil
            @response_parts = []
            message = super(payload, headers, usage_recorder:, &)
            segments << message
            parts.concat(@response_parts)
            break unless message.finish_reason == :continuation

            token = @continuation_token
            if token.to_s.empty? || seen.include?(token)
              raise Error.new('Gemini returned CONTINUATION without a new continuation token', response: message.raw)
            end

            seen << token
            payload = Support::Utils.deep_dup(original).merge(continuationToken: token)
          end
          segments.one? ? segments.first : merge_decode_segments(segments, parts)
        ensure
          @continuation_token = nil
          @response_parts = nil
        end

        private

        def sync_response(payload, additional_headers = {})
          super.tap do |message|
            @response_parts = message.raw.body.dig('candidates', 0, 'content', 'parts') || []
            @continuation_token = message.raw.body.dig('candidates', 0, 'continuationToken')
          end
        end

        def stream_response(...)
          @stream_parts = []
          @stream_metadata_calls = []
          @saw_server_part = false
          super.tap { @response_parts = @stream_parts }
        end

        def merge_decode_segments(segments, parts)
          final = segments.last
          Message.new(
            role: :assistant,
            content: decode_text(segments.map(&:content)),
            thinking: decode_thinking(segments),
            attachments: segments.flat_map(&:attachments),
            citations: decode_citations(segments),
            tool_calls: decode_tool_calls(segments),
            server_tool_calls: segments.flat_map(&:server_tool_calls),
            raw_content: decode_raw_content(segments, parts),
            tokens: Tokens.aggregate(segments.map(&:tokens)),
            usage_entries: segments.flat_map(&:ruby_llm_usage_entries),
            finish_reason: final.finish_reason,
            model: final.model,
            raw: final.raw
          )
        end

        def decode_text(values)
          text = values.compact.join
          text unless text.empty?
        end

        def decode_thinking(segments)
          thoughts = segments.filter_map(&:thinking)
          Thinking.build(text: decode_text(thoughts.map(&:text)), signature: thoughts.filter_map(&:signature).last)
        end

        def decode_tool_calls(segments)
          calls = segments.filter_map(&:tool_calls).reduce({}, :merge)
          calls unless calls.empty?
        end

        def decode_raw_content(segments, parts)
          return unless segments.any?(&:raw_content) || parts.count { |part| part['thoughtSignature'] } > 1

          without_search_suggestions(parts)
        end

        def decode_citations(segments)
          offset = 0
          segments.flat_map do |segment|
            citations = segment.citations.map do |citation|
              next citation unless citation.start_index && citation.end_index

              Citation.new(citation.to_h.merge(start_index: citation.start_index + offset,
                                               end_index: citation.end_index + offset))
            end
            offset += segment.content.to_s.length
            citations
          end
        end
      end
    end
  end
end
