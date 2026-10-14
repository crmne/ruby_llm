# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::CodeExecution::RubyInstallation do
  let(:root) { Dir.mktmpdir('ruby_llm-ruby-spec') }
  let(:prefix) { File.join(root, 'ruby') }
  let(:gem_dir) { File.join(prefix, 'lib', 'ruby', 'gems', '4.0.0') }
  let(:bundle) { File.join(root, 'bundle') }
  let(:installation) { described_class.new(prefix:, gem_dir:, gem_path: [bundle, gem_dir]) }

  after { FileUtils.rm_rf(root) }

  def bundled_gems_constant?
    require 'bundled_gems'
    defined?(Gem::BUNDLED_GEMS::SINCE)
  rescue LoadError
    false
  end

  def extensions
    File.join(gem_dir, 'extensions', Gem::Platform.local.to_s, Gem.extension_api_version)
  end

  def install(name, version, default: false)
    specifications = File.join(gem_dir, 'specifications', *('default' if default))
    FileUtils.mkdir_p(specifications)
    File.write(File.join(specifications, "#{name}-#{version}.gemspec"), <<~RUBY)
      # stub: #{name} #{version} ruby lib
      Gem::Specification.new do |s|
        s.name = "#{name}"
        s.version = "#{version}"
      end
    RUBY
    FileUtils.mkdir_p(File.join(gem_dir, 'gems', "#{name}-#{version}"))
  end

  before do
    FileUtils.mkdir_p([bundle, File.join(gem_dir, 'cache'), File.join(gem_dir, 'plugins')])
    install('json', '2.10.0', default: true)
    install('json', '2.15.0')
    install('csv', '3.3.5')
    install('rspec-core', '3.13.0')
    FileUtils.mkdir_p(File.join(extensions, 'rspec-core-3.13.0'))
    File.write(File.join(extensions, 'rspec-core-3.13.0', 'gem.build_complete'), '')
    File.write(File.join(extensions, 'rspec-core-3.13.0', 'native.so'), '')
    allow(installation).to receive(:bundled_gems).and_return(%w[csv])
  end

  it 'mounts the Ruby installation' do
    expect(installation.readable).to eq([prefix])
  end

  it "hides the application's gems, keeping Ruby's default and bundled gems" do
    expect(installation.denied).to contain_exactly(
      File.join(gem_dir, 'gems', 'rspec-core-3.13.0'),
      File.join(extensions, 'rspec-core-3.13.0', 'native.so'),
      File.join(gem_dir, 'cache'),
      File.join(gem_dir, 'plugins'),
      bundle
    )
  end

  it 'reads the bundled gems Ruby lists' do
    allow(installation).to receive(:bundled_gems).and_call_original
    allow(RbConfig::CONFIG).to receive(:[]).and_call_original
    allow(RbConfig::CONFIG).to receive(:[]).with('srcdir').and_return(root)
    FileUtils.mkdir_p(File.join(root, 'gems'))
    File.write(File.join(root, 'gems', 'bundled_gems'), "# comment\n\nminitest 5.25.0 https://example.com\ncsv 3.3.5\n")

    expect(installation.ruby_gem?('minitest')).to be(true)
    expect(installation.ruby_gem?('rspec-core')).to be(false)
  end

  it 'falls back to the gems Ruby moved from default to bundled' do
    allow(installation).to receive(:bundled_gems).and_call_original
    allow(RbConfig::CONFIG).to receive(:[]).and_call_original
    allow(RbConfig::CONFIG).to receive(:[]).with('srcdir').and_return(nil)
    skip 'this Ruby has no Gem::BUNDLED_GEMS' unless bundled_gems_constant?

    expect(installation.ruby_gem?(Gem::BUNDLED_GEMS::SINCE.keys.first)).to be(true)
  end
end
