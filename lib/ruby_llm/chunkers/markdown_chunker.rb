# frozen_string_literal: true

module RubyLLM
  module Chunkers
    # Splits markdown content into chunks while preserving document structure
    class MarkdownChunker < Chunker
      DEFAULT_MIN_SIZE = 500
      DEFAULT_MAX_SIZE = 2000
      HEADER_PATTERN = /^(\#{1,6})\s+(.+)$/
      CODE_BLOCK_PATTERN = /^```[\w]*$/ # Matches code block delimiters

      def initialize(min_size: DEFAULT_MIN_SIZE, max_size: DEFAULT_MAX_SIZE)
        super
        @min_size = min_size
        @max_size = max_size
      end

      def chunk(content)
        return [] if content.nil? || content.empty?

        sections = parse_sections(content)
        combine_sections(sections)
      end

      private

      def parse_sections(content)
        sections = []
        current_section = { headers: [], content: [], size: 0 }
        in_code_block = false
        header_stack = []

        content.split("\n").each do |line|
          # Handle code blocks
          if line.match?(CODE_BLOCK_PATTERN)
            in_code_block = !in_code_block
            current_section[:content] << line
            current_section[:size] += line.length + 1 # +1 for newline
            next
          end

          # Don't parse headers inside code blocks
          if !in_code_block && (header_match = line.match(HEADER_PATTERN))
            level = header_match[1].length
            title = header_match[2]

            # Clear header stack until we find a parent level
            header_stack.pop while !header_stack.empty? && header_stack.last[:level] >= level

            # Start new section if current one is not empty
            if !current_section[:content].empty? && current_section[:size] >= @min_size
              sections << current_section
              current_section = { headers: header_stack.dup, content: [], size: 0 }
            end

            # Add new header to stack
            header_stack << { level: level, title: title }
            current_section[:headers] = header_stack.dup
          end

          current_section[:content] << line
          current_section[:size] += line.length + 1 # +1 for newline

          # Start new section if max size reached (unless in code block)
          if !in_code_block && current_section[:size] >= @max_size && !line.match?(CODE_BLOCK_PATTERN)
            sections << current_section
            current_section = { headers: header_stack.dup, content: [], size: 0 }
          end
        end

        # Add last section if not empty
        sections << current_section if current_section[:content].any?
        sections
      end

      def combine_sections(sections)
        chunks = []
        current_chunk = []
        current_size = 0

        sections.each do |section|
          section_content = format_section(section)
          section_size = section_content.length

          # If adding this section would exceed max_size and we already have content,
          # finalize the current chunk and start a new one
          if current_size + section_size > @max_size && !current_chunk.empty?
            chunks << current_chunk.join("\n\n")
            current_chunk = []
            current_size = 0
          end

          # If a single section is larger than max_size, we need to force-split it
          if section_size > @max_size && !section_content.include?('```')
            # For large sections, we need to split them forcefully
            # First add any existing content as its own chunk
            chunks << current_chunk.join("\n\n") if current_chunk.any?
            current_chunk = []
            current_size = 0

            # Get the context part from the section content
            context_part = section_content.match(/^(_Context:.+?_\n\n)/m)&.captures&.first || ''

            # Split the content part, but keep the context with each chunk
            content_without_context = section_content.sub(/^_Context:.+?_\n\n/m, '')
            content_without_context.scan(/(.{1,#{@max_size - context_part.length}})(?: |$)/m).map(&:first).each do |chunk_part|
              chunks << "#{context_part}#{chunk_part}"
            end
          else
            # Add to the current chunk
            current_chunk << section_content
            current_size += section_size + 2 # +2 for "\n\n" separator
          end
        end

        chunks << current_chunk.join("\n\n") if current_chunk.any?
        chunks
      end

      def format_section(section)
        lines = []

        # Add header breadcrumbs
        unless section[:headers].empty?
          breadcrumb = section[:headers].map { |h| h[:title] }.join(' > ')
          lines << "_Context: #{breadcrumb}_"
          lines << ''
        end

        # Add content
        lines.concat(section[:content])

        lines.join("\n")
      end
    end
  end
end
