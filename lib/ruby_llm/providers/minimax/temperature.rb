# frozen_string_literal: true

module RubyLLM
  module Providers
    class MiniMax
      # Normalizes temperature for MiniMax models.
      # MiniMax accepts temperature in the range [0.0, 1.0].
      module Temperature
        module_function

        def normalize(temperature)
          return temperature if temperature.nil?

          clamped = temperature.to_f.clamp(0.0, 1.0)
          return clamped if (clamped - temperature.to_f).abs <= Float::EPSILON

          RubyLLM.logger.debug { "MiniMax requires temperature in [0.0, 1.0], clamping #{temperature} to #{clamped}" }
          clamped
        end
      end
    end
  end
end
