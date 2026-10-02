# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::MCP::InputRequest do
  def form(properties)
    described_class.new('profile', { 'message' => 'Your profile', 'requestedSchema' => { 'properties' => properties } })
  end

  it 'fills in the defaults of the fields an answer leaves out' do
    request = form('name' => { 'type' => 'string', 'default' => 'John Doe' },
                   'age' => { 'type' => 'integer', 'default' => 30 },
                   'verified' => { 'type' => 'boolean', 'default' => false },
                   'email' => { 'type' => 'string' })

    request.answer(age: 31)

    expect(request.response)
      .to eq(action: 'accept', content: { 'name' => 'John Doe', 'age' => 31, 'verified' => false })
  end

  it 'keeps the values an answer gives' do
    request = form('status' => { 'type' => 'string', 'enum' => %w[active inactive], 'default' => 'active' })

    request.answer(status: 'inactive')

    expect(request.response[:content]).to eq('status' => 'inactive')
  end

  it 'accepts a URL request without content' do
    request = described_class.new('connect', { 'mode' => 'url', 'url' => 'https://example.com/connect' })

    request.answer

    expect(request.response).to eq(action: 'accept')
  end
end
