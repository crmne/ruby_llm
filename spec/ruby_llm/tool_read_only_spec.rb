# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Tool do
  describe '.read_only' do
    it 'is off by default' do
      expect(Class.new(described_class).new).not_to be_read_only
    end

    it 'marks the class and its subclasses only' do
      parent = Class.new(described_class) { read_only }

      expect(parent.new).to be_read_only
      expect(Class.new(parent).new).to be_read_only
      expect(Class.new(described_class).read_only?).to be(false)
    end
  end
end
