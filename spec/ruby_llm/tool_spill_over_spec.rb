# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Tool do
  it 'declares how long its results may be before a chat saves them as files' do
    tool = Class.new(described_class) { spill_over 50_000 }
    subclass = Class.new(tool)

    expect(tool.new.spill_over).to eq(50_000)
    expect(subclass.spill_over).to eq(50_000)
    expect(Class.new(described_class) { spill_over false }.spill_over).to be(false)
    expect(Class.new(described_class).new.spill_over).to be_nil
  end

  it 'takes only a positive whole number of characters or false' do
    [0, -5, 1.5, nil, true, '100'].each do |value|
      expect { Class.new(described_class) { spill_over value } }
        .to raise_error(ArgumentError, 'spill_over takes a positive number of characters or false')
    end
  end
end
