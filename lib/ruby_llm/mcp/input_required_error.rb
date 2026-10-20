# frozen_string_literal: true

module RubyLLM
  class MCP
    # Raised when a server needs input from the user and no
    # MCP.before_input_request callback answered. Rescue
    # RubyLLM::InputRequiredError to catch a tool's own questions too.
    class InputRequiredError < RubyLLM::InputRequiredError
    end
  end
end
