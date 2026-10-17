# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Sandbox::Landlock do
  before do
    skip 'mxc runs on MRI' unless RUBY_ENGINE == 'ruby'
    require 'mxc'
  end

  let(:root) { File.realpath(Dir.mktmpdir('ruby_llm-landlock-spec')) }

  after { FileUtils.rm_rf(root) }

  def path(*parts) = File.join(root, *parts)

  def tree(*directories)
    directories.each { |directory| FileUtils.mkdir_p(path(directory)) }
  end

  it 'grants the entries around a denied path instead of the folder holding it' do
    tree('ruby/gems/rspec', 'ruby/gems/csv', 'ruby/lib', 'work')
    sandbox = MXC::Sandbox.new(readable: [path('ruby')], writable: [path('work')], denied: [path('ruby/gems/rspec')])

    policy = described_class.policy(sandbox)

    expect(policy.readable).to eq([path('ruby/gems/csv'), path('ruby/lib')])
    expect(policy.writable).to eq([path('work')])
    expect(policy.denied).to be_empty
    expect(policy.backend).to eq(:landlock)
  end

  it 'keeps denied paths outside every grant, and drops grants inside denied ones' do
    tree('ruby/lib', 'gems/app')
    sandbox = MXC::Sandbox.new(readable: [path('ruby'), path('gems/app')], denied: [path('gems')])

    policy = described_class.policy(sandbox)

    expect(policy.readable).to eq([path('ruby')])
    expect(policy.denied).to eq([path('gems')])
  end

  it 'leaves out links that lead to a denied path' do
    tree('ruby/gems/rspec', 'ruby/lib')
    File.symlink(path('ruby/gems/rspec'), path('ruby/rspec'))
    sandbox = MXC::Sandbox.new(readable: [path('ruby')], denied: [path('ruby/gems/rspec')])

    expect(described_class.policy(sandbox).readable).to eq([path('ruby/lib')])
  end

  it 'refuses a denied path inside a writable one, which Landlock cannot split' do
    tree('work/secret')
    sandbox = MXC::Sandbox.new(writable: [path('work')], denied: [path('work/secret')])

    expect { described_class.policy(sandbox) }
      .to raise_error(RubyLLM::ConfigurationError, /Landlock cannot hide .*secret inside the writable .*work/)
  end

  it 'keeps the rest of the policy' do
    sandbox = MXC::Sandbox.new(readable: [path], env: { 'LANG' => 'C.UTF-8' }, directory: path, timeout: 30,
                               limits: { cpu_time: 60 }, priority: :low)

    policy = described_class.policy(sandbox)

    expect([policy.env, policy.directory, policy.timeout, policy.limits, policy.priority, policy.network])
      .to eq([{ 'LANG' => 'C.UTF-8' }, path, 30, { cpu_time: 60 }, :low, false])
  end
end
