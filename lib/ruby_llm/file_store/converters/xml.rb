# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      # The little XML reading the Office converter and the HTML converter
      # share.
      module XML # :nodoc:
        ENTITIES = { 'amp' => '&', 'lt' => '<', 'gt' => '>', 'quot' => '"', 'apos' => "'", 'nbsp' => ' ' }.freeze

        module_function

        def unescape(text)
          text.gsub(/&(#x\h+|#\d+|[a-z]+);/i) do
            entity = Regexp.last_match(1)
            if entity.start_with?('#x', '#X') then [entity[2..].to_i(16)].pack('U')
            elsif entity.start_with?('#') then [entity[1..].to_i].pack('U')
            else ENTITIES.fetch(entity.downcase, "&#{entity};")
            end
          rescue RangeError
            ''
          end
        end

        def strip(xml)
          unescape(xml.gsub(/<[^>]*>/, ''))
        end

        def attribute(tag, name)
          tag[/\s#{Regexp.escape(name)}="([^"]*)"/, 1]&.then { |value| unescape(value) }
        end
      end
    end
  end
end
