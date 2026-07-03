# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Content do
  let(:text_path) { File.expand_path('../fixtures/ruby.txt', __dir__) }

  describe '#empty?' do
    it 'returns true when text is empty and there are no attachments' do
      expect(described_class.new('')).to be_empty
    end

    it 'returns false when text is present' do
      expect(described_class.new('hello')).not_to be_empty
    end

    it 'returns false when attachments are present without text' do
      expect(described_class.new(nil, text_path)).not_to be_empty
    end

    it 'returns false when empty text has attachments' do
      expect(described_class.new('', text_path)).not_to be_empty
    end
  end
end
