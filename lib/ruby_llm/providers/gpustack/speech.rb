# frozen_string_literal: true

module RubyLLM
  module Providers
    class GPUStack
      # GPUStack's vLLM speech endpoint requires an explicit stream flag.
      module Speech
        def stream_speech(payload, model:, voice:, format:, &)
          format ||= 'pcm'
          super(payload.merge(stream: true, response_format: format), model:, voice:, format:, &)
        end
      end
    end
  end
end
