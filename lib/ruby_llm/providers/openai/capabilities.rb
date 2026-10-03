# frozen_string_literal: true

module RubyLLM
  module Providers
    class OpenAI
      # Feature capability gaps not represented in upstream model catalogs.
      module Capabilities
        TOOL_CAPABILITIES = %w[tool_choice parallel_tool_calls].freeze
        CHAT_MODELS = %w[
          gpt-5-chat-latest
          gpt-5.1-chat-latest
        ].freeze
        CODEX_MODELS = %w[
          gpt-5-codex
          gpt-5.1-codex
          gpt-5.1-codex-max
          gpt-5.1-codex-mini
          gpt-5.2-codex
        ].freeze
        SEARCH_MODELS = %w[
          gpt-4o-mini-search-preview
          gpt-4o-mini-search-preview-2025-03-11
          gpt-4o-search-preview
          gpt-4o-search-preview-2025-03-11
          gpt-5-search-api
          gpt-5-search-api-2025-10-14
        ].freeze
        DEEP_RESEARCH_MODELS = %w[
          o3-deep-research
          o3-deep-research-2025-06-26
          o4-mini-deep-research
          o4-mini-deep-research-2025-06-26
        ].freeze
        MODERATION_MODELS = %w[
          omni-moderation-2024-09-26
          omni-moderation-latest
        ].freeze
        # The Responses API models OpenAI lists as supporting tool search
        # (gpt-5.4 and later): https://developers.openai.com/api/docs/guides/tools-tool-search
        TOOL_SEARCH_MODELS = %w[
          gpt-5.4
          gpt-5.4-2026-03-05
          gpt-5.4-mini
          gpt-5.4-mini-2026-03-17
          gpt-5.4-nano
          gpt-5.4-nano-2026-03-17
          gpt-5.4-pro
          gpt-5.4-pro-2026-03-05
          gpt-5.5
          gpt-5.5-2026-04-23
          gpt-5.5-pro
          gpt-5.5-pro-2026-04-23
          gpt-5.6
          gpt-5.6-luna
          gpt-5.6-sol
          gpt-5.6-terra
          gpt-6-astra
          gpt-6-luna
          gpt-6-sol
          gpt-6.1-sol
        ].freeze
        TRANSCRIPTION_MODELS = %w[
          gpt-live-transcribe
          gpt-realtime-whisper
          gpt-transcribe
          gpt-4o-mini-transcribe
          gpt-4o-mini-transcribe-2025-03-20
          gpt-4o-mini-transcribe-2025-12-15
          gpt-4o-transcribe
          gpt-4o-transcribe-diarize
          whisper-1
        ].freeze
        JUDGMENT_MODELS = %w[gpt-6-luna].freeze
        EXPLICIT_CAPABILITIES = {
          'function_calling' => (CHAT_MODELS + CODEX_MODELS).freeze,
          'structured_output' => (CHAT_MODELS + CODEX_MODELS + SEARCH_MODELS).freeze,
          'vision' => (CHAT_MODELS + CODEX_MODELS + DEEP_RESEARCH_MODELS + MODERATION_MODELS).freeze,
          'reasoning' => (CODEX_MODELS + DEEP_RESEARCH_MODELS).freeze,
          'transcription' => TRANSCRIPTION_MODELS,
          'citations' => SEARCH_MODELS,
          'judgment' => JUDGMENT_MODELS,
          'tool_search' => TOOL_SEARCH_MODELS
        }.freeze

        def self.augment(capabilities, model_id:, **)
          additions = EXPLICIT_CAPABILITIES.filter_map do |capability, models|
            capability if models.include?(model_id)
          end
          supported = capabilities | additions
          supported | (supported.include?('function_calling') ? TOOL_CAPABILITIES : [])
        end
      end
    end
  end
end
