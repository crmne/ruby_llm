# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Content do
  describe '#empty?' do
    it 'is true when text is empty and there are no attachments' do
      expect(described_class.new('')).to be_empty
    end

    it 'is true when text is whitespace-only and there are no attachments' do
      expect(described_class.new("   \n\t")).to be_empty
    end

    it 'is false when text has content' do
      expect(described_class.new('hello')).not_to be_empty
    end

    it 'is false when attachments are present without text' do
      content = described_class.new(nil, 'spec/fixtures/ruby.txt')
      expect(content).not_to be_empty
    end

    it 'is false when both text and attachments are present' do
      content = described_class.new('hello', 'spec/fixtures/ruby.txt')
      expect(content).not_to be_empty
    end
  end
end
