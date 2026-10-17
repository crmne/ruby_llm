# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      # Reads Word documents paragraph by paragraph, Excel workbooks sheet
      # by sheet with tab-separated cells, and PowerPoint decks slide by
      # slide. Needs no gems: the files are zipped XML.
      module Office # :nodoc:
        BREAKS = { 'w:tab' => "\t", 'a:tab' => "\t", 'w:br' => "\n", 'a:br' => "\n", 'w:cr' => "\n",
                   '/w:tc' => "\t" }.freeze
        SLIDE = %r{\Appt/slides/slide(\d+)\.xml\z}
        STRING_STATES = { 't' => 't', '/t' => nil, 'rph' => 'rph', '/rph' => nil }.freeze

        module_function

        def call(attachment)
          zip = Zip.new(attachment.content.to_s.b)
          if zip.include?('word/document.xml') then word(zip)
          elsif zip.include?('xl/workbook.xml') then excel(zip)
          elsif zip.names.any? { |name| name.match?(SLIDE) } then powerpoint(zip)
          end
        rescue Zip::Error => e
          RubyLLM.logger.debug { "Could not read an Office file: #{e.message}" }
          nil
        end

        def word(zip)
          paragraphs(zip.read('word/document.xml'), '/w:p')
        end

        def powerpoint(zip)
          slides = zip.names.filter_map { |name| name[SLIDE, 1]&.to_i }.sort
          slides.map do |number|
            "## Slide #{number}\n\n#{paragraphs(zip.read("ppt/slides/slide#{number}.xml"), '/a:p')}"
          end.join("\n\n")
        end

        def excel(zip)
          strings = shared_strings(zip)
          sheets(zip).map do |name, path|
            rows = zip.include?(path) ? Cells.new(strings).read(zip.read(path)) : []
            "## Sheet: #{name}\n\n#{rows.join("\n")}"
          end.join("\n\n")
        end

        def paragraphs(xml, paragraph)
          lines = [+'']
          XML.each(xml) do |kind, value|
            next lines.last << value if kind == :text
            next lines << +'' if value == paragraph

            lines.last << BREAKS.fetch(value, '')
          end
          lines.map { |line| XML.unescape(line).rstrip }.join("\n").strip
        end

        def shared_strings(zip)
          return [] unless zip.include?('xl/sharedStrings.xml')

          strings = []
          state = nil
          XML.each(zip.read('xl/sharedStrings.xml')) do |kind, value|
            next strings.last << value if kind == :text && state == 't'

            strings << +'' if value == 'si'
            state = string_state(state, value)
          end
          strings.map { |string| XML.unescape(string) }
        end

        def string_state(state, tag)
          state == 'rph' && tag != '/rph' ? state : STRING_STATES.fetch(tag, state)
        end

        def sheets(zip)
          targets = relationships(zip)
          tags(zip.read('xl/workbook.xml'), 'sheet').map do |tag|
            target = targets[XML.attribute(tag, 'r:id')].to_s.delete_prefix('/xl/').delete_prefix('/')
            [XML.attribute(tag, 'name'), "xl/#{target}"]
          end
        end

        def relationships(zip)
          return {} unless zip.include?('xl/_rels/workbook.xml.rels')

          tags(zip.read('xl/_rels/workbook.xml.rels'), 'relationship').to_h do |tag|
            [XML.attribute(tag, 'Id'), XML.attribute(tag, 'Target')]
          end
        end

        def tags(xml, name)
          found = []
          XML.each(xml) { |kind, value, source| found << source if kind == :tag && value == name }
          found
        end
      end
    end
  end
end
