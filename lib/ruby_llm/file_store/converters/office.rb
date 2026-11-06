# frozen_string_literal: true

require 'zlib'

module RubyLLM
  class FileStore
    module Converters
      # Reads the text of Word documents, Excel workbooks, and PowerPoint
      # decks (.docx, .xlsx, .pptx) on this machine, with no service and no
      # cost: a paragraph per line, a table or sheet row per line with tabs
      # between cells, and a heading for each sheet and slide, with a slide's
      # speaker notes under it. Excel dates read as dates, like 2026-03-31.
      # Text comes back in document order, without layout or images.
      module Office
        TYPES = {
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => :document,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => :workbook,
          'application/vnd.openxmlformats-officedocument.presentationml.presentation' => :deck
        }.freeze # :nodoc:
        MAX_SIZE = 50 * 1024 * 1024 # :nodoc:

        class << self
          # Returns the text of +attachment+, or +nil+ when it is not a
          # document, workbook, or deck it can read. A file it can't read
          # never raises.
          def call(attachment)
            kind = TYPES[attachment.mime_type]
            return unless kind

            send(kind, Zip.new(attachment.content.to_s.b))
          rescue Zip::Error, Zlib::Error
            nil
          rescue StandardError => e
            RubyLLM.logger.warn { "Could not read an Office file: #{e.class}" }
            nil
          end

          # Returns +true+: it reads files on this machine, for free.
          def local?
            true
          end

          private

          def document(zip)
            Prose.lines(zip['word/document.xml']).join("\n")
          end

          def workbook(zip)
            sheets = parts(zip, 'xl/workbook.xml', 'sheet', %r{\Axl/worksheets/[^/]+\.xml\z})
            Workbook.new(zip, sheets).text
          end

          def deck(zip)
            slides = parts(zip, 'ppt/presentation.xml', 'sldId', %r{\Appt/slides/[^/]+\.xml\z})
            slides.each_with_index.map do |(part, _tag), index|
              notes = notes_of(zip, part)
              sections = ["## Slide #{index + 1}", Prose.lines(zip[part]).join("\n")]
              sections << "Speaker notes:\n#{notes.join("\n")}" if notes.any?
              sections.reject(&:empty?).join("\n\n")
            end.join("\n\n")
          end

          def notes_of(zip, slide)
            notes = relationships(zip, slide).find { |relationship| relationship[:type]&.end_with?('/notesSlide') }
            notes ? Prose.lines(zip[notes[:target]]) : []
          end

          # Returns each part the +owner+ lists with a +tag+, in its order,
          # with that tag, or the parts matching +fallback+ in name order
          # when the listing doesn't resolve.
          def parts(zip, owner, tag, fallback)
            targets = relationships(zip, owner).to_h { |relationship| relationship.values_at(:id, :target) }
            listed = Markup.tags(zip[owner], tag).filter_map do |element|
              part = targets[Markup.attribute(element, 'r:id')]
              [part, element] if part && zip.include?(part)
            end
            return listed if listed.any?

            zip.names.grep(fallback).sort_by { |name| name[/\d+/].to_i }.map { |name| [name, nil] }
          end

          def relationships(zip, part)
            folder, _, file = part.rpartition('/')
            Markup.tags(zip["#{folder}/_rels/#{file}.rels"], 'Relationship').map do |element|
              { id: Markup.attribute(element, 'Id'), type: Markup.attribute(element, 'Type'),
                target: resolve(folder, Markup.attribute(element, 'Target').to_s) }
            end
          end

          def resolve(folder, target)
            base = target.start_with?('/') ? [] : folder.split('/')
            segments = target.split('/').each_with_object(base) do |segment, path|
              next if segment.empty? || segment == '.'

              segment == '..' ? path.pop : path.push(segment)
            end
            segments.join('/').force_encoding(Encoding::UTF_8)
          end
        end
      end
    end
  end
end
