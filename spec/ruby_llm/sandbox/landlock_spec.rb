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

  it 'leaves out a link to a folder that holds a denied path outside every grant' do
    tree('app/public', 'other/secret')
    File.symlink(path('other'), path('app/link'))
    File.write(path('app/key'), 'x')
    sandbox = MXC::Sandbox.new(readable: [path('app')], denied: [path('app/key'), path('other/secret')])

    policy = described_class.policy(sandbox)

    expect(policy.readable).to eq([path('app/public')])
    expect(policy.denied).to eq([path('other/secret')])
  end

  it 'finds a denied path named through a link inside the grant it leads to' do
    tree('real/keep', 'real/secret')
    File.symlink(path('real'), path('alias'))
    sandbox = MXC::Sandbox.new(readable: [path('real')], denied: [path('alias/secret')])

    policy = described_class.policy(sandbox)

    expect(policy.readable).to eq([path('real/keep')])
    expect(policy.denied).to be_empty
  end

  it 'splits a grant named through a link' do
    tree('real/keep', 'real/secret')
    File.symlink(path('real'), path('alias'))
    sandbox = MXC::Sandbox.new(readable: [path('alias')], denied: [path('real/secret')])

    expect(described_class.policy(sandbox).readable).to eq([path('real/keep')])
  end

  it 'refuses a denied path named through a link into a writable one' do
    tree('work')
    File.symlink(path('work'), path('alias'))
    sandbox = MXC::Sandbox.new(writable: [path('work')], denied: [path('alias/secret')])

    expect { described_class.policy(sandbox) }.to raise_error(RubyLLM::ConfigurationError, /Landlock cannot hide/)
  end

  it 'keeps a denied path that does not exist yet, under the folder it leads to' do
    tree('real')
    File.symlink(path('real'), path('alias'))
    sandbox = MXC::Sandbox.new(denied: [path('alias/later/secret')])

    expect(described_class.policy(sandbox).denied).to eq([path('real/later/secret')])
  end

  it 'drops a writable path that is itself denied' do
    tree('work')
    sandbox = MXC::Sandbox.new(writable: [path('work')], denied: [path('work')])

    policy = described_class.policy(sandbox)

    expect(policy.writable).to be_empty
    expect(policy.denied).to be_empty
  end

  it 'drops a file a denied path sits under' do
    File.write(path('notes'), 'x')
    sandbox = MXC::Sandbox.new(readable: [path('notes')], denied: [path('notes/secret')])

    expect(described_class.policy(sandbox).readable).to be_empty
  end

  it 'expands a home-relative path' do
    tree('home')
    home = Dir.home
    ENV['HOME'] = path('home')
    sandbox = MXC::Sandbox.new(denied: ['~/secret'])

    expect(described_class.policy(sandbox).denied).to eq([path('home/secret')])
  ensure
    ENV['HOME'] = home
  end

  it 'leaves out a broken link beside a denied path' do
    tree('ruby/gems', 'ruby/lib')
    File.symlink(path('ruby/gems'), path('ruby/loop'))
    File.symlink(path('ruby/one'), path('ruby/two'))
    File.symlink(path('ruby/two'), path('ruby/one'))
    sandbox = MXC::Sandbox.new(readable: [path('ruby')], denied: [path('ruby/gems')])

    expect(described_class.policy(sandbox).readable).to eq([path('ruby/lib')])
  end

  it 'refuses a denied path inside a writable one, which Landlock cannot split' do
    tree('work/secret')
    sandbox = MXC::Sandbox.new(writable: [path('work')], denied: [path('work/secret')])

    expect { described_class.policy(sandbox) }
      .to raise_error(RubyLLM::ConfigurationError, /Landlock cannot hide .*secret inside the writable .*work/)
  end

  it 'keeps the sandbox, changing only a copy' do
    sandbox_class = Class.new(MXC::Sandbox) { readable '/srv' }
    sandbox = sandbox_class.new.with_denied(path('ruby/gems/rspec'))

    policy = described_class.policy(sandbox)

    expect(policy).to be_an_instance_of(sandbox_class)
    expect(policy).not_to be(sandbox)
    expect([sandbox.backend, sandbox.denied]).to eq([MXC.config.backend, [path('ruby/gems/rspec')]])
  end

  it 'keeps the rest of the policy' do
    sandbox = MXC::Sandbox.new(readable: [path], env: { 'LANG' => 'C.UTF-8' }, directory: path, timeout: 30,
                               limits: { cpu_time: 60 }, priority: :low)

    policy = described_class.policy(sandbox)

    expect([policy.env, policy.directory, policy.timeout, policy.limits, policy.priority, policy.network])
      .to eq([{ 'LANG' => 'C.UTF-8' }, path, 30, { cpu_time: 60 }, :low, false])
  end
end
