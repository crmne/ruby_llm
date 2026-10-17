# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      # The little XML reading the Office and HTML converters share: a
      # scanner that walks a document once, in time linear in its length,
      # so a hostile file cannot make it slow.
      module XML # :nodoc:
        ENTITIES = { 'amp' => '&', 'lt' => '<', 'gt' => '>', 'quot' => '"', 'apos' => "'", 'nbsp' => ' ' }.freeze
        ENTITY = /&(#x\h{1,8}|#\d{1,8}|[a-z]{1,8});/i

        module_function

        # Yields <tt>[:text, text]</tt> for the text between tags, and
        # <tt>[:tag, name, source]</tt> for each tag, its name lowercased with
        # a leading slash for a closing tag. Comments, declarations, and
        # processing instructions are skipped, and a <tt><</tt> that opens
        # no tag is text.
        def each(xml)
          position = 0
          while position < xml.length
            opening = xml.index('<', position) || xml.length
            yield :text, xml[position...opening] if opening > position
            break if opening == xml.length

            position = skip(xml, opening) { |source| yield :tag, name_of(source), source }
            next if position

            yield :text, xml[opening..]
            break
          end
        end

        def text(xml)
          parts = []
          each(xml) { |kind, value| parts << value if kind == :text }
          unescape(parts.join)
        end

        def unescape(text)
          text.gsub(ENTITY) do
            entity = Regexp.last_match(1)
            if entity.start_with?('#x', '#X') then [entity[2..].to_i(16)].pack('U')
            elsif entity.start_with?('#') then [entity[1..].to_i].pack('U')
            else ENTITIES.fetch(entity.downcase, "&#{entity};")
            end
          rescue RangeError
            ''
          end
        end

        def attribute(source, name)
          start = source.index(" #{name}=\"") || source.index("\t#{name}=\"") || source.index("\n#{name}=\"")
          return unless start

          from = start + name.length + 3
          finish = source.index('"', from)
          unescape(source[from...finish]) if finish
        end

        def skip(xml, opening)
          closer = xml[opening, 4] == '<!--' ? '-->' : '>'
          closing = xml.index(closer, opening + 1)
          return unless closing

          source = xml[(opening + 1)...closing]
          yield source unless closer == '-->' || source.start_with?('!', '?')
          closing + closer.length
        end

        def name_of(source)
          source.strip.split(/[\s>]/, 2).first.to_s.delete_suffix('/').downcase
        end
      end
    end
  end
end
