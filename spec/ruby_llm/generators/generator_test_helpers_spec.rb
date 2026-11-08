# frozen_string_literal: true

require 'spec_helper'
require_relative '../../support/generator_test_helpers'

RSpec.describe GeneratorTestHelpers do
  let(:base) { File.join(described_class.base_directory, "helpers-spec-#{SecureRandom.hex(4)}") }

  after { FileUtils.rm_rf(base) }

  it 'keeps generator apps out of Dir.tmpdir by default' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with(described_class::ROOT_ENV).and_yield

    expect(described_class.base_directory).to eq(File.expand_path('../../../tmp/generator_apps', __dir__))
  end

  it 'honours RUBYLLM_GENERATOR_TMP' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with(described_class::ROOT_ENV).and_return(base)

    expect(described_class.base_directory).to eq(base)
  end

  it 'gives every root a folder of its own' do
    first = described_class.create_root(base)
    second = described_class.create_root(base)

    expect(first).not_to eq(second)
    expect([first, second]).to all(satisfy { |path| File.directory?(path) && File.dirname(path) == base })
  end

  it 'removes only its own root' do
    first = described_class.create_root(base)
    second = described_class.create_root(base)
    FileUtils.mkdir_p(File.join(second, 'test_app'))

    described_class.remove_root(first)

    expect(File.exist?(first)).to be(false)
    expect(File.directory?(File.join(second, 'test_app'))).to be(true)
  end

  it 'reuses one root per process and puts apps in it' do
    root = described_class.root

    expect(described_class.root).to eq(root)
    expect(described_class.app_path('test_app')).to eq(File.join(root, 'test_app'))
  end

  it 'gives a forked worker a root of its own and leaves the parent root alone' do
    skip 'fork is unavailable' unless Process.respond_to?(:fork)

    parent = described_class.root
    reader, writer = IO.pipe
    pid = fork do
      reader.close
      child = described_class.root
      writer.puts(child)
      described_class.remove_own_root
      writer.puts(File.exist?(child))
      exit!(0)
    end
    writer.close
    child, child_left = reader.read.lines.map(&:chomp)
    Process.wait(pid)

    expect(child).not_to eq(parent)
    expect(child_left).to eq('false')
    expect(File.directory?(parent)).to be(true)
  end
end
