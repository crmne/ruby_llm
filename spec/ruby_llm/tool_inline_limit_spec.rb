# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Tool do
  it 'declares how long its results may be before a chat saves them as files' do
    tool = Class.new(described_class) { inline_limit 50_000 }
    subclass = Class.new(tool)

    expect(tool.new.inline_limit).to eq(50_000)
    expect(subclass.inline_limit).to eq(50_000)
    expect(Class.new(described_class) { inline_limit false }.inline_limit).to be(false)
    expect(Class.new(described_class).new.inline_limit).to be_nil
  end

  it 'takes only a positive whole number of characters or false' do
    [0, -5, 1.5, nil, true, '100'].each do |value|
      expect { Class.new(described_class) { inline_limit value } }
        .to raise_error(ArgumentError, 'inline_limit takes a positive number of characters or false')
    end
  end
end
