# frozen_string_literal: true

module RubyLLM
  module Providers
    class GPUStack
      # Chat methods of the GPUStack API integration
      module Chat
        module_function

        def render_content(content, attachments = [])
          GPUStack::Media.render_content(content, attachments)
        end

        def render_role(role)
          role.to_s
        end

        # vLLM truncates the rendered prompt to its last tokens. It summarizes
        # nothing, and the cut can reach the system prompt. Truncating to the
        # model's own limit without an output limit leaves no room to answer,
        # and vLLM rejects the request.
        def apply_compaction(payload, compaction)
          log_ignored_compaction_options(compaction)
          limit = compaction[:at] || (-1 if payload.key?(:max_tokens))
          return payload.merge(truncate_prompt_tokens: limit, truncation_side: 'left') if limit

          RubyLLM.logger.debug { "#{@provider.name} needs at: or an output limit to truncate, not truncating" }
          payload
        end

        def log_ignored_compaction_options(compaction)
          ignored = compaction.except(:at)
          return if ignored.empty?

          RubyLLM.logger.debug { "#{@provider.name} only truncates the prompt, dropping #{ignored.inspect}" }
        end
      end
    end
  end
end
