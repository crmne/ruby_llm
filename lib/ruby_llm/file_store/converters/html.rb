# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      # Reads HTML as its text: scripts, styles, and tags dropped, blocks on
      # lines of their own.
      module HTML # :nodoc:
        BLOCKS = %w[/p /div /li /tr /h1 /h2 /h3 /h4 /h5 /h6 /section /article /header /footer /blockquote /pre /table
                    br br/].freeze
        HIDDEN = %w[script style template noscript].freeze

        module_function

        def call(attachment)
          parts = []
          hidden = nil
          XML.each(Text.call(attachment)) do |kind, value|
            next parts << value if kind == :text && hidden.nil?
            next hidden = nil if value == "/#{hidden}"
            next if hidden

            hidden = value if HIDDEN.include?(value)
            parts << "\n" if BLOCKS.include?(value)
          end
          tidy(XML.unescape(parts.join))
        end

        def tidy(text)
          text.gsub(/[ \t\r\f]+/, ' ').gsub(/ ?\n ?/, "\n").gsub(/\n{3,}/, "\n\n").strip
        end
      end
    end
  end
end
