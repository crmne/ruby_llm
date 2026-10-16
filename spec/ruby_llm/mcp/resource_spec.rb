# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::MCP::Resource do
  def resource(uri, mime_type, text = '# Policies')
    described_class.new(nil, 'uri' => uri, 'mimeType' => mime_type, 'text' => text)
  end

  describe '#to_attachment' do
    it 'takes the type the server reports when the URI has no extension' do
      expect(resource('file:///project/README', 'text/plain').to_attachment)
        .to have_attributes(filename: 'README.txt', mime_type: 'text/plain', content: '# Policies')
      expect(resource('db://reports/42', 'text/csv', "a,b\n").to_attachment)
        .to have_attributes(filename: '42.csv', mime_type: 'text/csv')
    end

    it 'names a resource whose URI has no path' do
      expect(resource('handbook://policies', 'text/markdown').to_attachment)
        .to have_attributes(filename: 'resource.md', mime_type: 'text/markdown')
    end

    it 'keeps the name of a URI that has an extension' do
      expect(resource('file:///project/README.md', 'text/markdown').to_attachment)
        .to have_attributes(filename: 'README.md', mime_type: 'text/markdown')
    end
  end
end
