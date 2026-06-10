# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Normalizes temperature for OpenAI models with provider-specific requirements.
      module Temperature
        module_function

        def normalize(temperature, model_id)
          if reasoning_model?(model_id) && !temperature.nil? && !temperature_close_to_one?(temperature)
            RubyLLM.logger.debug { "Model #{model_id} requires temperature=1.0, setting that instead." }
            1.0
          elsif model_id.include?('-search')
            RubyLLM.logger.debug { "Model #{model_id} does not accept temperature parameter, removing" }
            nil
          else
            temperature
          end
        end

        def temperature_close_to_one?(temperature)
          (temperature.to_f - 1.0).abs <= Float::EPSILON
        end

        def reasoning_model?(model_id)
          model_id.match?(/^o\d/) ||                          # o1, o3, o4-mini, etc.
            model_id.match?(/^gpt-5(\.\d+)?(-\d{4})?$/) ||    # gpt-5, gpt-5.4, gpt-5.4-2026-03-05
            model_id.match?(/^gpt-5(\.\d+)?-pro/)             # gpt-5-pro, gpt-5.4-pro
        end
      end
    end
  end
end
