# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      # Reads HTML as its text: scripts, styles, and tags dropped, blocks on
      # lines of their own.
      module HTML # :nodoc:
        BLOCKS = %r{<\s*br\b[^>]*>|<\s*/\s*(?:p|div|li|tr|h[1-6]|section|article|header|footer|blockquote|pre
                    |table)\s*>}ix
        HIDDEN = %r{<\s*(script|style|template|noscript)\b[^>]*>.*?<\s*/\s*\1\s*>}im

        module_function

        def call(attachment)
          html = Text.call(attachment)
          text = html.gsub(/<!--.*?-->/m, '').gsub(HIDDEN, '').gsub(BLOCKS, "\n").gsub(/<[^>]*>/, '')
          XML.unescape(text).gsub(/[ \t\r\f]+/, ' ').gsub(/ *\n */, "\n").gsub(/\n{3,}/, "\n\n").strip
        end
      end
    end
  end
end
