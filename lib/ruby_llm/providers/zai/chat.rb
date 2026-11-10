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
        SERVER_TOOL_ALIASES = {
          web_search: lambda { |options|
            settings = { enable: true, search_result: true }.merge(Support::Utils.deep_symbolize_keys(options))
            { tool: { type: 'web_search', web_search: settings } }
          }
        }.freeze

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
          return true if inline_video?(attachment)

          Protocols::ChatCompletions::Media.supported_attachment?(
            attachment, document_attachments: document_attachments(attachment), audio_attachments: false
          )
        end

        def render_content(content, attachments = [])
          Protocols::ChatCompletions::Media.render_parts(content, attachments) do |attachment|
            next render_video(attachment) if inline_video?(attachment)

            Protocols::ChatCompletions::Media.render_attachment(
              attachment, document_attachments: document_attachments(attachment),
                          image_attachments: true, audio_attachments: false
            )
          end
        end

        def inline_video?(attachment)
          attachment.video? && !attachment.provider_file?
        end

        def render_video(video)
          { type: 'video_url', video_url: { url: video.url_or_data_uri } }
        end

        # PDFs travel inline as data URIs, and files uploaded to Z.ai by id.
        def document_attachments(attachment)
          return :pdf unless attachment.provider_file?
          return :none unless attachment.source.provider == 'zai'

          attachment.audio? ? :none : :pdf
        end
      end
    end
  end
end
