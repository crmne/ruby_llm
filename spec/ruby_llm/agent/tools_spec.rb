# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent'
require 'tempfile'

RSpec.describe RubyLLM::Agent::Tools do
  describe RubyLLM::Agent::Tools::Read do
    let(:tool) { described_class.new }

    it 'has the correct name and description' do
      expect(tool.name).to eq('ruby_llm--agent--tools--read')
      expect(tool.description).to include('Read')
    end

    it 'reads file contents' do
      Tempfile.create(['test', '.txt']) do |f|
        f.write("line 1\nline 2\nline 3\n")
        f.flush

        result = tool.execute(path: f.path)
        expect(result).to include('line 1')
        expect(result).to include('line 2')
      end
    end

    it 'returns error for non-existent file' do
      result = tool.execute(path: '/nonexistent/file.txt')
      expect(result[:error]).to include('not found')
    end

    it 'supports offset and limit' do
      Tempfile.create(['test', '.txt']) do |f|
        f.write("line 1\nline 2\nline 3\nline 4\nline 5\n")
        f.flush

        result = tool.execute(path: f.path, offset: 2, limit: 2)
        expect(result).to include('line 2')
        expect(result).to include('line 3')
        expect(result).not_to include('line 1')
        expect(result).not_to include('line 4')
      end
    end
  end

  describe RubyLLM::Agent::Tools::Write do
    let(:tool) { described_class.new }

    it 'writes content to a file' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'test.txt')
        result = tool.execute(path: path, content: 'hello world')

        expect(result).to include('Successfully wrote')
        expect(File.read(path)).to eq('hello world')
      end
    end

    it 'creates parent directories' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'nested', 'deep', 'test.txt')
        tool.execute(path: path, content: 'nested content')

        expect(File.exist?(path)).to be true
      end
    end
  end

  describe RubyLLM::Agent::Tools::Edit do
    let(:tool) { described_class.new }

    it 'replaces text in a file' do
      Tempfile.create(['test', '.rb']) do |f|
        f.write("def foo\n  puts 'hello'\nend\n")
        f.flush

        result = tool.execute(
          path: f.path,
          old_string: 'def foo',
          new_string: 'def bar'
        )

        expect(result).to include('Successfully edited')
        expect(File.read(f.path)).to include('def bar')
        expect(File.read(f.path)).not_to include('def foo')
      end
    end

    it 'returns error when string not found' do
      Tempfile.create(['test', '.rb']) do |f|
        f.write("def foo\nend\n")
        f.flush

        result = tool.execute(
          path: f.path,
          old_string: 'not found',
          new_string: 'replacement'
        )

        expect(result[:error]).to include('not found')
      end
    end

    it 'returns error for ambiguous matches' do
      Tempfile.create(['test', '.rb']) do |f|
        f.write("foo\nfoo\nfoo\n")
        f.flush

        result = tool.execute(
          path: f.path,
          old_string: 'foo',
          new_string: 'bar'
        )

        expect(result[:error]).to include('Multiple matches')
      end
    end

    it 'replaces all with replace_all flag' do
      Tempfile.create(['test', '.rb']) do |f|
        f.write("foo\nfoo\nfoo\n")
        f.flush

        tool.execute(
          path: f.path,
          old_string: 'foo',
          new_string: 'bar',
          replace_all: true
        )

        expect(File.read(f.path)).to eq("bar\nbar\nbar\n")
      end
    end
  end

  describe RubyLLM::Agent::Tools::Bash do
    let(:tool) { described_class.new }

    it 'executes simple commands' do
      result = tool.execute(command: 'echo hello')
      expect(result).to include('hello')
    end

    it 'blocks dangerous commands' do
      result = tool.execute(command: 'rm -rf /')
      expect(result[:error]).to include('blocked')
    end

    it 'handles command timeout' do
      result = tool.execute(command: 'sleep 10', timeout: 1)
      expect(result[:error]).to include('timed out')
    end
  end

  describe RubyLLM::Agent::Tools::Glob do
    let(:tool) { described_class.new }

    it 'finds files matching pattern' do
      Dir.mktmpdir do |dir|
        FileUtils.touch(File.join(dir, 'test.rb'))
        FileUtils.touch(File.join(dir, 'test.txt'))
        FileUtils.mkdir_p(File.join(dir, 'sub'))
        FileUtils.touch(File.join(dir, 'sub', 'nested.rb'))

        result = tool.execute(pattern: '**/*.rb', path: dir)
        expect(result).to include('test.rb')
        expect(result).to include('nested.rb')
        expect(result).not_to include('test.txt')
      end
    end

    it 'returns message when no matches' do
      Dir.mktmpdir do |dir|
        result = tool.execute(pattern: '*.xyz', path: dir)
        expect(result).to include('No files found')
      end
    end
  end

  describe RubyLLM::Agent::Tools::Grep do
    let(:tool) { described_class.new }

    it 'searches file contents' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'test.rb'), "# TODO: fix this\ndef foo\nend\n")
        File.write(File.join(dir, 'other.rb'), "def bar\nend\n")

        result = tool.execute(pattern: 'TODO', path: dir, glob: '*.rb')
        expect(result).to include('test.rb')
        expect(result).to include('TODO')
        expect(result).not_to include('other.rb')
      end
    end

    it 'returns message when no matches' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'test.rb'), "def foo\nend\n")

        result = tool.execute(pattern: 'NOTFOUND', path: dir)
        expect(result).to include('No matches')
      end
    end
  end

  describe 'Tools categories' do
    it 'provides all tools' do
      expect(described_class[:all]).to include(
        RubyLLM::Agent::Tools::Read,
        RubyLLM::Agent::Tools::Write,
        RubyLLM::Agent::Tools::Bash
      )
    end

    it 'provides safe tools' do
      expect(described_class[:safe]).to include(RubyLLM::Agent::Tools::Read)
      expect(described_class[:safe]).not_to include(RubyLLM::Agent::Tools::Write)
    end
  end
end
