# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Tool do
  # Helper tool class for testing instance-level customization
  class TestWeatherTool < RubyLLM::Tool # rubocop:disable Lint/ConstantDefinitionInBlock,RSpec/LeakyConstantDeclaration
    description 'Gets current weather for a location'
    param :latitude, desc: 'Latitude (e.g., 52.5200)'
    param :longitude, desc: 'Longitude (e.g., 13.4050)'
    with_params cache_control: { type: 'ephemeral' }

    def execute(latitude:, longitude:)
      "Current weather at #{latitude}, #{longitude}: 15°C"
    end
  end

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

  describe 'instance-level customization' do
    describe '#initialize' do
      it 'accepts optional description parameter' do
        tool = TestWeatherTool.new(description: 'Custom weather description')
        expect(tool.description).to eq('Custom weather description')
      end

      it 'accepts optional parameters parameter' do
        custom_params = {
          city: RubyLLM::Parameter.new(:city, type: 'string', desc: 'City name', required: true)
        }
        tool = TestWeatherTool.new(parameters: custom_params)
        expect(tool.parameters).to eq(custom_params)
      end

      it 'accepts optional provider_params parameter' do
        tool = TestWeatherTool.new(provider_params: { timeout: 30 })
        expect(tool.provider_params).to eq({ timeout: 30 })
      end

      it 'accepts all optional parameters at once' do
        custom_params = {
          city: RubyLLM::Parameter.new(:city, type: 'string', desc: 'City name', required: true)
        }
        tool = TestWeatherTool.new(
          description: 'Custom description',
          parameters: custom_params,
          provider_params: { timeout: 30 }
        )

        expect(tool.description).to eq('Custom description')
        expect(tool.parameters).to eq(custom_params)
        expect(tool.provider_params).to eq({ timeout: 30 })
      end
    end

    describe 'fallback to class-level definitions' do
      it 'falls back to class description when not overridden' do
        tool = TestWeatherTool.new
        expect(tool.description).to eq('Gets current weather for a location')
      end

      it 'falls back to class parameters when not overridden' do
        tool = TestWeatherTool.new
        expect(tool.parameters).to eq(TestWeatherTool.parameters)
        expect(tool.parameters.keys).to contain_exactly(:latitude, :longitude)
      end

      it 'falls back to class provider_params when not overridden' do
        tool = TestWeatherTool.new
        expect(tool.provider_params).to eq({ cache_control: { type: 'ephemeral' } })
      end
    end

    describe 'instance setters' do
      it 'allows setting description after initialization' do
        tool = TestWeatherTool.new
        tool.description = 'Updated description'
        expect(tool.description).to eq('Updated description')
      end

      it 'allows setting parameters after initialization' do
        tool = TestWeatherTool.new
        custom_params = {
          city: RubyLLM::Parameter.new(:city, type: 'string', desc: 'City name', required: true)
        }
        tool.parameters = custom_params
        expect(tool.parameters).to eq(custom_params)
      end

      it 'allows setting provider_params after initialization' do
        tool = TestWeatherTool.new
        tool.provider_params = { max_retries: 3 }
        expect(tool.provider_params).to eq({ max_retries: 3 })
      end
    end

    describe '#params_schema with instance parameters' do
      it 'generates schema from instance parameters' do
        custom_params = {
          city: RubyLLM::Parameter.new(:city, type: 'string', desc: 'City name', required: true),
          country: RubyLLM::Parameter.new(:country, type: 'string', desc: 'Country code', required: false)
        }
        tool = TestWeatherTool.new(parameters: custom_params)

        schema = tool.params_schema
        expect(schema['type']).to eq('object')
        expect(schema['properties']).to have_key('city')
        expect(schema['properties']).to have_key('country')
        expect(schema['properties']['city']['description']).to eq('City name')
        expect(schema['required']).to contain_exactly('city')
      end

      it 'returns nil for empty instance parameters' do
        tool = TestWeatherTool.new(parameters: {})
        expect(tool.params_schema).to be_nil
      end

      it 'uses class-level schema when no instance parameters set' do
        tool = TestWeatherTool.new
        schema = tool.params_schema

        expect(schema['type']).to eq('object')
        expect(schema['properties']).to have_key('latitude')
        expect(schema['properties']).to have_key('longitude')
      end
    end

    describe 'multiple instances with different configurations' do
      it 'allows different instances of the same class to have different descriptions' do
        tool1 = TestWeatherTool.new(description: 'Get Berlin weather')
        tool2 = TestWeatherTool.new(description: 'Get Paris weather')
        tool3 = TestWeatherTool.new

        expect(tool1.description).to eq('Get Berlin weather')
        expect(tool2.description).to eq('Get Paris weather')
        expect(tool3.description).to eq('Gets current weather for a location')
      end

      it 'allows different instances to have different parameters' do
        berlin_params = {
          city: RubyLLM::Parameter.new(:city, type: 'string', desc: 'Berlin district', required: true)
        }
        paris_params = {
          arrondissement: RubyLLM::Parameter.new(:arrondissement, type: 'integer', desc: 'Paris district', required: true)
        }

        tool1 = TestWeatherTool.new(parameters: berlin_params)
        tool2 = TestWeatherTool.new(parameters: paris_params)
        tool3 = TestWeatherTool.new

        expect(tool1.parameters.keys).to contain_exactly(:city)
        expect(tool2.parameters.keys).to contain_exactly(:arrondissement)
        expect(tool3.parameters.keys).to contain_exactly(:latitude, :longitude)
      end

      it 'does not affect class-level definitions' do
        tool = TestWeatherTool.new(description: 'Custom description')

        expect(tool.description).to eq('Custom description')
        expect(TestWeatherTool.description).to eq('Gets current weather for a location')
      end
    end
  end
end
