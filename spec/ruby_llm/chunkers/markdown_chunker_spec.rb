# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Chunkers::MarkdownChunker do
  let(:chunker) { described_class.new(min_size: 20, max_size: 100) }

  describe '#chunk' do
    it 'returns empty array for nil content' do
      expect(chunker.chunk(nil)).to eq([])
    end

    it 'returns empty array for empty content' do
      expect(chunker.chunk('')).to eq([])
    end

    it 'preserves header hierarchy in chunks' do
      content = <<~MARKDOWN
        # Main Title
        Some intro text.

        ## Section 1
        Content for section 1.

        ### Subsection 1.1
        Detailed content here.

        ## Section 2
        More content.
      MARKDOWN

      chunks = chunker.chunk(content)

      expect(chunks[0]).to include('_Context: Main Title_')
      expect(chunks[1]).to include('_Context: Main Title > Section 1_')
      expect(chunks[2]).to include('_Context: Main Title > Section 1 > Subsection 1.1_')
      expect(chunks[3]).to include('_Context: Main Title > Section 2_')
    end

    it 'keeps code blocks intact' do
      content = <<~MARKDOWN
        # Code Example

        Here's a code block:

        ```ruby
        def hello_world
          puts "Hello, World!"
        end
        ```

        And some more text.
      MARKDOWN

      chunks = chunker.chunk(content)
      code_chunk = chunks.find { |c| c.include?('```ruby') }

      expect(code_chunk).to include("```ruby\ndef hello_world")
      expect(code_chunk).to include('end')
      expect(code_chunk).to include('```')
    end

    it 'respects max_size while keeping sections together' do
      chunker = described_class.new(max_size: 50)
      content = <<~MARKDOWN
        # Title
        Short intro.

        ## Section 1
        This is a longer section that should be in its own chunk
        because it exceeds the maximum size limit.

        ## Section 2
        Another section.
      MARKDOWN

      chunks = chunker.chunk(content)
      chunks.each do |chunk|
        expect(chunk.length).to be <= 50
      end
    end

    it 'combines small sections' do
      content = <<~MARKDOWN
        # Title
        Intro.

        ## Small Section 1
        Brief content.

        ## Small Section 2
        More brief content.
      MARKDOWN

      chunks = chunker.chunk(content)
      expect(chunks.length).to be < content.split('##').length
    end

    it 'handles nested lists and complex markdown' do
      content = <<~MARKDOWN
        # Shopping List

        ## Groceries
        - Fruits
          - Apples
          - Bananas
        - Vegetables
          1. Carrots
          2. Broccoli

        ## Household
        * Cleaning supplies
          * Soap
          * Detergent
        * Paper goods
      MARKDOWN

      chunks = chunker.chunk(content)
      # The chunks should all include context information
      expect(chunks).to all(include('_Context:'))
      expect(chunks.join).to include('Fruits')
      expect(chunks.join).to include('Cleaning supplies')
    end
  end
end
