# frozen_string_literal: true

module RubyLLM
  module Providers
    class Replicate
      # Image generation methods for the Replicate API implementation
      module Images
        attr_reader :model

        def images_url
          if official_model?
            "/v1/models/#{model.name}/predictions"
          else
            '/v1/predictions'
          end
        end

        def render_image_payload(prompt, model:, **params)
          self.model = model

          {}.tap do |payload|
            payload[:webhook] = @config.replicate_webhook_url
            payload[:version] = self.model.id unless official_model?
            payload[:input] = { prompt: prompt }.merge(params)

            if @config.replicate_webhook_events_filter
              payload[:webhook_events_filter] = Array(@config.replicate_webhook_events_filter)
            end
          end
        end

        def parse_image_response(response, **)
          DeferredImage.new(url: response.body.dig('urls', 'get'), provider_instance: self)
        end

        def fetch_image_blob(url)
          prediction = @connection.get(url).body
          return unless prediction['status'] == 'succeeded'

          image_url = Array(prediction['output']).first
          @connection.get(image_url).body
        end

        private

        def model=(id)
          @model = RubyLLM::Models.find(id, 'replicate')
        end

        def official_model?
          model.metadata[:is_official] == true
        end
      end
    end
  end
end
