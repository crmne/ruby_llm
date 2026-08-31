# frozen_string_literal: true

module RubyLLM
  module Providers
    class XAI
      module ReportedCost # :nodoc:
        USD_PER_TICK = 1e-10

        private

        def reported_cost(usage)
          ticks = usage['cost_in_usd_ticks']
          ticks ? ticks * USD_PER_TICK : nil
        end
      end
    end
  end
end
