# frozen_string_literal: true

require 'base64'

module RubyLLM
  module Providers
    class Bedrock
      # The Anthropic Messages API on Bedrock's InvokeModel endpoints, which
      # serve every Claude model and cross-region inference profile. Unlike
      # Converse, it carries Anthropic's own features, such as tool search,
      # so a prompt cache survives the tools a model loads on demand.
      class Anthropic < Protocols::Anthropic
        include Protocols::Bedrock::EventStream

        ANTHROPIC_VERSION = 'bedrock-2023-05-31'
        TOOL_SEARCH_BETA = 'tool-search-tool-2025-10-19'

        def completion_url
          model_path(@model.id, 'invoke')
        end

        def stream_url
          model_path(@model.id, 'invoke-with-response-stream')
        end

        # Bedrock counts tokens for the foundation model, not for the
        # inference profiles that serve it.
        def count_tokens_url
          model_path(Protocols::Converse::Chat.foundation_model_id(@model.id), 'count-tokens')
        end

        def render_payload(messages, **)
          payload = super.except(:model, :stream)
          payload[:messages] = inline_url_sources(payload[:messages])
          payload[:system] = inline_url_sources(payload[:system]) if payload[:system]
          payload.merge(anthropic_version: ANTHROPIC_VERSION)
        end

        def parse_count_tokens_response(response)
          response.body['inputTokens']
        end

        # The body names the foundation model; pricing and the transcript
        # follow the inference profile or ARN that was called.
        def parse_response_model_id(data)
          called_model_id(super)
        end

        def parse_model_id(data)
          called_model_id(super)
        end

        def called_model_id(named)
          named && (@model&.id || named)
        end

        def provider_file_references?
          false
        end

        private

        def sync_response(payload, additional_headers = {})
          headers = beta_headers(additional_headers, payload)
          response = @connection.post(completion_url, JSON.generate(render_invoke_body(payload, headers)),
                                      usage: @usage_tracker) do |request|
            request.headers.merge!(without_beta_header(headers))
          end
          parse_completion_response(response)
        end

        def stream_events(url, payload, additional_headers = {}, &)
          body = JSON.generate(render_invoke_body(payload, additional_headers))
          super(url, body, without_beta_header(additional_headers), &)
        end

        def post_count_tokens(payload)
          body = payload.except(:model).merge(anthropic_version: ANTHROPIC_VERSION, max_tokens: 1)
          body = JSON.generate(render_invoke_body(body, beta_headers({}, payload)))
          request = { input: { invokeModel: { body: Base64.strict_encode64(body) } } }
          @connection.post(count_tokens_url, JSON.generate(request))
        end

        # Bedrock still gates the tool search tool behind its beta.
        def beta_headers(additional_headers, payload)
          headers = super
          tools = Array(payload[:tools] || payload['tools'])
          tools.any? { |tool| search_tool?(tool) } ? add_beta(headers, TOOL_SEARCH_BETA) : headers
        end

        # InvokeModel takes Anthropic's betas in the body, not as a header.
        def render_invoke_body(payload, headers)
          betas = canonical_beta_headers(headers)[BETA_HEADER].to_s.split(',').map(&:strip).reject(&:empty?)
          return payload if betas.empty?

          payload.merge(anthropic_beta: (Array(payload[:anthropic_beta]) + betas).uniq)
        end

        def without_beta_header(headers)
          canonical_beta_headers(headers).except(BETA_HEADER)
        end

        # Bedrock does not fetch URLs, so remote images and documents travel
        # as their bytes.
        def inline_url_sources(blocks)
          return blocks unless blocks.is_a?(Array)

          blocks.map do |block|
            next block unless block.is_a?(Hash)
            next inline_url_source(block) if url_source?(block)

            block[:content].is_a?(Array) ? block.merge(content: inline_url_sources(block[:content])) : block
          end
        end

        def url_source?(block)
          source = block[:source]
          source.is_a?(Hash) && source[:type] == 'url'
        end

        def inline_url_source(block)
          attachment = Attachment.new(block.dig(:source, :url))
          block.merge(source: { type: 'base64', media_type: attachment.mime_type, data: attachment.encoded })
        end

        # Application inference profile ARNs contain '/', which Bedrock
        # expects escaped inside the model segment.
        def model_path(model_id, action)
          "/model/#{model_id.to_s.gsub('/', '%2F')}/#{action}"
        end
      end
    end
  end
end
