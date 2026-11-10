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
        # nothing, and the cut can reach the system prompt.
        def apply_compaction(payload, compaction)
          log_ignored_compaction_options(compaction)
          payload.merge(truncate_prompt_tokens: compaction.fetch(:at, -1), truncation_side: 'left')
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
