# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Responses
      # Manual context compaction through the Responses API.
      module Compaction
        def compaction_url
          "#{completion_url}/compact"
        end

        def render_compaction_payload(messages)
          { model: model.id, input: format_input(messages, caching: false),
            instructions: format_instructions(messages, caching: false) }.compact
        end

        def parse_compaction_response(response)
          body = response.body
          unless body['object'] == 'response.compaction' && body['output'].is_a?(Array)
            raise Error.new('The provider returned an invalid compaction response', response:)
          end

          Message.new(role: :assistant, content: '', model: model.id, finish_reason: :stop,
                      raw_content: body, raw: response, **parse_usage(body['usage'] || {}))
        end
      end
    end
  end
end
