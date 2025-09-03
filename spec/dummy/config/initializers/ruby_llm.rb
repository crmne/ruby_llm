# frozen_string_literal: true

RubyLLM.configure do |config|
  # Enable DB-backed model registry for tests
  config.model_registry_class = 'Model'
end
