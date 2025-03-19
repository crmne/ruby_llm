# frozen_string_literal: true

module RubyLLM
  module Providers
    module Bedrock
      # Defines capabilities and pricing for AWS Bedrock models
      module Capabilities
        module_function

        # Default prices per 1000 input tokens
        DEFAULT_INPUT_PRICE = 0.0
        DEFAULT_OUTPUT_PRICE = 0.0

        ANTHROPIC_CLAUDE_3_OPUS_INPUT_PRICE = 0.015
        ANTHROPIC_CLAUDE_3_OPUS_OUTPUT_PRICE = 0.075

        ANTHROPIC_CLAUDE_3_SONNET_INPUT_PRICE = 0.003
        ANTHROPIC_CLAUDE_3_SONNET_OUTPUT_PRICE = 0.015

        ANTHROPIC_CLAUDE_3_HAIKU_INPUT_PRICE = 0.0005
        ANTHROPIC_CLAUDE_3_HAIKU_OUTPUT_PRICE = 0.0025

        ANTHROPIC_CLAUDE_2_INPUT_PRICE = 0.008
        ANTHROPIC_CLAUDE_2_OUTPUT_PRICE = 0.024

        ANTHROPIC_CLAUDE_INSTANT_INPUT_PRICE = 0.0008
        ANTHROPIC_CLAUDE_INSTANT_OUTPUT_PRICE = 0.0024

        COHERE_COMMAND_INPUT_PRICE = 0.0015
        COHERE_COMMAND_OUTPUT_PRICE = 0.0020

        COHERE_COMMAND_LIGHT_INPUT_PRICE = 0.0003
        COHERE_COMMAND_LIGHT_OUTPUT_PRICE = 0.0006

        META_LLAMA_70B_INPUT_PRICE = 0.00195
        META_LLAMA_70B_OUTPUT_PRICE = 0.00256

        META_LLAMA_13B_INPUT_PRICE = 0.00075
        META_LLAMA_13B_OUTPUT_PRICE = 0.001

        META_LLAMA_7B_INPUT_PRICE = 0.0004
        META_LLAMA_7B_OUTPUT_PRICE = 0.0005

        MISTRAL_7B_INPUT_PRICE = 0.0002
        MISTRAL_7B_OUTPUT_PRICE = 0.0002

        MISTRAL_MIXTRAL_INPUT_PRICE = 0.0007
        MISTRAL_MIXTRAL_OUTPUT_PRICE = 0.0007

        MISTRAL_LARGE_INPUT_PRICE = 0.002
        MISTRAL_LARGE_OUTPUT_PRICE = 0.002

        def self.input_price_for(model_id)
          case model_id
          when /anthropic\.claude-3-opus/
            ANTHROPIC_CLAUDE_3_OPUS_INPUT_PRICE
          when /anthropic\.claude-3-sonnet/
            ANTHROPIC_CLAUDE_3_SONNET_INPUT_PRICE
          when /anthropic\.claude-3-haiku/
            ANTHROPIC_CLAUDE_3_HAIKU_INPUT_PRICE
          when /anthropic\.claude-v2/
            ANTHROPIC_CLAUDE_2_INPUT_PRICE
          when /anthropic\.claude-instant/
            ANTHROPIC_CLAUDE_INSTANT_INPUT_PRICE
          when /cohere\.command-text/
            COHERE_COMMAND_INPUT_PRICE
          when /cohere\.command-light/
            COHERE_COMMAND_LIGHT_INPUT_PRICE
          when /meta\.llama.*70b/i
            META_LLAMA_70B_INPUT_PRICE
          when /meta\.llama.*13b/i
            META_LLAMA_13B_INPUT_PRICE
          when /meta\.llama.*7b/i
            META_LLAMA_7B_INPUT_PRICE
          when /mistral\.mistral-7b/
            MISTRAL_7B_INPUT_PRICE
          when /mistral\.mixtral/
            MISTRAL_MIXTRAL_INPUT_PRICE
          when /mistral\.mistral-large/
            MISTRAL_LARGE_INPUT_PRICE
          else
            DEFAULT_INPUT_PRICE
          end
        end

        def self.output_price_for(model_id)
          case model_id
          when /anthropic\.claude-3-opus/
            ANTHROPIC_CLAUDE_3_OPUS_OUTPUT_PRICE
          when /anthropic\.claude-3-sonnet/
            ANTHROPIC_CLAUDE_3_SONNET_OUTPUT_PRICE
          when /anthropic\.claude-3-haiku/
            ANTHROPIC_CLAUDE_3_HAIKU_OUTPUT_PRICE
          when /anthropic\.claude-v2/
            ANTHROPIC_CLAUDE_2_OUTPUT_PRICE
          when /anthropic\.claude-instant/
            ANTHROPIC_CLAUDE_INSTANT_OUTPUT_PRICE
          when /cohere\.command-text/
            COHERE_COMMAND_OUTPUT_PRICE
          when /cohere\.command-light/
            COHERE_COMMAND_LIGHT_OUTPUT_PRICE
          when /meta\.llama.*70b/i
            META_LLAMA_70B_OUTPUT_PRICE
          when /meta\.llama.*13b/i
            META_LLAMA_13B_OUTPUT_PRICE
          when /meta\.llama.*7b/i
            META_LLAMA_7B_OUTPUT_PRICE
          when /mistral\.mistral-7b/
            MISTRAL_7B_OUTPUT_PRICE
          when /mistral\.mixtral/
            MISTRAL_MIXTRAL_OUTPUT_PRICE
          when /mistral\.mistral-large/
            MISTRAL_LARGE_OUTPUT_PRICE
          else
            DEFAULT_OUTPUT_PRICE
          end
        end

        def self.supports_chat?(model_id)
          case model_id
          when /anthropic\.claude/, /cohere\.command/, /meta\.llama/, /mistral\./
            true
          else
            false
          end
        end

        def self.supports_streaming?(model_id)
          case model_id
          when /anthropic\.claude/, /cohere\.command/, /meta\.llama/, /mistral\./
            true
          else
            false
          end
        end

        def self.supports_images?(model_id)
          case model_id
          when /anthropic\.claude-3/, /meta\.llama3-2-(?:11b|90b)/
            true
          else
            false
          end
        end

        def self.context_window_for(model_id)
          case model_id
          when /anthropic\.claude-3-opus/
            200_000
          when /anthropic\.claude-3-sonnet/
            200_000
          when /anthropic\.claude-3-haiku/
            200_000
          when /anthropic\.claude-2/
            100_000
          when /meta\.llama/
            4_096
          else
            4_096
          end
        end

        def self.supports_vision?(model_id)
          case model_id
          when /anthropic\.claude-3/, /meta\.llama3-2-(?:11b|90b)/
            true
          else
            false
          end
        end

        def self.max_tokens_for(model_id)
          case model_id
          when /anthropic\.claude-3/
            4096
          when /anthropic\.claude-v2/
            4096
          when /anthropic\.claude-instant/
            4096
          when /meta\.llama/
            4096
          when /mistral\./
            4096
          else
            4096
          end
        end

        def supports_functions?(model_id)
          model_id.match?(/anthropic\.claude-3/)
        end

        def supports_audio?(_model_id)
          false
        end

        def supports_json_mode?(model_id)
          model_id.match?(/anthropic\.claude-3/)
        end

        def format_display_name(model_id)
          case model_id
          when /anthropic\.claude-3/
            'Claude 3'
          when /anthropic\.claude-v2/
            'Claude 2'
          when /anthropic\.claude-instant/
            'Claude Instant'
          when /amazon\.titan/
            'Titan'
          else
            model_id
          end
        end

        def model_type(_model_id)
          'chat'
        end

        def supports_structured_output?(model_id)
          model_id.match?(/anthropic\.claude-3/)
        end

        def model_family(model_id)
          case model_id
          when /anthropic\.claude-3/
            :claude3
          when /anthropic\.claude-v2/
            :claude2
          when /anthropic\.claude-instant/
            :claude_instant
          when /amazon\.titan/
            :titan
          else
            :other
          end
        end

        def default_input_price
          0.1
        end

        def default_output_price
          0.2
        end
      end
    end
  end
end 