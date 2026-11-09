# frozen_string_literal: true

module RubyLLM
  module Providers
    class Azure
      # Foundry's REST reference lists /openai/v1/moderations, but resource
      # and project endpoints answer it with the 404 of an unknown route and
      # the catalog holds no moderation model.
      module Moderation
        def render_moderation_payload(*, **)
          raise NotImplementedError
        end
      end
    end
  end
end
