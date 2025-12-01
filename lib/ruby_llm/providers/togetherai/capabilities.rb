# frozen_string_literal: true

module RubyLLM
  module Providers
    class TogetherAI
      # Capabilities for the Together.ai provider
      module Capabilities
        def self.supports_streaming?(model_id)
          # Most chat models support streaming, exclude specialized non-chat models
          supports_chat_for?(model_id)
        end

        def self.supports_vision?(model_id)
          supports_vision_for?(model_id)
        end

        def self.supports_functions?(model_id)
          supports_tools_for?(model_id)
        end

        def self.supports_json_mode?(model_id)
          # Most chat models support JSON mode, exclude specialized models
          supports_chat_for?(model_id) && !model_id.match?(/whisper|voxtral/i)
        end

        def self.model_type(model_id)
          return 'embedding' if supports_embeddings_for?(model_id)
          return 'image' if supports_images_for?(model_id)
          return 'audio' if supports_audio_for?(model_id)
          return 'moderation' if supports_moderation_for?(model_id)

          'chat'
        end

        def self.normalize_temperature(temperature, _model)
          # Together.ai accepts temperature values between 0.0 and 2.0
          return temperature if temperature.nil?

          temperature.clamp(0.0, 2.0)
        end

        def self.max_tokens_for_model(_model)
          # Default max tokens for Together.ai models
          # This would ideally be model-specific
          4096
        end

        def self.format_display_name(model_id)
          model_id.split('/').last.tr('-', ' ').titleize
        end

        def self.model_family(model_id)
          case model_id
          when /llama/i then 'llama'
          when /qwen/i then 'qwen'
          when /mistral/i then 'mistral'
          when /deepseek/i then 'deepseek'
          when /gemma/i then 'gemma'
          when /moonshot/i then 'kimi'
          when /glm/i then 'glm'
          when /cogito/i then 'cogito'
          when /arcee/i then 'arcee'
          when /marin/i then 'marin'
          when /gryphe/i then 'mythomax'
          when /openai/i then 'openai'
          else 'other'
          end
        end

        def self.context_window_for(model_id)
          # Context windows based on Together.ai model specifications
          # Using a hash lookup for better performance and maintainability
          context_windows = {
            # Ultra large context (1M+ tokens)
            'meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8' => 524_288,
            'meta-llama/Llama-4-Scout-17B-16E-Instruct' => 327_680,

            # 256K+ context models
            'moonshotai/Kimi-K2-Instruct-0905' => 262_144,
            'moonshotai/Kimi-K2-Thinking' => 262_144,
            'Qwen/Qwen3-235B-A22B-Thinking-2507' => 262_144,
            'Qwen/Qwen3-235B-A22B-Instruct-2507-tput' => 262_144,
            'Qwen/Qwen3-Next-80B-A3B-Instruct' => 262_144,
            'Qwen/Qwen3-Next-80B-A3B-Thinking' => 262_144,
            'Qwen/Qwen3-Coder-480B-A35B-Instruct-FP8' => 256_000,

            # ~200K context models
            'zai-org/GLM-4.6' => 202_752,

            # ~160K context models
            'deepseek-ai/DeepSeek-R1' => 163_839,
            'deepseek-ai/DeepSeek-R1-0528-tput' => 163_839,
            'deepseek-ai/DeepSeek-V3' => 163_839,

            # ~130K context models
            'meta-llama/Llama-3.3-70B-Instruct-Turbo' => 131_072,
            'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo' => 131_072,
            'meta-llama/Meta-Llama-3.1-405B-Instruct-Turbo' => 130_815,
            'meta-llama/Llama-3.2-3B-Instruct-Turbo' => 131_072,
            'deepseek-ai/DeepSeek-R1-Distill-Llama-70B' => 131_072,
            'deepseek-ai/DeepSeek-R1-Distill-Qwen-14B' => 131_072,
            'zai-org/GLM-4.5-Air-FP8' => 131_072,

            # ~128K context models
            'moonshotai/Kimi-K2-Instruct' => 128_000,
            'deepseek-ai/DeepSeek-V3.1' => 128_000,
            'openai/gpt-oss-120b' => 128_000,
            'openai/gpt-oss-20b' => 128_000,
            'arcee-ai/virtuoso-medium-v2' => 128_000,
            'arcee-ai/virtuoso-large' => 128_000,
            'arcee-ai/maestro-reasoning' => 128_000,
            'arcee_ai/arcee-spotlight' => 128_000,

            # ~40K context models
            'Qwen/Qwen3-235B-A22B-fp8-tput' => 40_960,
            'mistralai/Magistral-Small-2506' => 40_960,

            # ~32K context models (most common)
            'Qwen/Qwen2.5-7B-Instruct-Turbo' => 32_768,
            'Qwen/Qwen2.5-72B-Instruct-Turbo' => 32_768,
            'Qwen/Qwen2.5-VL-72B-Instruct' => 32_768,
            'Qwen/Qwen2.5-Coder-32B-Instruct' => 32_768,
            'Qwen/QwQ-32B' => 32_768,
            'mistralai/Mistral-Small-24B-Instruct-2501' => 32_768,
            'mistralai/Mistral-7B-Instruct-v0.2' => 32_768,
            'mistralai/Mistral-7B-Instruct-v0.3' => 32_768,
            'google/gemma-3n-E4B-it' => 32_768,
            'arcee-ai/coder-large' => 32_768,
            'arcee-ai/caller' => 32_768,
            'arcee-ai/arcee-blitz' => 32_768,

            # ~8K context models
            'meta-llama/Llama-3.3-70B-Instruct-Turbo-Free' => 8_193,
            'meta-llama/Meta-Llama-3-8B-Instruct-Lite' => 8_192,
            'meta-llama/Llama-3-70b-chat-hf' => 8_192,
            'mistralai/Mistral-7B-Instruct-v0.1' => 8_192,
            'google/gemma-2b-it' => 8_192,

            # ~4K context models
            'marin-community/marin-8b-instruct' => 4_096,
            'Gryphe/MythoMax-L2-13b' => 4_096
          }

          # Check for exact match first
          return context_windows[model_id] if context_windows.key?(model_id)

          # Pattern matching for model families
          case model_id
          when %r{^deepcogito/cogito-v2.*} then 32_768
          when %r{^Qwen/Qwen3.*235B.*} then 262_144
          when %r{^meta-llama/Llama-4.*} then 1_048_576
          else 16_384 # Default context window for unknown models
          end
        end

        def self.max_tokens_for(model_id)
          max_tokens_for_model(model_id)
        end

        def self.modalities_for(model_id)
          input_modalities = ['text']
          output_modalities = ['text']

          input_modalities << 'image' if supports_vision_for?(model_id)
          input_modalities << 'audio' if supports_audio_for?(model_id) && !model_id.match?(/sonic/i)

          output_modalities = ['image'] if supports_images_for?(model_id)
          output_modalities << 'audio' if model_id.match?(/sonic|voxtral/i)

          { input: input_modalities, output: output_modalities }
        end

        def self.capabilities_for(model_id)
          capabilities = []
          capabilities << 'chat' if supports_chat_for?(model_id)
          capabilities << 'embeddings' if supports_embeddings_for?(model_id)
          capabilities << 'tools' if supports_tools_for?(model_id)
          capabilities << 'vision' if supports_vision_for?(model_id)
          capabilities << 'images' if supports_images_for?(model_id)
          capabilities << 'audio' if supports_audio_for?(model_id)
          capabilities << 'moderation' if supports_moderation_for?(model_id)
          capabilities
        end

        def self.supports_tools_for?(model_id)
          # Most chat models support function calling, exclude non-chat models
          return false if supports_embeddings_for?(model_id)
          return false if supports_images_for?(model_id)
          return false if supports_audio_for?(model_id)
          return false if supports_moderation_for?(model_id)

          true
        end

        def self.supports_chat_for?(model_id)
          # Chat models are the main category, exclude non-chat models
          return false if supports_embeddings_for?(model_id)
          return false if supports_images_for?(model_id)
          return false if supports_audio_for?(model_id) && !supports_vision_for?(model_id)
          return false if supports_moderation_for?(model_id) && !model_id.match?(/Llama-Guard/i)

          true
        end

        def self.supports_embeddings_for?(model_id)
          # Embedding models
          model_id.match?(/bge-|m2-bert|gte-|multilingual-e5/i)
        end

        # Methods for detecting different model capabilities
        def self.supports_images_for?(model_id)
          # Image generation models (FLUX, Stable Diffusion, Imagen)
          model_id.match?(/FLUX|stable-diffusion|imagen/i)
        end

        def self.supports_vision_for?(model_id)
          # Vision models (multimodal models that can process images)
          model_id.match?(/Scout|VL|spotlight/i)
        end

        def self.supports_video_for?(_model_id)
          false # Video generation support will be added in future PR
        end

        def self.supports_audio_for?(model_id)
          # Audio models (TTS and transcription)
          model_id.match?(/sonic|whisper|voxtral|orpheus/i)
        end

        def self.supports_transcription_for?(model_id)
          # Transcription-specific models
          model_id.match?(/whisper/i)
        end

        def self.supports_moderation_for?(model_id)
          # Moderation models
          model_id.match?(/Guard|VirtueGuard/i)
        end

        def self.supports_rerank_for?(_model_id)
          false # Rerank support will be added in future PR
        end

        def self.pricing_for(_model_id)
          # Placeholder pricing - should be model-specific
          {
            input_tokens: 0.001,
            output_tokens: 0.002
          }
        end
      end
    end
  end
end
