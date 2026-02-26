# frozen_string_literal: true

module RubyLLM
  module Providers
    class VoyageAI
      # Determines capabilities for Voyage AI models
      module Capabilities
        module_function

        def supports_streaming?(_model_id)
          false
        end

        def supports_tools?(_model_id)
          false
        end

        def supports_vision?(_model_id)
          false
        end

        def supports_json_mode?(_model_id)
          false
        end

        def format_display_name(model_id)
          case model_id
          when 'voyage-4-large' then 'Voyage 4 Large'
          when 'voyage-4' then 'Voyage 4'
          when 'voyage-4-lite' then 'Voyage 4 Lite'
          when 'voyage-4-nano' then 'Voyage 4 Nano'
          when 'voyage-code-3' then 'Voyage Code 3'
          when 'voyage-finance-2' then 'Voyage Finance 2'
          when 'voyage-law-2' then 'Voyage Law 2'
          when 'voyage-multilingual-2' then 'Voyage Multilingual 2'
          else model_id.split('-').map(&:capitalize).join(' ')
          end
        end

        def model_family(model_id)
          case model_id
          when /voyage-4/ then 'voyage-4'
          when /voyage-code/ then 'voyage-code'
          when /voyage-finance/ then 'voyage-finance'
          when /voyage-law/ then 'voyage-law'
          when /voyage-multilingual/ then 'voyage-multilingual'
          else 'voyage'
          end
        end

        def context_window_for(model_id)
          # voyage-law-2 has a 16K context window, others have 32K
          model_id == 'voyage-law-2' ? 16_000 : 32_000
        end

        def max_tokens_for(_model_id)
          nil # Not applicable for embeddings
        end

        def modalities_for(_model_id)
          {
            input: ['text'],
            output: ['embeddings']
          }
        end

        def capabilities_for(_model_id)
          []
        end

        def pricing_for(model_id)
          case model_id
          when 'voyage-4-large' then { input: 0.12 / 1_000_000 }
          when 'voyage-4' then { input: 0.06 / 1_000_000 }
          when 'voyage-4-lite' then { input: 0.02 / 1_000_000 }
          when 'voyage-4-nano' then { input: 0.01 / 1_000_000 } # Estimated
          when 'voyage-code-3' then { input: 0.18 / 1_000_000 }
          when 'voyage-finance-2' then { input: 0.12 / 1_000_000 }
          when 'voyage-law-2' then { input: 0.12 / 1_000_000 }
          when 'voyage-multilingual-2' then { input: 0.12 / 1_000_000 }
          else { input: 0.0 }
          end
        end

        def release_date_for(model_id)
          case model_id
          when 'voyage-law-2', 'voyage-finance-2', 'voyage-multilingual-2' then '2024-01-01'
          when 'voyage-code-3' then '2024-06-01'
          when 'voyage-4-large', 'voyage-4', 'voyage-4-lite' then '2025-01-01'
          when 'voyage-4-nano' then '2025-02-01'
          end
        end
      end
    end
  end
end
