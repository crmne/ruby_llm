# frozen_string_literal: true

require 'spec_helper'
require 'json-schema'

RSpec.describe RubyLLM::Models do
  let(:schema_path) { described_class.schema_file }
  let(:models_json_path) { RubyLLM.config.model_registry_file }

  it 'validates that models.json conforms to the schema' do
    models_data = JSON.parse(File.read(models_json_path))

    validation_errors = JSON::Validator.fully_validate(schema_path, models_data)

    expect(validation_errors).to be_empty,
                                 "models.json has validation errors:\n#{validation_errors.join("\n")}"
  end

  it 'validates that all capabilities are arrays' do
    models_data = JSON.parse(File.read(models_json_path))

    models_with_non_array_capabilities = models_data.select do |model|
      model['capabilities'] && !model['capabilities'].is_a?(Array)
    end

    expect(models_with_non_array_capabilities).to be_empty,
                                                  'Models with non-array capabilities: ' \
                                                  "#{models_with_non_array_capabilities.map { |m| m['id'] }.join(', ')}"
  end
end
