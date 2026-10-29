# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Gemini can pause a long response with a continuation token. Each
      # hop resends the same request with the newest token, and the hops
      # join into one assistant message.
      module LongDecode # :nodoc:
        def complete(messages, **, &)
          @unfinished = messages.last if messages.last&.continuation
          super
        end

        def complete_request(payload, headers, usage_recorder: nil, progress_recorder: nil, &)
          segments = [@unfinished].compact
          parts = Array(@unfinished&.raw_content)

          loop do
            hop = super(payload, headers, usage_recorder:, &)
            segments << hop
            parts.concat(hop_parts(hop))
            return segments.one? ? hop : join_hops(segments, parts) unless hop.continuation

            if segments[...-1].any? { |segment| segment.continuation == hop.continuation }
              raise Error.new('Gemini repeated a continuation token', response: hop.raw)
            end

            progress_recorder&.call(join_hops(segments, parts, continuation: hop.continuation))
            payload = payload.merge(continuationToken: hop.continuation)
          end
        end

        private

        def stream_response(...)
          @stream_parts = @stream_metadata_calls = @stream_citation_parts = nil
          super
        end

        def hop_parts(hop)
          hop.raw_content || @stream_parts || hop.raw&.body&.dig('candidates', 0, 'content', 'parts') || []
        end

        def join_hops(segments, parts, continuation: nil)
          final = segments.last
          Message.new(
            role: :assistant,
            content: join_text(segments.map(&:content)),
            thinking: join_thinking(segments),
            attachments: segments.flat_map(&:attachments),
            citations: join_citations(segments),
            tool_calls: join_tool_calls(segments),
            server_tool_calls: segments.flat_map(&:server_tool_calls),
            raw_content: join_raw_content(parts, continuation),
            continuation: continuation,
            tokens: Tokens.aggregate(segments.map(&:tokens)),
            usage_entries: segments.flat_map(&:ruby_llm_usage_entries),
            finish_reason: final.finish_reason,
            model: final.model,
            raw: final.raw
          )
        end

        def join_text(values)
          text = values.compact.join
          text unless text.empty?
        end

        def join_thinking(segments)
          thoughts = segments.filter_map(&:thinking)
          Thinking.build(text: join_text(thoughts.map(&:text)), signature: thoughts.filter_map(&:signature).last)
        end

        def join_tool_calls(segments)
          calls = segments.filter_map(&:tool_calls).reduce({}, :merge)
          calls unless calls.empty?
        end

        def join_raw_content(parts, continuation)
          return without_search_suggestions(parts) if continuation
          return unless parts.any? { |part| server_tool_part?(part) } ||
                        parts.count { |part| part['thoughtSignature'] } > 1

          without_search_suggestions(parts)
        end

        def join_citations(segments)
          offset = 0
          segments.flat_map do |segment|
            citations = segment.citations.map do |citation|
              next citation unless citation.start_index

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
