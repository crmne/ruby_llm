# frozen_string_literal: true

require 'spec_helper'
require 'open3'

# rubocop:disable-next RSpec/DescribeClass
RSpec.describe 'requiring ruby_llm' do
  def constant_defined?(constant, after: nil)
    script = ["require 'ruby_llm'", after, "print defined?(#{constant}) ? 'yes' : 'no'"].compact.join('; ')
    output, = Open3.capture2(RbConfig.ruby, '-I', File.expand_path('../lib', __dir__), '-e', script)
    output
  end

  it 'leaves the MIME table unloaded' do
    expect(constant_defined?('Marcel')).to eq('no')
  end

  it 'loads the MIME table with the helper that reads it' do
    expect(constant_defined?('Marcel', after: 'RubyLLM::Files::MimeType')).to eq('yes')
  end

  it 'loads the MIME table with the MCP content reader' do
    expect(constant_defined?('Marcel', after: 'RubyLLM::MCP::Content')).to eq('yes')
  end
end
