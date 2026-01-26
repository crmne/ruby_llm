# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Normalizes temperature for OpenAI models with provider-specific requirements.
      module Temperature
        module_function

        def normalize(temperature, model_id)
          if model_id.match?(/^(o\d|gpt-5)/) && !temperature.nil? && !temperature_close_to_one?(temperature)
            RubyLLM.logger.debug "Model #{model_id} requires temperature=1.0, setting that instead."
            1.0
          elsif model_id.include?('-search')
            RubyLLM.logger.debug "Model #{model_id} does not accept temperature parameter, removing"
            nil
          else
            temperature
          end
        end

        def temperature_close_to_one?(temperature)
          (temperature.to_f - 1.0).abs <= Float::EPSILON
        end
      end
    end
  end
end
