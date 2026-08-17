# frozen_string_literal: true

module RubyLLM
  module Protocols
    # The MiniMax video API: asynchronous generation on two independently
    # versioned endpoints, where the model id picks the version. MiniMax has
    # no chat, embedding, or image seams here, so those are left
    # unimplemented.
    class MiniMax < Protocol
      include MiniMax::Videos
    end
  end
end
