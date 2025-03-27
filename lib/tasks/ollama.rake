# frozen_string_literal: true

require 'ruby_llm'

def pull_model(ollama_library_model_spec, description)
  warn <<~MESSAGE
    + pulling #{ollama_library_model_spec} from Ollama library (#{description}); monitor progress in Ollama server logs
  MESSAGE

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
  desc 'Install some models required for running Ollama specs (downloads about 7.5 GiB into your Ollama server)'
  task :install_models_for_specs do
    RubyLLM.config.request_timeout = 60 * 30 # 30min timeout per model since pull is synchronous
    RubyLLM.config.ollama_api_base_url = ENV.fetch('OLLAMA_API_BASE_URL')

    pull_model('llama3.1:8b', '4.9 GiB chat model')
    pull_model('granite3.2-vision:2b', '2.4 GiB vision model')
    pull_model('snowflake-arctic-embed:22m', '46 MiB embedding model')
  end
end
