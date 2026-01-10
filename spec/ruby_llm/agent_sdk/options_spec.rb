# frozen_string_literal: true

require 'spec_helper'
require 'ruby_llm/agent_sdk'

RSpec.describe RubyLLM::AgentSDK::Options do
  describe '#initialize' do
    it 'sets default values' do
      opts = described_class.new
      expect(opts.allowed_tools).to eq([])
      expect(opts.disallowed_tools).to eq([])
      expect(opts.permission_mode).to eq(:default)
      expect(opts.env).to eq({})
    end

    it 'accepts keyword arguments' do
      opts = described_class.new(
        allowed_tools: %w[Read Edit],
        permission_mode: :accept_edits,
        max_turns: 10
      )
      expect(opts.allowed_tools).to eq(%w[Read Edit])
      expect(opts.permission_mode).to eq(:accept_edits)
      expect(opts.max_turns).to eq(10)
    end
  end

  describe '.build' do
    it 'returns a new instance' do
      opts = described_class.build
      expect(opts).to be_a(described_class)
    end
  end

  describe 'fluent interface' do
    describe '#with_tools' do
      it 'sets allowed tools' do
        opts = described_class.build.with_tools(:Read, :Edit, :Bash)
        expect(opts.allowed_tools).to eq(%w[Read Edit Bash])
      end

      it 'accepts array' do
        opts = described_class.build.with_tools(%w[Read Edit])
        expect(opts.allowed_tools).to eq(%w[Read Edit])
      end

      it 'returns self for chaining' do
        opts = described_class.build
        expect(opts.with_tools(:Read)).to eq(opts)
      end
    end

    describe '#with_model' do
      it 'sets model as symbol' do
        opts = described_class.build.with_model(:opus)
        expect(opts.model).to eq(:opus)
      end

      it 'converts string to symbol' do
        opts = described_class.build.with_model('sonnet')
        expect(opts.model).to eq(:sonnet)
      end
    end

    describe '#with_permission_mode' do
      it 'sets permission mode' do
        opts = described_class.build.with_permission_mode(:accept_edits)
        expect(opts.permission_mode).to eq(:accept_edits)
      end
    end

    describe '#with_cwd' do
      it 'expands path' do
        opts = described_class.build.with_cwd('~')
        expect(opts.cwd).to eq(File.expand_path('~'))
      end
    end

    describe '#with_max_turns' do
      it 'sets max turns' do
        opts = described_class.build.with_max_turns(5)
        expect(opts.max_turns).to eq(5)
      end
    end

    describe '#with_timeout' do
      it 'sets timeout' do
        opts = described_class.build.with_timeout(60)
        expect(opts.timeout).to eq(60)
      end
    end

    describe '#with_system_prompt' do
      it 'sets system prompt' do
        opts = described_class.build.with_system_prompt('You are helpful')
        expect(opts.system_prompt).to eq('You are helpful')
      end
    end

    it 'supports method chaining' do
      opts = described_class.build
        .with_tools(:Read, :Edit)
        .with_model(:sonnet)
        .with_permission_mode(:accept_edits)
        .with_max_turns(10)

      expect(opts.allowed_tools).to eq(%w[Read Edit])
      expect(opts.model).to eq(:sonnet)
      expect(opts.permission_mode).to eq(:accept_edits)
      expect(opts.max_turns).to eq(10)
    end
  end

  describe '#tool_allowed?' do
    it 'returns true when allowed_tools is empty' do
      opts = described_class.new
      expect(opts.tool_allowed?('Read')).to be true
    end

    it 'returns true for allowed tools' do
      opts = described_class.new(allowed_tools: %w[Read Edit])
      expect(opts.tool_allowed?('Read')).to be true
      expect(opts.tool_allowed?('Edit')).to be true
    end

    it 'returns false for non-allowed tools' do
      opts = described_class.new(allowed_tools: %w[Read Edit])
      expect(opts.tool_allowed?('Bash')).to be false
    end

    it 'returns false for disallowed tools' do
      opts = described_class.new(disallowed_tools: %w[Bash])
      expect(opts.tool_allowed?('Bash')).to be false
    end
  end

  describe '#to_h' do
    it 'excludes nil and empty values' do
      opts = described_class.new(max_turns: 5)
      hash = opts.to_h
      expect(hash).to include(max_turns: 5)
      expect(hash).not_to have_key(:model)
      expect(hash).not_to have_key(:allowed_tools)
    end
  end

  describe '.schema' do
    it 'returns the schema hash' do
      expect(described_class.schema).to be_a(Hash)
      expect(described_class.schema).to have_key(:prompt)
      expect(described_class.schema).to have_key(:permission_mode)
    end
  end

  describe '.attribute_names' do
    it 'returns all attribute names' do
      names = described_class.attribute_names
      expect(names).to include(:allowed_tools, :permission_mode, :model)
    end
  end
end
