# frozen_string_literal: true

module RubyLLM
  module Providers
    module Mistral
      # Determines capabilities for Mistral models
      module Capabilities
        module_function

        def supports_streaming?(_model_id)
          true
        end

        def supports_tools?(_model_id)
          true
        end

        def supports_vision?(model_id)
          model_id.include?('pixtral')
        end

        def supports_json_mode?(_model_id)
          true
        end

        def format_display_name(model_id)
          case model_id
          when /mistral-large/ then 'Mistral Large'
          when /mistral-medium/ then 'Mistral Medium'
          when /mistral-small/ then 'Mistral Small'
          when /ministral-3b/ then 'Ministral 3B'
          when /ministral-8b/ then 'Ministral 8B'
          when /codestral/ then 'Codestral'
          when /pixtral-large/ then 'Pixtral Large'
          when /pixtral-12b/ then 'Pixtral 12B'
          when /mistral-embed/ then 'Mistral Embed'
          when /mistral-moderation/ then 'Mistral Moderation'
          else model_id.split('-').map(&:capitalize).join(' ')
          end
        end

        def model_family(model_id)
          case model_id
          when /mistral-large/ then 'mistral-large'
          when /mistral-medium/ then 'mistral-medium'
          when /mistral-small/ then 'mistral-small'
          when /ministral/ then 'ministral'
          when /codestral/ then 'codestral'
          when /pixtral/ then 'pixtral'
          when /mistral-embed/ then 'mistral-embed'
          when /mistral-moderation/ then 'mistral-moderation'
          else 'mistral'
          end
        end

        def context_window_for(_model_id)
          32_768 # Default for most Mistral models
        end

        def max_tokens_for(_model_id)
          8192 # Default for most Mistral models
        end

        def modalities_for(model_id)
          case model_id
          when /pixtral/
            {
              input: %w[text image],
              output: ['text']
            }
          when /embed/
            {
              input: ['text'],
              output: ['embedding']
            }
          else
            {
              input: ['text'],
              output: ['text']
            }
          end
        end

        def capabilities_for(model_id)
          case model_id
          when /embed/ then { embeddings: true }
          when /moderation/ then { moderation: true }
          else
            {
              chat: true,
              streaming: supports_streaming?(model_id),
              tools: supports_tools?(model_id),
              vision: supports_vision?(model_id),
              json_mode: supports_json_mode?(model_id)
            }
          end
        end

        def pricing_for(_model_id)
          {
            input: 0.0,
            output: 0.0
          }
        end
      end
    end
  end
end
