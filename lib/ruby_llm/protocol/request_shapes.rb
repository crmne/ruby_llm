# frozen_string_literal: true

require 'json'

module RubyLLM
  class Protocol
    # Builds the RequestShape a protocol returns from parse_request_shape. A
    # protocol reads its payload into turns of parts, keeping each piece's
    # size and never its content, and hands them to shape_request with the
    # rules its provider enforces; Analysis then finds the problems.
    module RequestShapes # :nodoc: all
      SETTING_VALUE = /\A[\w.-]{1,40}\z/

      # A piece of a turn as a protocol reads it, with the ids and flags the
      # analysis needs and a shape never shows.
      PartSpec = Struct.new(:kind, :measure, :unit, :name, :source, :mime_type, :signed, :call_id, :result_id,
                            :without_data, keyword_init: true) do
        def call?
          kind == :tool_call
        end

        def result?
          kind == :tool_result
        end

        def to_part
          RequestShape::Part.new(kind:, size: measure, unit:, name:, source:, mime_type:, signed: signed || false)
        end
      end

      # A turn as a protocol reads it. Its speaker, +:system+, +:user+,
      # +:model+, or +:tool+, tells the analysis whose turn it is.
      TurnSpec = Struct.new(:index, :role, :speaker, :parts, keyword_init: true) do
        def model?
          speaker == :model
        end

        def to_turn
          RequestShape::Turn.new(index:, role:, parts: parts.map(&:to_part))
        end
      end

      private

      def shape_request(turns, payload:, instructions: [], tool_names: [], thinking_settings: {}, pairing: :id,
                        rules: [])
        analysis = Analysis.new(turns, pairing:, rules:)
        kept = analysis.kept_turns
        RequestShape.new(
          provider: @provider&.slug, model: @model&.id, step: analysis.step, payload_keys: payload.keys,
          thinking_settings: thinking_settings, instructions: instructions.map(&:to_part),
          turns: kept.map(&:to_turn), turn_count: turns.size, omitted_turns: turns.size - kept.size,
          tool_names: shape_list(tool_names).filter_map { |name| shape_name(name) },
          tool_rounds: analysis.tool_rounds, problems: analysis.problems
        )
      end

      def shape_turn(index, role, speaker, parts)
        TurnSpec.new(index:, role: shape_name(role), speaker:, parts: parts.flatten.compact)
      end

      # A turn on the user's side that carries tool results answers a model
      # turn instead of starting a new one.
      def shape_answer(parts)
        parts.flatten.compact.any?(&:result?) ? :tool : :user
      end

      def shape_text(text, kind: :text, signed: false)
        PartSpec.new(kind:, measure: shape_length(text), signed:, without_data: kind == :text && text.nil?)
      end

      def shape_tool_call(name, arguments, id: nil, signed: false)
        PartSpec.new(kind: :tool_call, name: shape_name(name), measure: shape_length(arguments),
                     call_id: shape_name(id), signed:)
      end

      # A result made of content blocks counts the characters of its text,
      # and its other blocks, such as images, follow it as parts of their
      # own. The block reads one content block in the protocol's format.
      def shape_tool_result(content, name: nil, id: nil)
        result = PartSpec.new(kind: :tool_result, name: shape_name(name), result_id: shape_name(id))
        unless content.is_a?(Array) && block_given?
          result.measure = shape_length(content)
          return [result]
        end

        texts, others = content.flat_map { |block| yield shape_hash(block) }.partition { |part| part.kind == :text }
        result.measure = texts.sum { |part| part.measure.to_i }
        [result, *others]
      end

      def shape_other(name, signed: false)
        PartSpec.new(kind: :other, name: shape_name(name), signed:)
      end

      def shape_media(kind, source:, size: nil, unit: nil, mime_type: nil, signed: false)
        mime_type = shape_name(mime_type)
        PartSpec.new(kind: kind || shape_media_kind(mime_type), measure: size, unit:, source:, mime_type:, signed:)
      end

      def shape_inline(data, kind: nil, mime_type: nil, signed: false)
        shape_media(kind, source: :inline, size: shape_bytes(data), unit: :bytes, mime_type:, signed:)
      end

      def shape_file(kind: nil, mime_type: nil)
        shape_media(kind, source: :file, mime_type:)
      end

      def shape_media_kind(mime_type)
        type = mime_type.to_s
        return :image if Files::MimeType.image?(type)
        return :audio if Files::MimeType.audio?(type)
        return :video if Files::MimeType.video?(type)

        :document
      end

      # Thinking settings are short words and numbers, such as an effort or
      # a budget, so anything else is left out rather than risk content.
      def shape_settings(settings, *names)
        shape_hash(settings).slice(*names).select do |_, value|
          [Integer, Float, TrueClass, FalseClass].any? { |type| value.is_a?(type) } ||
            (value.is_a?(String) && value.match?(SETTING_VALUE))
        end
      end

      def shape_signature?(signature)
        signature.is_a?(String) && !signature.empty?
      end

      def shape_name(value)
        value if value.is_a?(String) && !value.empty?
      end

      def shape_length(value)
        case value
        when nil then nil
        when String then value.length
        else JSON.generate(value).length
        end
      end

      # Base64 carries three bytes in every four characters, and its padding
      # marks the missing bytes of the last group.
      def shape_bytes(data)
        return unless data.is_a?(String)

        ((data.length - data.count("\r\n")) * 3 / 4) - [data.count('='), 2].min
      end

      def shape_hash(value)
        value.is_a?(Hash) ? value : {}
      end

      def shape_list(value)
        value.is_a?(Array) ? value : []
      end
    end
  end
end
