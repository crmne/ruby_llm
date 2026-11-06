# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      module Office
        # Walks the tags of an Office XML part from left to right, so its
        # time grows with the part's size whatever the part holds: nothing
        # backtracks over unclosed tags. Names lose their prefix, since
        # generators pick their own. Parts are binary Strings.
        class Markup # :nodoc:
          ENTITIES = { 'amp' => '&', 'lt' => '<', 'gt' => '>', 'quot' => '"', 'apos' => "'" }.freeze
          ENTITY = /&(?:#(\d+)|#x(\h+)|(amp|lt|gt|quot|apos));/
          NAME = %r{\A(?:[^\s:/]+:)?([^\s/]+)}
          ATTRIBUTES = Hash.new do |patterns, name|
            patterns[name] = /\s#{Regexp.escape(name)}=(?:"([^"]*)"|'([^']*)')/
          end
          RELATIONSHIP_ID = /\s[\w.-]+:id=(?:"([^"]*)"|'([^']*)')/
          SLASH = 47
          QUESTION = 63
          BANG = 33
          private_constant :ENTITIES, :ENTITY, :NAME, :ATTRIBUTES, :RELATIONSHIP_ID, :SLASH, :QUESTION, :BANG

          class << self
            # Yields <tt>:open</tt>, <tt>:empty</tt>, or <tt>:close</tt> with
            # each tag's name and its source, and <tt>:text</tt> with nil and
            # the text between tags, leaving out the elements named in +skip+.
            def scan(xml, skip: [], &)
              new(xml.to_s.b, skip, &).run
            end

            # Returns the source of each tag named +name+.
            def tags(xml, name)
              found = []
              scan(xml) { |kind, tag_name, source| found << source if tag_name == name && kind != :close }
              found
            end

            # Returns the value of an attribute in a tag's source, unescaped.
            def attribute(tag, name)
              match = ATTRIBUTES[name].match(tag.to_s)
              unescape(match[1] || match[2]) if match
            end

            # Returns the prefixed +id+ attribute of a tag's source, whatever
            # its prefix, which is how a part refers to a relationship.
            def relationship_id(tag)
              match = RELATIONSHIP_ID.match(tag.to_s)
              unescape(match[1] || match[2]) if match
            end

            # Returns +text+ as UTF-8, with the entities XML defines replaced.
            def unescape(text)
              text = text.to_s.dup.force_encoding(Encoding::UTF_8).scrub
              return text unless text.include?('&')

              text.gsub(ENTITY) do
                named = Regexp.last_match(3)
                next ENTITIES.fetch(named) if named

                character(Regexp.last_match(1)&.to_i || Regexp.last_match(2).to_i(16))
              end
            end

            private

            def character(code)
              [code].pack('U').then { |text| text.valid_encoding? ? text : '' }
            rescue RangeError
              ''
            end
          end

          def initialize(xml, skip, &block)
            @xml = xml
            @skip = skip
            @block = block
            @position = 0
            @skipping = nil
            @depth = 0
          end

          def run
            while (start = @xml.index('<', @position))
              finish = @xml.index('>', start)
              break unless finish

              @block.call(:text, nil, @xml.byteslice(@position, start - @position)) if start > @position && !@skipping
              @position = finish + 1
              tag(start, finish)
            end
          end

          private

          def tag(start, finish)
            first = @xml.getbyte(start + 1)
            return if [QUESTION, BANG].include?(first)

            if first == SLASH
              closing(name_of(@xml.byteslice(start + 2, finish - start - 2)))
            else
              opening(@xml.byteslice(start + 1, finish - start - 1))
            end
          end

          def opening(source)
            name = name_of(source)
            empty = source.end_with?('/')
            return count(name, empty) if @skipping
            return start_skipping(name) if !empty && @skip.include?(name)

            @block.call(empty ? :empty : :open, name, source)
          end

          def closing(name)
            return @block.call(:close, name, nil) unless @skipping

            @depth -= 1 if name == @skipping
            @skipping = nil if @depth.zero?
          end

          def count(name, empty)
            @depth += 1 if name == @skipping && !empty
          end

          def start_skipping(name)
            @skipping = name
            @depth = 1
          end

          def name_of(source)
            source[NAME, 1].to_s
          end
        end
      end
    end
  end
end
