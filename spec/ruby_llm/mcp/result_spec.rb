# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::MCP::Result do
  let(:offline) { [{ 'type' => 'text', 'text' => 'The laptop is offline' }] }

  it 'takes the data without braces' do
    result = described_class.new('content' => offline, 'isError' => true)

    expect(result).to have_attributes(text: 'The laptop is offline', ui_uri: nil)
    expect(result).to be_error
  end

  it 'takes the data in braces' do
    result = described_class.new({ 'content' => offline, 'isError' => true })

    expect(result.text).to eq('The laptop is offline')
    expect(result).to be_error
  end

  it 'takes the URI of the UI that renders it' do
    result = described_class.new({ 'content' => offline }, 'ui://laptop/files')

    expect(result).to have_attributes(text: 'The laptop is offline', ui_uri: 'ui://laptop/files')
  end
end
