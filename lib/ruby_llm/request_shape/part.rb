# frozen_string_literal: true

module RubyLLM
  class RequestShape
    # A Part describes one piece of a turn by its kind and size, never by
    # its content.
    #
    #   part.kind    # => :tool_call
    #   part.name    # => "find_tasks"
    #   part.size    # => 42
    #   part.unit    # => :chars
    #   part.signed? # => true
    #   part.to_s    # => "call find_tasks (args 42 chars), signed"
    #
    class Part
      include Support::Inspectable

      TEXT_KINDS = %i[text thinking].freeze
      private_constant :TEXT_KINDS

      # The kind of piece: +:text+, +:thinking+, +:image+, +:audio+,
      # +:video+, +:document+, +:tool_call+, +:tool_result+, or +:other+
      # for a piece RubyLLM does not classify, such as a provider tool step.
      attr_reader :kind

      # The size of the piece as the request sends it, in #unit: the
      # characters of text, thinking, tool call arguments, and a tool
      # result's text, or of its JSON when it is structured data, and the
      # bytes of inline media. Media inside a tool result follows it as
      # parts of its own. Returns +nil+ when there is nothing to measure,
      # such as media sent by URL or thinking the provider encrypted.
      attr_reader :size

      # The unit of #size: +:chars+ or +:bytes+, or +nil+ without a size.
      attr_reader :unit

      # The tool's name for a tool call, and for a tool result the name of
      # the call it answers, which is +nil+ when no call in the request
      # matches it. For an +:other+ piece, the provider's name for it.
      attr_reader :name

      # Where media comes from: +:inline+ for bytes in the request, +:url+
      # for a link the provider fetches, or +:file+ for a file stored with
      # the provider. Returns +nil+ for pieces that are not media.
      attr_reader :source

      # The MIME type of media, as the request gives it or as its format
      # implies, or +nil+.
      attr_reader :mime_type

      # Creates a part. Every attribute but +kind+ is optional. A +size+
      # counts characters unless +unit+ says +:bytes+; pass +signed: true+
      # when the piece carries a thinking signature.
      def initialize(kind:, size: nil, unit: nil, name: nil, source: nil, mime_type: nil, signed: false)
        @kind = kind
        @size = size
        @unit = size && (unit || :chars)
        @name = name
        @source = source
        @mime_type = mime_type
        @signed = signed
      end

      # Returns whether the piece carries a thinking signature, the token a
      # provider issues to verify replayed thinking or tool calls.
      def signed?
        @signed
      end

      # Returns the part in words, with its size and unit:
      #
      #   text (13 chars)
      #   image/png (34512 bytes)
      #   document (url)
      #   result find_tasks (6859 chars)
      #   thinking (no text), signed
      #
      def to_s
        signed? ? "#{description}, signed" : description
      end

      # Returns the part as a Hash, with its size under its unit, omitting
      # attributes it does not have.
      def to_h
        hash = { kind: kind, name: name }
        hash[unit] = size if size
        hash.merge(source: source, mime_type: mime_type, signed: signed? || nil).compact
      end

      def inspect_attributes # :nodoc:
        to_h
      end

      private

      def description
        case kind
        when :tool_call then ['call', name, size && "(args #{measured})"].compact.join(' ')
        when :tool_result then ['result', name, size && "(#{measured})"].compact.join(' ')
        when :other then name || 'part of no known kind'
        else "#{mime_type || kind} (#{size ? measured : missing})"
        end
      end

      def measured
        noun = { chars: 'char', bytes: 'byte' }.fetch(unit, unit.to_s)
        "#{size} #{noun}#{'s' unless size == 1}"
      end

      def missing
        return source.to_s if source && source != :inline

        TEXT_KINDS.include?(kind) ? 'no text' : 'no data'
      end
    end
  end
end
