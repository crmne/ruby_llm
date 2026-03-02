# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Tool do
  describe '#name' do
    it 'converts class name to snake_case and removes _tool suffix' do
      stub_const('SampleTool', Class.new(described_class))
      expect(SampleTool.new.name).to eq('sample')
    end

    # rubocop:disable Naming/AsciiIdentifiers

    it 'normalizes class name Unicode characters to ASCII' do
      stub_const('SàmpleTòol', Class.new(described_class))
      expect(SàmpleTòol.new.name).to eq('sample')
    end

    it 'handles class names with unsupported characters' do
      stub_const('SampleΨTool', Class.new(described_class))
      expect(SampleΨTool.new.name).to eq('sample')
    end

    # rubocop:enable Naming/AsciiIdentifiers

    it 'handles class names without Tool suffix' do
      stub_const('AnotherSample', Class.new(described_class))
      expect(AnotherSample.new.name).to eq('another_sample')
    end

    it 'strips :: for class in module namespace' do
      stub_const('TestModule::SampleTool', Class.new(described_class))
      expect(TestModule::SampleTool.new.name).to eq('test_module--sample')
    end

    it 'handles ASCII-8BIT encoded class names without raising Encoding::CompatibilityError' do
      # This simulates a class name that is ASCII-8BIT encoded
      tool_class = Class.new(described_class)
      ascii_8bit_name = 'SampleTool'.dup.force_encoding('ASCII-8BIT')
      allow(tool_class).to receive(:name).and_return(ascii_8bit_name)
      expect(tool_class.new.name).to eq('sample')
    end
  end

  describe '#call' do
    it 'returns an error hash for unknown keyword arguments' do
      stub_const('SignatureTool', Class.new(described_class) do
        def execute(questions:)
          questions
        end
      end)

      result = SignatureTool.new.call({ 'questions' => [], 'isOther' => true })

      expect(result).to eq({ error: 'Invalid tool arguments: unknown keyword: :isOther' })
    end

    it 'returns an error hash for missing required keyword arguments' do
      stub_const('RequiredTool', Class.new(described_class) do
        def execute(questions:)
          questions
        end
      end)

      result = RequiredTool.new.call({})

      expected_error = if RUBY_ENGINE == 'jruby'
        'Invalid tool arguments: missing keyword: questions'
      else
        'Invalid tool arguments: missing keyword: :questions'
      end
      expect(result).to eq({ error: expected_error })
    end

    it 'allows extra keyword arguments when execute accepts keyrest' do
      stub_const('FlexibleTool', Class.new(described_class) do
        def execute(questions:, **extra)
          { questions:, extra: }
        end
      end)

      result = FlexibleTool.new.call({ 'questions' => [1], 'isOther' => true })

      expect(result).to eq({ questions: [1], extra: { isOther: true } })
    end

    it 're-raises unrelated ArgumentError from inside execute' do
      stub_const('ManualArgumentErrorTool', Class.new(described_class) do
        def execute(questions:)
          _ = questions
          raise ArgumentError, 'bad value provided'
        end
      end)

      expect { ManualArgumentErrorTool.new.call({ 'questions' => [] }) }
        .to raise_error(ArgumentError, 'bad value provided')
    end
  end
end
