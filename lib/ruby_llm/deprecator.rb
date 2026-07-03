# frozen_string_literal: true

module RubyLLM
  # Owns RubyLLM deprecation warnings so applications and tests can decide how
  # aggressively to handle compatibility paths.
  class Deprecator
    def warn(message)
      case RubyLLM.config.deprecation_behavior
      when :silence
        nil
      when :raise
        raise DeprecationError, message
      else
        RubyLLM.logger.warn(message)
      end
    end

    def deprecate(name, replacement:, removal:)
      warn("#{name} is deprecated and will be removed in RubyLLM #{removal}. Use #{replacement} instead.")
    end
  end

  class DeprecationError < StandardError; end
end
