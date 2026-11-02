# frozen_string_literal: true

require 'spec_helper'
require 'active_support/core_ext/numeric/time'

RSpec.describe RubyLLM::Protocol::CacheLifetime do
  it 'renders seconds in the largest unit that divides them' do
    expect(described_class.render(3600)).to eq('1h')
    expect(described_class.render(86_400)).to eq('24h')
    expect(described_class.render(300)).to eq('5m')
    expect(described_class.render(90)).to eq('90s')
  end

  it 'renders a Duration' do
    expect(described_class.render(1.hour)).to eq('1h')
    expect(described_class.render(5.minutes)).to eq('5m')
  end

  it 'renders the digits a string column keeps for an Integer or Duration' do
    expect(described_class.render('3600')).to eq('1h')
    expect(described_class.render('5400.0')).to eq('90m')
  end

  it 'leaves a provider spelling alone' do
    expect(described_class.render('1h')).to eq('1h')
    expect(described_class.render('in_memory')).to eq('in_memory')
  end
end
