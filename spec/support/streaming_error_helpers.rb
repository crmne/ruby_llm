# frozen_string_literal: true

module StreamingErrorHelpers
  ERROR_HANDLING_CONFIGS = {
    anthropic: {
      url: 'https://api.anthropic.com/v1/messages',
      error_response: {
        type: 'error',
        error: {
          type: 'overloaded_error',
          message: 'Overloaded'
        }
      },
      chunk_status: 529,
      expected_error: RubyLLM::OverloadedError
    },
    openai: {
      url: 'https://api.openai.com/v1/chat/completions',
      error_response: {
        error: {
          message: 'The server is temporarily overloaded. Please try again later.',
          type: 'server_error',
          param: nil,
          code: nil
        }
      },
      chunk_status: 500,
      expected_error: RubyLLM::ServerError
    },
    gemini: {
      url: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse',
      error_response: {
        error: {
          code: 529,
          message: 'Service overloaded - please try again later',
          status: 'RESOURCE_EXHAUSTED'
        }
      },
      chunk_status: 529,
      expected_error: RubyLLM::OverloadedError
    },
    deepseek: {
      url: 'https://api.deepseek.com/chat/completions',
      error_response: {
        error: {
          message: 'Service overloaded - please try again later',
          type: 'server_error',
          param: nil,
          code: nil
        }
      },
      chunk_status: 500,
      expected_error: RubyLLM::ServerError
    },
    openrouter: {
      url: 'https://openrouter.ai/api/v1/chat/completions',
      error_response: {
        error: {
          message: 'Service overloaded - please try again later',
          type: 'server_error',
          param: nil,
          code: nil
        }
      },
      chunk_status: 500,
      expected_error: RubyLLM::ServerError
    },
    ollama: {
      url: 'http://localhost:11434/v1/chat/completions',
      error_response: {
        error: {
          message: 'Service overloaded - please try again later',
          type: 'server_error',
          param: nil,
          code: nil
        }
      },
      chunk_status: 500,
      expected_error: RubyLLM::ServerError
    },
    bedrock: {
      url: 'https://bedrock-runtime.us-west-2.amazonaws.com/model/anthropic.claude-3-5-haiku-20241022-v1:0/invoke-with-response-stream',
      error_response: {
        error: {
          message: 'Service overloaded - please try again later',
          type: 'server_error'
        }
      },
      chunk_status: 500,
      expected_error: RubyLLM::ServerError
    },
    gpustack: {
      url: 'http://localhost:11444/v1/chat/completions',
      error_response: {
        error: {
          message: 'Service overloaded - please try again later',
          type: 'server_error',
          param: nil,
          code: nil
        }
      },
      chunk_status: 500,
      expected_error: RubyLLM::ServerError
    },
    perplexity: {
      url: 'https://api.perplexity.ai/chat/completions',
      error_response: {
        error: {
          message: 'Service overloaded - please try again later',
          type: 'server_error',
          param: nil,
          code: nil
        }
      },
      chunk_status: 500,
      expected_error: RubyLLM::ServerError
    },
    mistral: {
      url: 'https://api.mistral.ai/v1/chat/completions',
      error_response: {
        error: {
          message: 'Service overloaded - please try again later',
          type: 'server_error',
          param: nil,
          code: nil
        }
      },
      chunk_status: 500,
      expected_error: RubyLLM::ServerError
    },
    vertexai: {
      url: lambda {
        project_id = ENV.fetch('GOOGLE_CLOUD_PROJECT', 'test-project')
        location = ENV.fetch('GOOGLE_CLOUD_LOCATION', 'us-central1')
        "https://#{location}-aiplatform.googleapis.com/v1beta1/projects/#{project_id}/locations/#{location}/publishers/google/models/gemini-2.5-flash:streamGenerateContent?alt=sse"
      }.call,
      error_response: {
        error: {
          code: 529,
          message: 'Service overloaded - please try again later',
          status: 'RESOURCE_EXHAUSTED'
        }
      },
      chunk_status: 529,
      expected_error: RubyLLM::OverloadedError
    }
  }.freeze

  def error_handling_supported?(provider)
    ERROR_HANDLING_CONFIGS.key?(provider)
  end

  def expected_error_for(provider)
    ERROR_HANDLING_CONFIGS[provider][:expected_error]
  end

  def stub_error_response(provider, type)
    config = ERROR_HANDLING_CONFIGS[provider]
    return unless config

    body = case type
           when :chunk
             "#{config[:error_response].to_json}\n\n"
           when :event
             "event: error\ndata: #{config[:error_response].to_json}\n\n"
           end

    status = type == :chunk ? config[:chunk_status] : 200

    stub_request(:post, config[:url])
      .to_return(
        status: status,
        body: body,
        headers: { 'Content-Type' => 'text/event-stream' }
      )
  end
end
