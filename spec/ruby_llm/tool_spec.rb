# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Tool do
  describe '.description' do
    it 'sets and returns the tool description' do
      stub_const('DescribedTool', Class.new(described_class) do
        description 'Does a thing'
      end)

      expect(DescribedTool.description).to eq('Does a thing')
      expect(DescribedTool.new.description).to eq('Does a thing')
    end
  end

  describe '.parameter' do
    it 'accepts a description for the parameter' do
      stub_const('ParamDescriptionTool', Class.new(described_class) do
        parameter :city, description: 'City name'

        def execute(city:)
          city
        end
      end)

      expect(ParamDescriptionTool.declared_parameters[:city].description).to eq('City name')
    end
  end

  describe '.parameters' do
    it 'requires a schema or a block' do
      expect { Class.new(described_class).parameters }
        .to raise_error(ArgumentError, /schema or a block/)
    end
  end

  describe '.tool_name' do
    it 'derives the model-facing name without instantiating the tool' do
      stub_const('SampleTool', Class.new(described_class))

      expect(SampleTool.tool_name).to eq('sample')
    end

    it 'is what the instance name delegates to' do
      stub_const('OverriddenNameTool', Class.new(described_class) do
        def self.tool_name = 'weather'
      end)

      expect(OverriddenNameTool.new.name).to eq('weather')
    end

    it 'follows a class name override' do
      stub_const('ClassNameTool', Class.new(described_class) do
        def self.name = 'Weather'
      end)

      expect(ClassNameTool.tool_name).to eq('weather')
      expect(ClassNameTool.new.name).to eq('weather')
    end
  end

  describe '#name' do
    it 'converts class name to snake_case and removes _tool suffix' do
      stub_const('SampleTool', Class.new(described_class))
      expect(SampleTool.new.name).to eq('sample')
    end

    it 'keeps an instance-level override working' do
      stub_const('InstanceNamedTool', Class.new(described_class) do
        def name = 'custom'
      end)

      expect(InstanceNamedTool.new.name).to eq('custom')
      expect(InstanceNamedTool.tool_name).to eq('instance_named')
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

      result = SignatureTool.new.call(**{ 'questions' => [], 'isOther' => true })

      expect(result).to eq({ error: 'Invalid tool arguments: unknown keyword: isOther' })
    end

    it 'returns an error hash for missing required keyword arguments' do
      stub_const('RequiredTool', Class.new(described_class) do
        def execute(questions:)
          questions
        end
      end)

      result = RequiredTool.new.call

      expect(result).to eq({ error: 'Invalid tool arguments: missing keyword: questions' })
    end

    it 'allows extra keyword arguments when execute accepts keyrest' do
      stub_const('FlexibleTool', Class.new(described_class) do
        def execute(questions:, **extra)
          { questions:, extra: }
        end
      end)

      result = FlexibleTool.new.call(questions: [1], isOther: true)

      expect(result).to eq({ questions: [1], extra: { isOther: true } })
    end

    it 're-raises unrelated ArgumentError from inside execute' do
      stub_const('ManualArgumentErrorTool', Class.new(described_class) do
        def execute(questions:)
          _ = questions
          raise ArgumentError, 'bad value provided'
        end
      end)

      expect { ManualArgumentErrorTool.new.call(questions: []) }
        .to raise_error(ArgumentError, 'bad value provided')
    end

    it 'returns an error hash for unknown arguments when execute takes no keywords' do
      stub_const('NoArgumentTool', Class.new(described_class) do
        def execute
          'ok'
        end
      end)

      result = NoArgumentTool.new.call(unexpected: true)

      expect(result).to eq({ error: 'Invalid tool arguments: unknown keyword: unexpected' })
    end

    context 'with a tool_call keyword' do
      let(:tool_call) { RubyLLM::ToolCall.new(id: 'call_1', name: 'audited', arguments: { 'query' => 'ruby' }) }

      it 'passes the current ToolCall to tools that declare tool_call:' do
        stub_const('AuditedTool', Class.new(described_class) do
          def execute(query:, tool_call: nil)
            { query: query, tool_call_id: tool_call&.id }
          end
        end)

        result = AuditedTool.new.call(query: 'ruby', tool_call: tool_call)

        expect(result).to eq(query: 'ruby', tool_call_id: 'call_1')
      end

      it 'does not pass the ToolCall to tools that do not declare it' do
        stub_const('PlainTool', Class.new(described_class) do
          def execute(query:)
            query
          end
        end)

        expect(PlainTool.new.call(query: 'ruby', tool_call: tool_call)).to eq('ruby')
      end

      it 'stays callable without a tool call' do
        stub_const('StandaloneTool', Class.new(described_class) do
          def execute(query:, tool_call: nil)
            [query, tool_call]
          end
        end)

        expect(StandaloneTool.new.call(query: 'ruby')).to eq(['ruby', nil])
      end

      it 'rejects tool_call as a model-provided argument' do
        stub_const('GuardedTool', Class.new(described_class) do
          def execute(query:, tool_call: nil)
            [query, tool_call]
          end
        end)

        result = GuardedTool.new.call(tool_call: tool_call, **{ 'query' => 'ruby', 'tool_call' => 'spoofed' })

        expect(result).to eq({ error: 'Invalid tool arguments: unknown keyword: tool_call' })
      end

      it 'keeps tool_call out of the inferred argument schema' do
        stub_const('InferredAuditedTool', Class.new(described_class) do
          def execute(query:, tool_call: nil)
            [query, tool_call]
          end
        end)

        schema = InferredAuditedTool.new.parameters_schema

        expect(schema['properties'].keys).to eq(['query'])
        expect(schema['required']).to eq(['query'])
      end
    end
  end

  describe '#parameters_schema' do
    it 'infers flat string parameters from the execute keyword signature' do
      stub_const('InferredSignatureTool', Class.new(described_class) do
        def execute(query:, limit: '5')
          [query, limit]
        end
      end)

      expect(InferredSignatureTool.new.parameters_schema).to eq(
        'type' => 'object',
        'properties' => {
          'query' => { 'type' => 'string' },
          'limit' => { 'type' => 'string' }
        },
        'required' => ['query'],
        'additionalProperties' => false,
        'strict' => true
      )
    end

    it 'uses an empty object schema for tools without keyword arguments' do
      stub_const('EmptySignatureTool', Class.new(described_class) do
        def execute
          'ok'
        end
      end)

      expect(EmptySignatureTool.new.parameters_schema).to eq(
        'type' => 'object',
        'properties' => {},
        'required' => [],
        'additionalProperties' => false,
        'strict' => true
      )
    end

    it 'keeps explicit param declarations authoritative' do
      stub_const('ExplicitParamTool', Class.new(described_class) do
        parameter :query, description: 'Search query'

        def execute(query:, internal:)
          [query, internal]
        end
      end)

      expect(ExplicitParamTool.new.parameters_schema).to eq(
        'type' => 'object',
        'properties' => {
          'query' => { 'type' => 'string', 'description' => 'Search query' }
        },
        'required' => ['query'],
        'additionalProperties' => false,
        'strict' => true
      )
    end

    it 'drops the schema dialect and auto-generated title providers have no use for' do
      stub_const('SchemaMetadataTool', Class.new(described_class) do
        parameters do
          object :window, description: 'Time window to schedule' do
            string :start, description: 'ISO start'
          end
        end

        def execute(window:)
          window
        end
      end)

      schema = SchemaMetadataTool.new.parameters_schema

      expect(schema).not_to include('$schema', 'title')
      expect(schema.dig('properties', 'window', 'description')).to eq('Time window to schedule')
      expect(schema['required']).to eq(['window'])
    end
  end

  describe '.split_result' do
    it 'stringifies a result that is neither text nor structured data' do
      expect(described_class.split_result(42)).to eq(['42', []])
    end

    it 'serializes structured results as JSON' do
      expect(described_class.split_result({ ok: true })).to eq(['{"ok":true}', []])
      expect(described_class.split_result([1, 2])).to eq(['[1,2]', []])
    end

    it 'splits an attachment out of a mixed result' do
      attachment = RubyLLM::Attachment.new(StringIO.new('bytes'), filename: 'a.txt')

      expect(described_class.split_result(['here it is', attachment])).to eq(['here it is', [attachment]])
    end

    it 'returns a lone attachment with empty text' do
      attachment = RubyLLM::Attachment.new(StringIO.new('bytes'), filename: 'a.txt')

      expect(described_class.split_result(attachment)).to eq(['', [attachment]])
    end

    it 'rejects a mixed result carrying anything but text and attachments' do
      attachment = RubyLLM::Attachment.new(StringIO.new('bytes'), filename: 'a.txt')

      expect { described_class.split_result([attachment, 42]) }.to raise_error(
        ArgumentError, /can only contain Strings and RubyLLM::Attachments/
      )
    end
  end

  describe '#execute' do
    it 'tells subclasses to implement it' do
      stub_const('AbstractTool', Class.new(described_class))

      expect { AbstractTool.new.execute }.to raise_error(NotImplementedError, /must implement #execute/)
    end
  end

  describe RubyLLM::Tool::SchemaDefinition do
    describe '.from_parameters' do
      it 'returns nothing without parameters' do
        expect(described_class.from_parameters(nil)).to be_nil
        expect(described_class.from_parameters({})).to be_nil
      end

      it 'gives array parameters a default item type' do
        parameters = { tags: RubyLLM::Parameter.new(:tags, type: 'array') }

        expect(described_class.from_parameters(parameters).json_schema['properties']['tags']).to eq(
          'type' => 'array', 'items' => { 'type' => 'string' }
        )
      end
    end

    describe '.map_type' do
      {
        'integer' => 'integer',
        'int' => 'integer',
        'number' => 'number',
        'float' => 'number',
        'double' => 'number',
        'boolean' => 'boolean',
        'array' => 'array',
        'object' => 'object',
        'anything else' => 'string'
      }.each do |declared, expected|
        it "maps #{declared} to #{expected}" do
          expect(described_class.map_type(declared)).to eq(expected)
        end
      end
    end

    describe '#json_schema' do
      it 'returns nothing when neither a schema nor a block was given' do
        expect(described_class.new.json_schema).to be_nil
      end

      it 'unwraps a schema object that knows how to describe itself' do
        schema = Class.new do
          def to_json_schema = { schema: { type: 'object', properties: { a: { type: 'string' } } } }
        end.new

        expect(described_class.new(schema: schema).json_schema).to eq(
          'type' => 'object', 'properties' => { 'a' => { 'type' => 'string' } }
        )
      end

      it 'instantiates a schema class' do
        schema_class = Class.new do
          def to_json_schema = { 'schema' => { 'type' => 'object' } }
        end

        expect(described_class.new(schema: schema_class).json_schema).to eq('type' => 'object')
      end

      it 'returns nothing for a schema it cannot read' do
        expect(described_class.new(schema: 42).json_schema).to be_nil
      end

      it 'builds from a block' do
        definition = described_class.new(block: proc { string :city })

        expect(definition.json_schema['properties']).to have_key('city')
      end
    end

    describe '#present?' do
      it 'is true only with a schema or a block' do
        expect(described_class.new).not_to be_present
        expect(described_class.new(schema: { type: 'object' })).to be_present
        expect(described_class.new(block: proc {})).to be_present
      end
    end
  end
end
