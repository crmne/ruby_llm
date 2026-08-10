# frozen_string_literal: true

module RubyLLM
  module Protocols
    class Gemini
      # Explicit content caching via the Gemini cachedContents API.
      module Caches
        module_function

        def caches_url
          'cachedContents'
        end

        def cache_url(name)
          cache_name(name)
        end

        def render_cache_payload(content, model:, ttl: nil, instructions: nil, attachments: [])
          payload = {
            model: cache_model_name(model),
            contents: [{ role: 'user', parts: Media.format_content(content, attachments) }]
          }
          payload[:systemInstruction] = { parts: [{ text: instructions }] } if instructions
          payload[:ttl] = format_cache_ttl(ttl) if ttl
          payload
        end

        def render_cache_update_payload(ttl:)
          { ttl: format_cache_ttl(ttl) }
        end

        def parse_cache_response(data)
          CachedContent.new(
            name: data['name'],
            model: data['model']&.split('/')&.last,
            provider_instance: @provider,
            created_at: (Time.iso8601(data['createTime']) if data['createTime']),
            expires_at: (Time.iso8601(data['expireTime']) if data['expireTime']),
            tokens: data.dig('usageMetadata', 'totalTokenCount'),
            metadata: data
          )
        end

        def cache_name(name)
          name = name.name if name.is_a?(CachedContent)
          name.to_s.include?('/') ? name.to_s : "cachedContents/#{name}"
        end

        def cache_model_name(model_id)
          "models/#{model_id}"
        end

        def format_cache_ttl(ttl)
          ttl.is_a?(String) ? ttl : "#{ttl.to_i}s"
        end
      end
    end
  end
end
