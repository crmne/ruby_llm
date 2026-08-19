# frozen_string_literal: true

module RubyLLM
  module Providers
    # Shared lookup over a provider's CAPABILITIES table, which maps a name
    # from ModelSchema::CAPABILITIES to a matcher for model ids: +true+, a
    # Regexp, a callable, or a list matched against #capability_subject.
    module CapabilityTable # :nodoc:
      def supports?(model_id, capability)
        case (matcher = self::CAPABILITIES[capability.to_s])
        when true then true
        when nil, false then false
        when Regexp then model_id.match?(matcher)
        when Proc then matcher.call(model_id)
        else matcher.include?(capability_subject(model_id))
        end
      end

      def supported_capabilities(model_id)
        self::CAPABILITIES.keys.select { |capability| supports?(model_id, capability) }
      end

      def capability_subject(model_id)
        model_id
      end
    end
  end
end
