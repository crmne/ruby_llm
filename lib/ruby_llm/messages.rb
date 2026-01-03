# frozen_string_literal: true

module RubyLLM
  # Internal helper module for accessing protected message attributes
  module Messages
    module_function

    def signature_for(message)
      message.send(:thinking_signature) if message.respond_to?(:thinking_signature, true)
    end
  end
end
