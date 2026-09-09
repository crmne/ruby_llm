# frozen_string_literal: true

module RubyLLM
  module Protocols
    module Bedrock
      # Moderation through an explicitly configured Bedrock guardrail.
      class Guardrails < Protocol
        POLICY_FILTERS = {
          'contentPolicy' => %w[filters],
          'topicPolicy' => %w[topics],
          'wordPolicy' => %w[customWords managedWordLists],
          'sensitiveInformationPolicy' => %w[piiEntities regexes],
          'contextualGroundingPolicy' => %w[filters]
        }.freeze
        private_constant :POLICY_FILTERS

        IMAGE_TYPES = %w[image/png image/jpeg].freeze
        INTERVENTIONS = %w[BLOCKED ANONYMIZED].freeze
        private_constant :IMAGE_TYPES, :INTERVENTIONS

        def moderate(input, model:, with: [], provider_options: {})
          raise ArgumentError, 'Bedrock guardrails do not accept a model' unless model.nil?

          url = @provider.guardrail_url
          attachments = Attachment.wrap(with, config: @config)
          validate_moderation_input(input, attachments)
          payloads = (input.is_a?(Array) ? input : [input]).map do |text|
            render_moderation_payload(text, attachments, provider_options)
          end
          track_usage(:moderation) do
            responses = payloads.map do |payload|
              response = post_moderation(url, payload)
              result = parse_moderation_result(response)
              @usage_tracker.succeed_attempts(tokens: [Tokens.new])
              [response, result]
            end
            parse_moderation_responses(responses)
          end
        end

        private

        def parse_moderation_responses(responses)
          RubyLLM::Moderation.new(
            id: responses.one? ? responses.first.first.headers['x-amzn-requestid'] : nil,
            model: nil,
            results: responses.map(&:last),
            raw: responses.one? ? responses.first.first.body : responses.map { |response, _result| response.body }
          )
        end

        def validate_moderation_input(input, attachments)
          unless valid_text_input?(input)
            raise ArgumentError, 'Bedrock moderation requires text or a nonempty array of texts'
          end
          if input.is_a?(Array) && attachments.any?
            raise ArgumentError, 'Bedrock moderation accepts image attachments with one text input at a time'
          end
          raise ArgumentError, 'Bedrock moderation requires text or an image' if input.nil? && attachments.empty?

          attachments.each do |attachment|
            next if IMAGE_TYPES.include?(attachment.mime_type)

            raise UnsupportedAttachmentError, attachment.mime_type
          end
        end

        def valid_text_input?(input)
          input.nil? || input.is_a?(String) || (input.is_a?(Array) && input.any? && input.all?(String))
        end

        def render_moderation_payload(input, attachments, provider_options)
          content = input.nil? ? [] : [{ text: { text: input } }]
          content.concat(attachments.map do |attachment|
            { image: { format: attachment.mime_type.delete_prefix('image/'), source: { bytes: attachment.encoded } } }
          end)
          { source: 'INPUT', content: }.merge(render_guardrail_options(provider_options))
        end

        def render_guardrail_options(provider_options)
          options = provider_options.transform_keys(&:to_sym)
          unknown = options.keys - %i[source outputScope]
          unless unknown.empty?
            raise ArgumentError, "Bedrock moderation options only support source and outputScope: #{unknown.join(', ')}"
          end

          options
        end

        def post_moderation(url, payload)
          @connection.post(url, payload, usage: @usage_tracker) do |request|
            request.headers.merge!(@provider.sign_headers('POST', url, JSON.generate(payload)))
          end
        end

        def parse_moderation_result(response)
          data = response.body
          unless data.is_a?(Hash) && %w[NONE GUARDRAIL_INTERVENED].include?(data['action'])
            raise Error.new('Bedrock moderation returned no recognized verdict', response:)
          end

          categories = Array(data['assessments']).flat_map { |assessment| parse_moderation_categories(assessment) }
          RubyLLM::Moderation::Result.new(
            flagged: data['action'] == 'GUARDRAIL_INTERVENED', categories: categories.uniq, category_scores: {}
          )
        end

        def parse_moderation_categories(assessment)
          POLICY_FILTERS.flat_map do |policy, groups|
            groups.flat_map do |group|
              Array(assessment.dig(policy, group)).filter_map do |filter|
                next unless INTERVENTIONS.include?(filter['action'])

                filter['name'] || filter['type'] || "#{policy}.#{group}"
              end
            end
          end
        end
      end
    end
  end
end
