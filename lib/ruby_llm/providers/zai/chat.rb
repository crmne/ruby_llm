# frozen_string_literal: true

module RubyLLM
  module Providers
    class ZAI
      # Chat methods of the Z.ai API integration
      # https://docs.z.ai/api-reference/llm/chat-completion
      module Chat
        FINISH_REASONS = Protocols::ChatCompletions::Chat::FINISH_REASONS.merge(
          'sensitive' => :content_filter,
          'model_context_window_exceeded' => :max_tokens
        ).freeze

        # Search results come back only when the tool sets search_result.
        FILE_MODEL_PREFIX = 'glm-5.3-flash'

        SERVER_TOOL_ALIASES = {
          web_search: lambda { |options|
            settings = { enable: true, search_result: true }.merge(Support::Utils.deep_symbolize_keys(options))
            { tool: { type: 'web_search', web_search: settings } }
          }
        }.freeze

        # The GLM-5.3-Flash series is the one that reads files.
        def self.reads_files?(model)
          model&.id.to_s.start_with?(FILE_MODEL_PREFIX)
        end

        module_function

        def finish_reasons = FINISH_REASONS

        def render_role(role)
          role.to_s
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, max_output_tokens: nil,
                           schema: nil, thinking: nil, citations: false, caching: nil, tool_prefs: nil)
          payload = super
          raise ArgumentError, 'Z.ai does not accept calls: :one' if payload.delete(:parallel_tool_calls) == false

          payload[:thinking] = { type: thinking.disabled? ? 'disabled' : 'enabled' } if thinking&.enabled?
          payload.delete(:reasoning_effort) if thinking&.disabled?
          payload
        end

        def apply_end_user(payload, identifier)
          payload.merge(user_id: identifier)
        end

        # Sources from the web_search tool arrive in a top-level web_search
        # array, on the last chunk when streaming.
        def parse_root_citations(data)
          results = data['web_search']
          return super unless results.is_a?(Array) && results.any?

          results.each_with_index.filter_map do |result, index|
            next unless result.is_a?(Hash)

            Citation.new(url: result['link'], title: result['title'], cited_text: result['content'],
                         source_index: index)
          end
        end

        # Z.ai caches prompt prefixes by itself and takes no cache controls.
        def openai_prompt_caching?
          false
        end

        def render_thinking(msg)
          text = msg.thinking&.text if msg.role == :assistant
          text ? { reasoning_content: text } : {}
        end

        def supported_attachment?(attachment)
          return true if remote_pdf?(attachment)

          Protocols::ChatCompletions::Media.supported_attachment?(
            attachment, document_attachments: document_attachments(attachment), audio_attachments: false
          )
        end

        def render_content(content, attachments = [])
          Protocols::ChatCompletions::Media.render_parts(content, attachments) do |attachment|
            next { type: 'file', file: { file_url: attachment.source.to_s } } if remote_pdf?(attachment)

            Protocols::ChatCompletions::Media.render_attachment(
              attachment, document_attachments: document_attachments(attachment),
                          image_attachments: true, audio_attachments: false
            )
          end
        end

        # The API fetches a remote PDF itself.
        def remote_pdf?(attachment)
          attachment.url? && attachment.pdf? && Chat.reads_files?(@model)
        end

        # Files uploaded to Z.ai are referenced by id; other documents are not inlined.
        def document_attachments(attachment)
          return :none unless attachment.provider_file? && attachment.source.provider == 'zai'

          attachment.audio? ? :none : :pdf
        end
      end
    end
  end
end
