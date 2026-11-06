# frozen_string_literal: true

module RubyLLM
  class FileStore
    module Converters
      module Office
        # What a Word paragraph's style and numbering make of it: a Markdown
        # heading, or a list marker with the count Word would show. A style
        # is a heading by its outline level, the nearest one along +basedOn+,
        # which also covers localized names, or else by being named
        # <tt>heading 1</tt> to <tt>heading 6</tt>. Numbers are always
        # decimal, without a level's own format or text. Missing or broken
        # parts mark nothing.
        class Outline # :nodoc:
          HEADING_NAME = /\Aheading ([1-6])\z/i
          HEADING_LEVELS = (0..5)
          MAX_CHAIN = 32
          MAX_LEVEL = 8
          NO_LIST = 0
          private_constant :HEADING_NAME, :HEADING_LEVELS, :MAX_CHAIN, :MAX_LEVEL, :NO_LIST

          def self.read(zip)
            new(part(zip, 'word/styles.xml'), part(zip, 'word/numbering.xml'))
          end

          def self.part(zip, name)
            zip[name]
          rescue Zip::Error, Zlib::Error
            nil
          end
          private_class_method :part

          def initialize(styles, numbering)
            @styles = {}
            @resolved = {}
            @abstracts = {}
            @lists = {}
            @counts = Hash.new { |counts, abstract| counts[abstract] = {} }
            @overridden = {}
            read_styles(styles)
            read_numbering(numbering)
          end

          # Returns the marker for a paragraph with these properties of its
          # own, counting it if it is a list item.
          def marker(style:, list:, level:, outline:)
            inherited = resolve(style)
            heading = outline ? heading_of(outline) : inherited[:heading]
            return "#{'#' * heading} " if heading

            item(list || inherited[:list], level || inherited[:level] || 0)
          end

          private

          def heading_of(outline)
            outline + 1 if HEADING_LEVELS.cover?(outline)
          end

          def resolve(id)
            @resolved[id] ||= resolve_chain(id)
          end

          # Walks at most MAX_CHAIN styles, which also ends a basedOn cycle.
          def resolve_chain(id)
            found = {}
            MAX_CHAIN.times do
              style = @styles[id]
              break unless style

              found = style.merge(found)
              id = style[:based_on]
            end
            heading = found.key?(:outline) ? heading_of(found[:outline]) : found[:named]
            { heading:, list: found[:list], level: found[:level] }
          end

          def item(list_id, level)
            return '' if list_id.nil? || list_id == NO_LIST

            list = @lists[list_id]
            definition = list && @abstracts.dig(list[:abstract], level)
            return '' unless definition

            count = next_count(list_id, list, level, definition)
            render(definition[:format], count, level)
          end

          def render(format, count, level)
            case format
            when 'none' then ''
            when 'bullet' then "#{'  ' * level}- "
            else "#{'  ' * level}#{count}. "
            end
          end

          def next_count(list_id, list, level, definition)
            counts = @counts[list[:abstract]]
            override = list[:overrides][level]
            if override && !@overridden[[list_id, level]]
              @overridden[[list_id, level]] = true
              counts[level] = override - 1
            end
            counts[level] = (counts[level] || (definition[:start] - 1)) + 1
            counts.delete_if { |deeper, _count| deeper > level }
            counts[level]
          end

          def read_styles(xml)
            style = nil
            Markup.scan(xml) do |kind, name, tag|
              next if kind == :text || name.nil?
              next style = nil if kind == :close && name == 'style'
              next if kind == :close

              name == 'style' ? style = open_style(tag) : (style_property(style, name, tag) if style)
            end
          end

          def open_style(tag)
            return unless Markup.prefixed(tag, 'type') == 'paragraph'

            id = Markup.prefixed(tag, 'styleId')
            @styles[id] = {} if id
          end

          def style_property(style, name, tag)
            case name
            when 'name' then assign(style, :named, Markup.prefixed(tag, 'val').to_s[HEADING_NAME, 1]&.to_i)
            when 'basedOn' then style[:based_on] = Markup.prefixed(tag, 'val')
            when 'outlineLvl' then assign(style, :outline, integer(tag))
            when 'numId' then assign(style, :list, integer(tag))
            when 'ilvl' then assign(style, :level, level_of(tag))
            end
          end

          def assign(style, key, value)
            style[key] = value unless value.nil?
          end

          def read_numbering(xml)
            state = {}
            Markup.scan(xml) do |kind, name, tag|
              next if kind == :text

              kind == :close ? close_numbering(state, name) : open_numbering(state, name, tag)
            end
          end

          def open_numbering(state, name, tag)
            case name
            when 'abstractNum' then state[:abstract] = @abstracts[integer(tag, 'abstractNumId')] = {}
            when 'lvl' then open_level(state, tag)
            when 'start' then state[:level][:start] = integer(tag) || 0 if state[:level]
            when 'numFmt' then state[:level][:format] = Markup.prefixed(tag, 'val') if state[:level]
            when 'num' then state[:list] = @lists[integer(tag, 'numId')] = { overrides: {} }
            when 'abstractNumId' then state[:list][:abstract] = integer(tag) if state[:list]
            when 'lvlOverride' then state[:override] = level_of(tag, 'ilvl')
            when 'startOverride' then start_override(state, integer(tag))
            end
          end

          def open_level(state, tag)
            level = level_of(tag, 'ilvl')
            state[:level] = (state[:abstract][level] = { start: 0 } if state[:abstract] && level)
          end

          def start_override(state, value)
            state[:list][:overrides][state[:override]] = value if state[:list] && state[:override] && value
          end

          def close_numbering(state, name)
            case name
            when 'abstractNum' then state[:abstract] = nil
            when 'lvl' then state[:level] = nil
            when 'num' then state[:list] = nil
            when 'lvlOverride' then state[:override] = nil
            end
          end

          def integer(tag, attribute = 'val')
            Markup.prefixed(tag, attribute).to_s[/\A\d{1,9}\z/]&.to_i
          end

          def level_of(tag, attribute = 'val')
            level = integer(tag, attribute)
            level if level && level <= MAX_LEVEL
          end
        end
      end
    end
  end
end
