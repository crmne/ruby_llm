# frozen_string_literal: true

module RubyLLM
  module Support
    module DeprecatedJobPredicates # :nodoc:
      def done?
        warn_about_predicate(:done?, :complete?)
        complete?
      end

      def completed?
        warn_about_predicate(:completed?, :succeeded?)
        succeeded?
      end

      private

      def warn_about_predicate(name, replacement)
        RubyLLM.deprecator.deprecate("#{self.class}##{name}", replacement: "#{self.class}##{replacement}",
                                                              removal: '3.0')
      end
    end
  end
end
