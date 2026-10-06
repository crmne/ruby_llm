# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Tool do
  describe '.defer' do
    it 'is off by default' do
      expect(Class.new(described_class).deferred?).to be(false)
    end

    it 'defers the class and its subclasses only' do
      parent = Class.new(described_class) { defer }

      expect(parent.deferred?).to be(true)
      expect(Class.new(parent).deferred?).to be(true)
      expect(Class.new(described_class).deferred?).to be(false)
    end
  end
end
