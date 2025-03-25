# frozen_string_literal: true

require 'ruby_llm'

def pull_model(ollama_library_model_spec, description)
  warn "+ pulling #{ollama_library_model_spec} from Ollama library (#{description})"

  # ugly but effective
  response = RubyLLM::Providers::Ollama.send(
    :post, '/api/pull', {
      model: ollama_library_model_spec,
      insecure: false,
      stream: false
    }
  )

  unless response.body['status'] == 'success'
    raise 'non-successful response when pulling model; check Ollama server logs'
  end

  warn '+ done'
end

namespace :ollama do
  desc 'Install some tiny models required for running Ollama specs (downloads about 150 MB into your Ollama server)'
  task :install_models_for_specs do
    RubyLLM.config.ollama_api_base_url = ENV.fetch('OLLAMA_API_BASE_URL')

    pull_model('smollm:135m', '92MiB chat model')
    pull_model('snowflake-arctic-embed:22m', '46MiB embedding model')
  end
end
