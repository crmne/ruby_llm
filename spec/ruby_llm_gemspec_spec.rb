# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable-next RSpec/DescribeClass
RSpec.describe 'ruby_llm.gemspec' do
  subject(:gemspec) { Gem::Specification.load(File.expand_path('../ruby_llm.gemspec', __dir__)) }

  def runtime_dependency(name)
    gemspec.dependencies.find { |dependency| dependency.type == :runtime && dependency.name == name }
  end

  it 'keeps faraday compatible with Ruby < 4.0' do
    expect(runtime_dependency('faraday').requirement).to be_satisfied_by(Gem::Version.new('1.10.3'))
  end

  it 'keeps faraday-retry compatible with Faraday v1 and v2' do
    expect(runtime_dependency('faraday-retry').requirement.to_s).to eq('>= 1')
  end

  it 'supports Marcel v1 and v2' do
    expect(runtime_dependency('marcel').requirement.to_s).to eq('>= 1.0, < 3')
  end

  it 'allows applications to resolve either JSON 2 or JSON 3' do
    requirement = runtime_dependency('json').requirement

    expect(requirement).to be_satisfied_by(Gem::Version.new('2.21.2'))
    expect(requirement).to be_satisfied_by(Gem::Version.new('3.0.2'))
  end
end
