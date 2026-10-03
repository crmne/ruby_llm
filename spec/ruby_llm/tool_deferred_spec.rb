# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Tool do
  describe '.deferred' do
    it 'defaults to false' do
      stub_const('UndeclaredTool', Class.new(described_class))
      expect(UndeclaredTool.deferred?).to be(false)
      expect(UndeclaredTool.new.deferred?).to be(false)
    end

    it 'marks the class as deferred when called without arguments and returns self' do
      klass = Class.new(described_class)
      expect(klass.deferred).to be(klass)
      stub_const('HeavyTool', klass)
      expect(HeavyTool.deferred?).to be(true)
      expect(HeavyTool.new.deferred?).to be(true)
    end

    it 'accepts explicit true/false' do
      stub_const('TrueTool', Class.new(described_class) { deferred(true) })
      stub_const('FalseTool', Class.new(described_class) { deferred(false) })
      expect(TrueTool.deferred?).to be(true)
      expect(FalseTool.deferred?).to be(false)
    end

    it 'is inherited by subclasses, which may opt back out' do
      stub_const('ParentTool', Class.new(described_class) { deferred })
      stub_const('ChildTool', Class.new(ParentTool))
      stub_const('EagerChildTool', Class.new(ParentTool) { deferred(false) })
      expect(ChildTool.deferred?).to be(true)
      expect(ChildTool.new.deferred?).to be(true)
      expect(EagerChildTool.deferred?).to be(false)
      expect(ParentTool.deferred?).to be(true)
    end

    it 'does not propagate to unrelated classes' do
      stub_const('ParentTool', Class.new(described_class) { deferred })
      stub_const('SiblingTool', Class.new(described_class))
      expect(ParentTool.deferred?).to be(true)
      expect(SiblingTool.deferred?).to be(false)
    end
  end

  describe RubyLLM::Tool::Registration do
    let(:tool) do
      stub_const('WeatherTool', Class.new(RubyLLM::Tool) do
        description 'Looks up weather'
        parameter :city, description: 'City name'
        def execute(city:) = "weather in #{city}"
      end)
      WeatherTool.new
    end

    it 'pins a deferred flag without mutating the tool' do
      registration = described_class.new(tool, deferred: true)
      expect(registration.deferred?).to be(true)
      expect(tool.deferred?).to be(false)
    end

    it 'exposes the wrapped tool via #tool' do
      registration = described_class.new(tool, deferred: true)
      expect(registration.tool).to be(tool)
    end

    it 'delegates every other method to the wrapped tool' do
      registration = described_class.new(tool, deferred: false)
      expect(registration.name).to eq('weather')
      expect(registration.description).to eq('Looks up weather')
      expect(registration.parameters_schema).to eq(tool.parameters_schema)
      expect(registration.provider_options).to eq({})
    end

    it 'is recognizable as a Registration through the delegator' do
      registration = described_class.new(tool, deferred: true)
      expect(registration).to be_a(described_class)
    end
  end
end
