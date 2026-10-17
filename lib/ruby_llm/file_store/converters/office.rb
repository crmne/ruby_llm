# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      # Reads Word documents paragraph by paragraph, Excel workbooks sheet
      # by sheet with tab-separated cells, and PowerPoint decks slide by
      # slide. Needs no gems: the files are zipped XML.
      module Office # :nodoc:
        module_function

        def call(attachment)
          zip = Zip.new(attachment.content.to_s.b)
          if zip.include?('word/document.xml') then word(zip)
          elsif zip.include?('xl/workbook.xml') then excel(zip)
          elsif zip.names.any? { |name| name.match?(%r{\Appt/slides/slide\d+\.xml\z}) } then powerpoint(zip)
          end
        rescue Zip::Error => e
          RubyLLM.logger.debug { "Could not read an Office file: #{e.message}" }
          nil
        end

        def word(zip)
          paragraphs(zip.read('word/document.xml'), paragraph: 'w:p', cell: 'w:tc')
        end

        def powerpoint(zip)
          slides = zip.names.filter_map { |name| name[%r{\Appt/slides/slide(\d+)\.xml\z}, 1]&.to_i }.sort
          slides.map do |number|
            "## Slide #{number}\n\n#{paragraphs(zip.read("ppt/slides/slide#{number}.xml"), paragraph: 'a:p')}"
          end.join("\n\n")
        end

        def excel(zip)
          strings = shared_strings(zip)
          sheets(zip).map do |name, path|
            rows = zip.include?(path) ? rows(zip.read(path), strings) : []
            "## Sheet: #{name}\n\n#{rows.join("\n")}"
          end.join("\n\n")
        end

        def paragraphs(xml, paragraph:, cell: nil)
          xml = xml.gsub(%r{<w:tab/>|<a:tab/>}, "\t").gsub(%r{<w:br/>|<a:br/>|<w:cr/>}, "\n")
          xml = xml.gsub(%r{</#{cell}>}, "\t") if cell
          xml.split(%r{</#{paragraph}>}).map { |part| XML.strip(part).rstrip }.join("\n").strip
        end

        def shared_strings(zip)
          return [] unless zip.include?('xl/sharedStrings.xml')

          zip.read('xl/sharedStrings.xml').scan(%r{<si>(.*?)</si>}m).map do |(item)|
            XML.unescape(item.gsub(%r{<rPh\b.*?</rPh>}m, '').scan(%r{<t(?:\s[^>]*)?>(.*?)</t>}m).join)
          end
        end

        def sheets(zip)
          targets = relationships(zip)
          zip.read('xl/workbook.xml').scan(/<sheet\s[^>]*>/).map do |tag|
            target = targets[XML.attribute(tag, 'r:id')].to_s.delete_prefix('/xl/').delete_prefix('/')
            [XML.attribute(tag, 'name'), "xl/#{target}"]
          end
        end

        def relationships(zip)
          return {} unless zip.include?('xl/_rels/workbook.xml.rels')

          zip.read('xl/_rels/workbook.xml.rels').scan(/<Relationship\s[^>]*>/).to_h do |tag|
            [XML.attribute(tag, 'Id'), XML.attribute(tag, 'Target')]
          end
        end

        def rows(xml, strings)
          xml.scan(%r{<row\b[^>]*>(.*?)</row>}m).map do |(row)|
            cells = []
            row.scan(%r{<c\b([^>]*?)(?:/>|>(.*?)</c>)}m).each do |attributes, body|
              column = column_index(XML.attribute(" #{attributes}", 'r')) || cells.size
              cells[column] = value(XML.attribute(" #{attributes}", 't'), body.to_s, strings)
            end
            cells.join("\t").rstrip
          end
        end

        def column_index(reference)
          letters = reference.to_s[/\A[A-Z]+/]
          letters&.each_char&.reduce(0) { |index, letter| (index * 26) + (letter.ord - 64) }&.-(1)
        end

        def value(type, body, strings)
          raw = body[%r{<v>(.*?)</v>}m, 1]
          case type
          when 's' then strings[raw.to_i]
          when 'inlineStr' then XML.unescape(body.scan(%r{<t(?:\s[^>]*)?>(.*?)</t>}m).join)
          when 'b' then raw == '1' ? 'TRUE' : 'FALSE'
          else raw && XML.unescape(raw)
          end
        end
      end
    end
  end
end
