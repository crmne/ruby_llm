# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Meta
      module Transcription
        # Assembles a transcript from Meta's voice events. Without turns the
        # transcript arrives whole in the final transcript event. With turns
        # each speechComplete carries a turn's final text, and the transcript,
        # speaker, and timing events between speechStart and it belong to the
        # most recently opened turn. Turns can overlap and finish out of order,
        # so each is held until every turn opened before it has finished.
        class Stream # :nodoc:
          def initialize(model:, &block)
            @model = model
            @block = block
            @turns = {}
            @segments = []
            @latest_ms = 0
          end

          def process(event)
            @latest_ms = [@latest_ms, event['audioProcessedMs'].to_i].max
            @last_event = event
            case event['type']
            when 'transcript' then process_transcript(event)
            when 'speechStart' then open_turn(event)
            when 'speaker' then @turns[@current_turn]&.store(:speaker, event['label'])
            when 'speechEnd' then @turns[event['turnId']]&.store(:end_ms, event['audioProcessedMs'])
            when 'speechComplete' then complete_turn(event)
            when 'error' then raise Error, event['message'] || 'Meta transcription failed'
            end
          end

          def finish
            raise Error, 'Meta transcription ended before its final transcript' unless complete?

            duration = @latest_ms / 1000.0
            result = RubyLLM::Transcription.new(
              text: @turns.empty? ? @final_text : @segments.map { |segment| segment['text'] }.join(' '),
              model: @model, duration:, audio_seconds: duration, segments: @segments.empty? ? nil : @segments
            )
            @block.call(TranscriptionChunk.new(type: TranscriptionChunk::DONE, text: result.text, raw: @last_event))
            result
          end

          private

          def process_transcript(event)
            text = event['transcript'].to_s.strip
            return finish_transcript(text, event) if event['final']
            return if text.empty?

            @block.call(TranscriptionChunk.new(type: TranscriptionChunk::PARTIAL, text:, raw: event))
          end

          def finish_transcript(text, event)
            @final_text = text
            return if text.empty? || @turns.any?

            @block.call(TranscriptionChunk.new(type: TranscriptionChunk::DELTA, delta: text, raw: event))
          end

          def open_turn(event)
            @current_turn = event['turnId']
            @turns[@current_turn] = { start_ms: event['audioProcessedMs'] }
          end

          def complete_turn(event)
            turn = @turns[event['turnId']] ||= {}
            text = event['transcript'].to_s.strip
            segment = text.empty? ? nil : turn_segment(event['turnId'], text, turn, event)
            turn.merge!(complete: true, segment:, event:)
            emit_completed_turns
          end

          def emit_completed_turns
            @turns.each_value do |turn|
              break unless turn[:complete]

              emit_turn(turn) unless turn[:emitted]
            end
          end

          def emit_turn(turn)
            turn[:emitted] = true
            segment = turn[:segment]
            return unless segment

            delta = @segments.empty? ? segment['text'] : " #{segment['text']}"
            @segments << segment
            @block.call(TranscriptionChunk.new(type: TranscriptionChunk::SEGMENT, delta:, segment:, raw: turn[:event]))
          end

          def turn_segment(turn_id, text, turn, event)
            end_ms = turn[:end_ms] || event['audioProcessedMs']
            { 'text' => text, 'turnId' => turn_id, 'start' => turn[:start_ms] && (turn[:start_ms] / 1000.0),
              'end' => end_ms && (end_ms / 1000.0), 'speaker' => turn[:speaker] }.compact
          end

          def complete?
            @turns.values.all? { |turn| turn[:complete] } && (!@final_text.nil? || @segments.any?)
          end
        end
      end
    end
  end
end
