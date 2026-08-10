# frozen_string_literal: true

class CaptureInstrumenter
  attr_reader :events

  def initialize
    @events = []
  end

  def instrument(name, payload)
    result = block_given? ? yield : nil
    events << [name, payload.dup]
    result
  end
end
