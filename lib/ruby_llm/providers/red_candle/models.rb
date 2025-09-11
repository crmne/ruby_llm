# frozen_string_literal: true

module RubyLLM
  module Providers
    class RedCandle
      # Models methods of the RedCandle integration
      module Models
        # TODO: red-candle supports more models, but let's start with some well tested ones.
        SUPPORTED_MODELS = [
          {
            id: 'google/gemma-3-4b-it-qat-q4_0-gguf',
            name: 'Gemma 3 4B Instruct (Quantized)',
            gguf_file: 'gemma-3-4b-it-q4_0.gguf',
            tokenizer: 'google/gemma-3-4b-it', # Tokenizer from base model
            context_window: 8192,
            family: 'gemma',
            architecture: 'gemma2',
            supports_chat: true,
            supports_structured: true
          },
          {
            id: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
            name: 'TinyLlama 1.1B Chat (Quantized)',
            gguf_file: 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
            context_window: 2048,
            family: 'llama',
            architecture: 'llama',
            supports_chat: true,
            supports_structured: true
          },
          {
            id: 'TheBloke/Mistral-7B-Instruct-v0.2-GGUF',
            name: 'Mistral 7B Instruct v0.2 (Quantized)',
            gguf_file: 'mistral-7b-instruct-v0.2.Q4_K_M.gguf',
            tokenizer: 'mistralai/Mistral-7B-Instruct-v0.2',
            context_window: 32_768,
            family: 'mistral',
            architecture: 'mistral',
            supports_chat: true,
            supports_structured: true
          },
          {
            id: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF',
            name: 'Qwen 2.1.5B Instruct (Quantized)',
            gguf_file: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
            context_window: 32_768,
            family: 'qwen2',
            architecture: 'qwen2',
            supports_chat: true,
            supports_structured: true
          },
          {
            id: 'microsoft/Phi-3-mini-4k-instruct',
            name: 'Phi 3',
            context_window: 4096,
            family: 'phi',
            architecture: 'phi',
            supports_chat: true,
            supports_structured: true
          }
        ].freeze

        def list_models
          SUPPORTED_MODELS.map do |model_data|
            Model::Info.new(
              id: model_data[:id],
              name: model_data[:name],
              provider: slug,
              family: model_data[:family],
              context_window: model_data[:context_window],
              capabilities: %w[streaming structured_output],
              modalities: { input: %w[text], output: %w[text] }
            )
          end
        end

        def models
          @models ||= list_models
        end

        def model(id)
          models.find { |m| m.id == id } ||
            raise(Error.new(nil,
                            "Model #{id} not found in Red Candle provider. Available models: #{model_ids.join(', ')}"))
        end

        def model_available?(id)
          SUPPORTED_MODELS.any? { |m| m[:id] == id }
        end

        def model_ids
          SUPPORTED_MODELS.map { |m| m[:id] }
        end

        def model_info(id)
          SUPPORTED_MODELS.find { |m| m[:id] == id }
        end

        def supports_chat?(model_id)
          info = model_info(model_id)
          info ? info[:supports_chat] : false
        end

        def supports_structured?(model_id)
          info = model_info(model_id)
          info ? info[:supports_structured] : false
        end

        def gguf_file_for(model_id)
          info = model_info(model_id)
          info ? info[:gguf_file] : nil
        end

        def tokenizer_for(model_id)
          info = model_info(model_id)
          info ? info[:tokenizer] : nil
        end
      end
    end
  end
end
